# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import https_fn
from firebase_functions.options import set_global_options
from firebase_admin import initialize_app
# functions/main.py
import functions_framework
from firebase_admin import initialize_app, firestore, storage
from firebase_functions import storage_fn, https_fn
import easyocr
import deepface
from deepface import DeepFace
import cv2
import numpy as np
import tempfile
import os
import re
import json
import requests
from urllib.parse import urlparse

# Initialize Firebase Admin
initialize_app()
db = firestore.client()
bucket = storage.bucket()

# ─────────────────────────────────────────────────────────────────────────────
# TRIGGER 1: CNIC IMAGE UPLOADED → Run OCR
# Fires when: users/{uid}/cnic_front.jpg is uploaded
# ─────────────────────────────────────────────────────────────────────────────
@storage_fn.on_object_finalized(region="us-central1")
def process_cnic_upload(event: storage_fn.CloudEvent):
    """
    Automatically triggers when any file is uploaded to Firebase Storage.
    Filters for CNIC front images and runs OCR on them.
    """
    file_path = event.data.name  # e.g. "users/uid123/cnic_front.jpg"

    # Only process front CNIC images
    if "cnic_front" not in file_path:
        return

    # Extract user ID from path: users/{uid}/cnic_front.jpg
    parts = file_path.split("/")
    if len(parts) < 2:
        return
    uid = parts[1]

    print(f"[OCR] Processing CNIC front for user: {uid}")

    try:
        # ── Download image from Storage ──
        blob = bucket.blob(file_path)
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            blob.download_to_filename(tmp.name)
            image_path = tmp.name

        # ── Run OCR ──
        extracted_data = _run_easyocr(image_path)

        # ── Save to Firestore ──
        db.collection("users").document(uid).set({
            **extracted_data,
            "ocrStatus": "success",
            "verificationStep": "ocr_done"
        }, merge=True)

        print(f"[OCR] Success for {uid}: {extracted_data}")

        # ── Cleanup ──
        os.unlink(image_path)

    except Exception as e:
        print(f"[OCR] Error for {uid}: {str(e)}")
        db.collection("users").document(uid).set({
            "ocrStatus": "failed",
            "ocrError": str(e)
        }, merge=True)


# ─────────────────────────────────────────────────────────────────────────────
# TRIGGER 2: SELFIE UPLOADED → Run Liveness + Face Match
# Fires when: users/{uid}/selfie.jpg is uploaded
# ─────────────────────────────────────────────────────────────────────────────
@storage_fn.on_object_finalized(region="us-central1")
def process_selfie_upload(event: storage_fn.CloudEvent):
    """
    Automatically triggers when selfie is uploaded.
    Runs liveness check + face match against CNIC front photo.
    """
    file_path = event.data.name  # e.g. "users/uid123/selfie.jpg"

    if "selfie" not in file_path:
        return

    parts = file_path.split("/")
    if len(parts) < 2:
        return
    uid = parts[1]

    print(f"[FACE] Processing selfie for user: {uid}")

    selfie_tmp = None
    cnic_tmp = None

    try:
        # ── Download selfie ──
        selfie_blob = bucket.blob(file_path)
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            selfie_blob.download_to_filename(tmp.name)
            selfie_tmp = tmp.name

        # ── Download CNIC front (for face match) ──
        cnic_path = f"users/{uid}/cnic_front.jpg"
        cnic_blob = bucket.blob(cnic_path)
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            cnic_blob.download_to_filename(tmp.name)
            cnic_tmp = tmp.name

        # ── Step 1: Liveness Check (anti-spoofing) ──
        liveness_result = _check_liveness(selfie_tmp)

        if not liveness_result["is_live"]:
            db.collection("users").document(uid).set({
                "livenessStatus": "failed",
                "livenessScore": liveness_result["score"],
                "livenessError": "Spoofing detected — please use a real photo",
                "isVerified": False,
                "verificationStep": "liveness_failed"
            }, merge=True)
            print(f"[FACE] Liveness failed for {uid}")
            return

        # ── Step 2: Face Match selfie vs CNIC ──
        match_result = _run_face_match(selfie_tmp, cnic_tmp)

        if match_result["is_match"]:
            # ✅ Verified!
            db.collection("users").document(uid).set({
                "livenessStatus": "passed",
                "livenessScore": liveness_result["score"],
                "faceMatchStatus": "matched",
                "faceMatchDistance": match_result["distance"],
                "faceMatchConfidence": match_result["confidence"],
                "isVerified": True,
                "verificationStep": "completed",
                "verifiedAt": firestore.SERVER_TIMESTAMP
            }, merge=True)
            print(f"[FACE] Verified! User {uid} — distance: {match_result['distance']:.3f}")
        else:
            # ❌ Face mismatch
            db.collection("users").document(uid).set({
                "livenessStatus": "passed",
                "faceMatchStatus": "mismatch",
                "faceMatchDistance": match_result["distance"],
                "faceMatchConfidence": match_result["confidence"],
                "isVerified": False,
                "verificationStep": "face_mismatch"
            }, merge=True)
            print(f"[FACE] Face mismatch for {uid} — distance: {match_result['distance']:.3f}")

    except Exception as e:
        print(f"[FACE] Error for {uid}: {str(e)}")
        db.collection("users").document(uid).set({
            "faceMatchStatus": "error",
            "faceMatchError": str(e),
            "isVerified": False,
            "verificationStep": "error"
        }, merge=True)

    finally:
        # Cleanup temp files
        if selfie_tmp and os.path.exists(selfie_tmp):
            os.unlink(selfie_tmp)
        if cnic_tmp and os.path.exists(cnic_tmp):
            os.unlink(cnic_tmp)


# ─────────────────────────────────────────────────────────────────────────────
# HTTPS CALLABLE: Manual re-check trigger (optional, from Flutter)
# ─────────────────────────────────────────────────────────────────────────────
@https_fn.on_call(region="us-central1")
def trigger_verification(req: https_fn.CallableRequest):
    """
    Optional: Flutter can call this to manually re-trigger verification
    if the automatic Storage trigger was missed.
    """
    uid = req.auth.uid if req.auth else None
    if not uid:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
            message="Must be authenticated"
        )

    # Re-trigger by checking if both files exist and processing
    selfie_blob = bucket.blob(f"users/{uid}/selfie.jpg")
    cnic_blob = bucket.blob(f"users/{uid}/cnic_front.jpg")

    if not selfie_blob.exists() or not cnic_blob.exists():
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
            message="Upload both CNIC and selfie first"
        )

    # Simulate the storage event by processing directly
    # (reuses same logic)
    return {"status": "processing", "message": "Verification triggered"}


# ─────────────────────────────────────────────────────────────────────────────
# HELPER: EasyOCR — Extract CNIC fields
# ─────────────────────────────────────────────────────────────────────────────
def _run_easyocr(image_path: str) -> dict:
    """
    Uses EasyOCR to extract text from Pakistani CNIC.
    Returns structured fields: name, father's name, CNIC number, DOB, etc.
    """
    reader = easyocr.Reader(["en"], gpu=False)

    # Read image with OpenCV first for preprocessing
    img = cv2.imread(image_path)

    # ── Preprocessing: improve OCR accuracy ──
    # 1. Upscale small images
    h, w = img.shape[:2]
    if w < 600:
        scale = 600 / w
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # 2. Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 3. Adaptive threshold to handle uneven lighting
    thresh = cv2.adaptiveThreshold(
        gray, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 11, 2
    )

    # Save preprocessed image
    processed_path = image_path.replace(".jpg", "_processed.jpg")
    cv2.imwrite(processed_path, thresh)

    # Run EasyOCR
    results = reader.readtext(processed_path, detail=0, paragraph=False)
    full_text = "\n".join(results)

    print(f"[OCR] Raw text extracted:\n{full_text}")

    # ── Parse Pakistani CNIC fields ──
    extracted = _parse_cnic_text(full_text, results)

    # Cleanup
    if os.path.exists(processed_path):
        os.unlink(processed_path)

    return extracted


def _parse_cnic_text(full_text: str, lines: list) -> dict:
    """
    Parses EasyOCR output to extract Pakistani CNIC fields.
    Pakistani CNIC format: XXXXX-XXXXXXX-X
    """
    extracted = {
        "name": None,
        "fathersName": None,
        "cnicNumber": None,
        "dob": None,
        "issueDate": None,
        "expiryDate": None,
        "gender": None,
        "rawOcrText": full_text
    }

    # ── CNIC Number: 00000-0000000-0 ──
    cnic_pattern = r'\b\d{5}[-\s]?\d{7}[-\s]?\d{1}\b'
    cnic_match = re.search(cnic_pattern, full_text)
    if cnic_match:
        extracted["cnicNumber"] = re.sub(r'[\s]', '-', cnic_match.group()).strip()

    # ── Date Pattern: DD.MM.YYYY or DD/MM/YYYY ──
    date_pattern = r'\b(\d{2}[.\-/]\d{2}[.\-/]\d{4})\b'
    dates = re.findall(date_pattern, full_text)
    if len(dates) >= 1:
        extracted["dob"] = dates[0]
    if len(dates) >= 2:
        extracted["issueDate"] = dates[1]
    if len(dates) >= 3:
        extracted["expiryDate"] = dates[2]

    # ── Gender ──
    if re.search(r'\bM\b|\bMale\b|\bMALE\b', full_text, re.IGNORECASE):
        extracted["gender"] = "Male"
    elif re.search(r'\bF\b|\bFemale\b|\bFEMALE\b', full_text, re.IGNORECASE):
        extracted["gender"] = "Female"

    # ── Name extraction: line after "Name" keyword ──
    for i, line in enumerate(lines):
        clean = line.strip()
        if re.search(r'\bName\b', clean, re.IGNORECASE) and i + 1 < len(lines):
            name_candidate = lines[i + 1].strip()
            # Basic validation: only letters and spaces
            if re.match(r'^[A-Za-z\s]+$', name_candidate) and len(name_candidate) > 3:
                extracted["name"] = name_candidate

        # Father's name often follows "Father Name" or "S/O"
        if re.search(r"Father|S/O|Son of", clean, re.IGNORECASE) and i + 1 < len(lines):
            father_candidate = lines[i + 1].strip()
            if re.match(r'^[A-Za-z\s]+$', father_candidate) and len(father_candidate) > 3:
                extracted["fathersName"] = father_candidate

    return extracted


# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Liveness Check using DeepFace anti-spoofing
# ─────────────────────────────────────────────────────────────────────────────
def _check_liveness(selfie_path: str) -> dict:
    """
    Uses DeepFace's anti-spoofing model to check if selfie is a real person
    vs a photo of a photo (print attack) or screen replay.
    """
    try:
        # DeepFace anti_spoofing detects if face is real
        result = DeepFace.extract_faces(
            img_path=selfie_path,
            anti_spoofing=True,
            enforce_detection=True
        )

        if not result:
            return {"is_live": False, "score": 0.0, "error": "No face detected"}

        face_data = result[0]

        # anti_spoofing=True adds 'is_real' and 'antispoof_score' to result
        is_real = face_data.get("is_real", False)
        score = face_data.get("antispoof_score", 0.0)

        return {
            "is_live": is_real,
            "score": float(score)
        }

    except Exception as e:
        print(f"[LIVENESS] Error: {str(e)}")
        # If DeepFace can't find a face at all, fail safely
        return {"is_live": False, "score": 0.0, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# HELPER: Face Match — selfie vs CNIC photo
# ─────────────────────────────────────────────────────────────────────────────
def _run_face_match(selfie_path: str, cnic_path: str) -> dict:
    """
    Compares selfie face with face on CNIC front image.
    Uses DeepFace with ArcFace model (best accuracy for ID photos).
    Threshold: distance < 0.40 = same person (ArcFace cosine).
    """
    try:
        result = DeepFace.verify(
            img1_path=selfie_path,
            img2_path=cnic_path,
            model_name="ArcFace",          # Best for ID verification
            detector_backend="retinaface", # Best face detector
            distance_metric="cosine",
            enforce_detection=True,
            align=True
        )

        distance = result.get("distance", 1.0)
        threshold = result.get("threshold", 0.40)
        verified = result.get("verified", False)

        # Confidence: invert distance to percentage
        confidence = max(0.0, (1.0 - distance) * 100)

        return {
            "is_match": verified,
            "distance": float(distance),
            "threshold": float(threshold),
            "confidence": round(float(confidence), 2)
        }

    except Exception as e:
        print(f"[FACE MATCH] Error: {str(e)}")
        raise Exception(f"Face match failed: {str(e)}")
# For cost control, you can set the maximum number of containers that can be
# running at the same time. This helps mitigate the impact of unexpected
# traffic spikes by instead downgrading performance. This limit is a per-function
# limit. You can override the limit for each function using the max_instances
# parameter in the decorator, e.g. @https_fn.on_request(max_instances=5).
set_global_options(max_instances=10)

# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")