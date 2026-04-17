import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

class ChatService {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get myId => _auth.currentUser!.uid;

  // ── Presence ──────────────────────────────────────────────────────────────

  Future<void> updatePresence(bool online) async {
    try {
      await _db.collection('users').doc(myId).set({
        'online':   online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Guard against empty userId to prevent crashes.
  Stream<bool> presenceStream(String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((s) => s.data()?['online'] as bool? ?? false);
  }

  // ── Typing indicator ──────────────────────────────────────────────────────

  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      await _db.collection('chats').doc(chatId).update({
        'typing.$myId': isTyping,
      });
    } catch (_) {}
  }

  Stream<bool> isOtherTypingStream(String chatId, String otherId) {
    if (otherId.isEmpty) return Stream.value(false);
    return _db.collection('chats').doc(chatId).snapshots().map((s) {
      final typing = s.data()?['typing'] as Map<String, dynamic>?;
      return typing?[otherId] as bool? ?? false;
    });
  }

  // ── Chat creation / lookup ────────────────────────────────────────────────

  Future<String> getOrCreateChat({
    required String otherUserId,
    required String otherUserName,
  }) async {
    if (otherUserId.isEmpty) {
      throw ArgumentError('Invalid user ID.');
    }
    if (otherUserId == myId) {
      throw ArgumentError('You cannot start a chat with yourself.');
    }

    final existing = await _db
        .collection('chats')
        .where('participants', arrayContains: myId)
        .get();

    for (final doc in existing.docs) {
      final p = List<String>.from(doc['participants'] as List? ?? []);
      if (p.contains(otherUserId)) return doc.id;
    }

    final meDoc  = await _db.collection('users').doc(myId).get();
    final myName = meDoc.data()?['name'] as String? ?? 'User';

    final ref = await _db.collection('chats').add({
      'participants':    [myId, otherUserId],
      'lastMessage':     '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'names':           {myId: myName, otherUserId: otherUserName},
      'unreadCount':     {myId: 0, otherUserId: 0},
      'archivedBy':      <String>[],
      'deletedBy':       <String, dynamic>{},
      'mutedBy':         <String>[],
      'clearedAt':       <String, dynamic>{},
      'typing':          <String, dynamic>{},
    });

    return ref.id;
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(
      String chatId,
      String text, {
        Map<String, dynamic>? replyTo,
      }) async {
    await _sendInternal(chatId: chatId, text: text, replyTo: replyTo);
  }

  Future<void> sendMessageWithItem(
      String chatId,
      String text, {
        required Map<String, dynamic> itemData,
        Map<String, dynamic>? replyTo,
      }) async {
    await _sendInternal(
      chatId:  chatId,
      text:    text,
      replyTo: replyTo,
      itemRef: {
        'itemId':      itemData['id']                    ?? '',
        'title':       itemData['title']                 ?? '',
        'image':       itemData['image']                 ?? '',
        'price':       itemData['price']?.toString()     ?? '',
        'listingType': itemData['listingType']           ?? 'sell',
      },
    );
  }

  Future<void> _sendInternal({
    required String chatId,
    required String text,
    Map<String, dynamic>? itemRef,
    Map<String, dynamic>? replyTo,
  }) async {
    final chatDoc      = await _db.collection('chats').doc(chatId).get();
    final participants = List<String>.from(
        chatDoc.data()?['participants'] as List? ?? []);
    final otherId = participants.firstWhere(
          (id) => id != myId,
      orElse:   () => '',
    );

    final batch  = _db.batch();
    final msgRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final msgData = <String, dynamic>{
      'senderId':           myId,
      'text':               text,
      'timestamp':          FieldValue.serverTimestamp(),
      'read':               false,
      'deletedFor':         <String>[],
      'deletedForEveryone': false,
      'reactions':          <String, dynamic>{},
      'starredBy':          <String>[],
    };
    if (itemRef != null) msgData['itemRef'] = itemRef;
    if (replyTo != null) msgData['replyTo'] = replyTo;

    batch.set(msgRef, msgData);

    final chatUpdate = <String, dynamic>{
      'lastMessage':     itemRef != null ? '📦 $text' : text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'deletedBy':       FieldValue.delete(),
      'typing.$myId':    false,
    };
    if (otherId.isNotEmpty) {
      chatUpdate['unreadCount.$otherId'] = FieldValue.increment(1);
    }
    batch.update(_db.collection('chats').doc(chatId), chatUpdate);
    await batch.commit();
  }

  // ── Reactions ─────────────────────────────────────────────────────────────

  Future<void> toggleReaction(
      String chatId, String messageId, String emoji) async {
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final doc       = await msgRef.get();
      final reactions = Map<String, dynamic>.from(
          doc.data()?['reactions'] as Map? ?? {});
      final users = List<String>.from(reactions[emoji] as List? ?? []);

      if (users.contains(myId)) {
        users.remove(myId);
      } else {
        users.add(myId);
      }

      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }

      await msgRef.update({'reactions': reactions});
    } catch (_) {}
  }

  // ── Star message ──────────────────────────────────────────────────────────

  Future<void> toggleStarMessage(String chatId, String messageId) async {
    try {
      final msgRef = _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      final doc     = await msgRef.get();
      final starred = List<String>.from(
          doc.data()?['starredBy'] as List? ?? []);

      if (starred.contains(myId)) {
        starred.remove(myId);
      } else {
        starred.add(myId);
      }

      await msgRef.update({'starredBy': starred});
    } catch (_) {}
  }

  // ── Delete / Archive / Mute ───────────────────────────────────────────────

  Future<void> deleteChatForMe(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'deletedBy.$myId': FieldValue.serverTimestamp(),
    });
  }

  Future<void> archiveChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayUnion([myId]),
    });
  }

  Future<void> unarchiveChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'archivedBy': FieldValue.arrayRemove([myId]),
    });
  }

  Future<void> muteChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'mutedBy': FieldValue.arrayUnion([myId]),
    });
  }

  Future<void> unmuteChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'mutedBy': FieldValue.arrayRemove([myId]),
    });
  }

  Future<void> deleteMessageForMe(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'deletedFor': FieldValue.arrayUnion([myId])});
  }

  Future<void> deleteMessageForEveryone(
      String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text':               'This message was deleted',
      'deletedForEveryone': true,
      'itemRef':            FieldValue.delete(),
      'replyTo':            FieldValue.delete(),
      'reactions':          <String, dynamic>{},
    });
  }

  /// BUG FIX 3: Store a per-user clearedAt timestamp.
  Future<void> clearChatForMe(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'clearedAt.$myId':   FieldValue.serverTimestamp(),
      'unreadCount.$myId': 0,
    });
  }

  // ── Read receipts ─────────────────────────────────────────────────────────

  /// BUG FIX 2: Removed `isNotEqualTo` filter which required a composite
  /// Firestore index (and failed silently). Now filters client-side.
  Future<void> markMessagesRead(String chatId) async {
    try {
      // Only filter by read=false — no compound query, no index needed.
      final unread = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .get();

      if (unread.docs.isEmpty) return;

      final batch   = _db.batch();
      bool  changed = false;

      for (final doc in unread.docs) {
        final data = doc.data();
        // Client-side check: only mark OTHER user's messages as read
        if ((data['senderId'] as String?) != myId) {
          batch.update(doc.reference, {'read': true});
          changed = true;
        }
      }

      if (!changed) return;

      batch.update(_db.collection('chats').doc(chatId), {
        'unreadCount.$myId': 0,
      });
      await batch.commit();
    } catch (e) {
      debugPrint('markMessagesRead error: $e');
    }
  }

  Stream<int> unreadCountStream(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .map((s) {
    final counts = s.data()?['unreadCount'] as Map<String, dynamic>?;
    return (counts?[myId] as num?)?.toInt() ?? 0;
  });

  // ── BUG FIX 3: effectiveLastMessageStream ─────────────────────────────────
  Stream<String> effectiveLastMessageStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((s) {
      final data            = s.data() ?? {};
      final lastMessage     = data['lastMessage']     as String? ?? '';
      final lastMessageTime = data['lastMessageTime'] as Timestamp?;
      final clearedAt       = data['clearedAt']       as Map<String, dynamic>?;
      final myClearedAt     = clearedAt?[myId]        as Timestamp?;

      if (myClearedAt != null && lastMessageTime != null) {
        if (!myClearedAt.toDate().isBefore(lastMessageTime.toDate())) {
          return '';
        }
      }
      return lastMessage;
    });
  }

  Stream<QuerySnapshot> messagesStream(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp')
      .snapshots();

  Stream<Timestamp?> myClearedAtStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((s) {
      final clearedAt = s.data()?['clearedAt'] as Map<String, dynamic>?;
      return clearedAt?[myId] as Timestamp?;
    });
  }

  Stream<QuerySnapshot> myChatsStream() => _db
      .collection('chats')
      .where('participants', arrayContains: myId)
      .orderBy('lastMessageTime', descending: true)
      .snapshots();

  Stream<bool> isMutedStream(String chatId) => _db
      .collection('chats')
      .doc(chatId)
      .snapshots()
      .map((s) {
    final muted = List<String>.from(s.data()?['mutedBy'] as List? ?? []);
    return muted.contains(myId);
  });

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(
      String itemId, Map<String, dynamic> itemData) async {
    final favRef = _db
        .collection('users')
        .doc(myId)
        .collection('favorites')
        .doc(itemId);
    final doc = await favRef.get();
    if (doc.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'addedAt':    FieldValue.serverTimestamp(),
        'title':      itemData['title']             ?? '',
        'image':      itemData['image']             ?? '',
        'price':      itemData['price']?.toString() ?? '',
        'sellerName': itemData['sellerName']        ?? '',
      });
    }
  }

  Stream<bool> isFavoriteStream(String itemId) {
    if (itemId.isEmpty) return Stream.value(false);
    return _db
        .collection('users')
        .doc(myId)
        .collection('favorites')
        .doc(itemId)
        .snapshots()
        .map((s) => s.exists);
  }
}