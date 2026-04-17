import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fixio/routes/app_routes.dart';
import '../services/firebase_auth_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FixioApp());
}


class FixioApp extends StatelessWidget {
  const FixioApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
      ),
    );
  }
}