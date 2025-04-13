import 'package:flutter/material.dart';
import 'screens/register_screen.dart';
import 'screens/video_capture_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stroke Detection App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => RegisterScreen(),
        '/videoCapture': (context) => VideoCaptureScreen(),
      },
    );
  }
}
