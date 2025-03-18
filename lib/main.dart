import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'smart_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Initialiser les plugins Flutter
  await Firebase.initializeApp(); // 🔥 Initialisation Firebase ici
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Home App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SmartHomeScreen(),
    );
  }
}