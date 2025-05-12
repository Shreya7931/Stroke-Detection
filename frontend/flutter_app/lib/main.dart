import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
 // ✅ new home screen

void main() {
  runApp(StrokeDetectionApp());
}

class StrokeDetectionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stroke Detection App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(), // ✅ now uses HomeScreen as the landing page
    );
  }
}
