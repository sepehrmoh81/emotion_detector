import 'package:emotion_detector/screens/emotion_detection_screen.dart';

import 'screens/license_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.camera.request();
  runApp(const EmotionDetectionApp());
}

class EmotionDetectionApp extends StatelessWidget {
  const EmotionDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emotion Detector',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
      ),
      home: const LicenseCheckScreen(),
    );
  }
}