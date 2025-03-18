import 'package:flutter/material.dart';
import 'smart_home_screen.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Initialiser les plugins Flutter
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
