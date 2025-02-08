import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../wrappers/SecureStorageWrapper.dart';
import 'emotion_detection_screen.dart';
import 'license_verification_screen.dart';

class LicenseCheckScreen extends StatefulWidget {
  const LicenseCheckScreen({super.key});

  @override
  State<LicenseCheckScreen> createState() => _LicenseCheckScreenState();
}

class _LicenseCheckScreenState extends State<LicenseCheckScreen> {
  final SecureStorageWrapper storage = SecureStorageWrapper();

  @override
  void initState() {
    super.initState();
    _initializeAndCheck();
  }

  Future<void> _initializeAndCheck() async {
    await storage.init();
    await _checkLicenseStatus();
  }

  Future<void> _checkLicenseStatus() async {
    final verified = await storage.read('license_verified');
    final storedUuid = await storage.read('uuid');

    if (verified == 'true' && storedUuid != null) {
      // Verify the stored UUID hasn't been tampered with
      final validationHash = await storage.read('validation_hash');
      if (validationHash == _generateValidationHash(storedUuid)) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const EmotionDetectionScreen()),
        );
        return;
      }
    }

    // Generate new UUID if not verified or validation failed
    final uuid = const Uuid().v7();
    await storage.write('uuid', uuid);
    await storage.write('validation_hash', _generateValidationHash(uuid));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (context) => LicenseVerificationScreen(uuid: uuid)),
    );
  }

  String _generateValidationHash(String uuid) {
    final key = 'This is property of © Raman AI. PLEASE DO NOT STEAL!';
    final bytes = utf8.encode(uuid + key);
    return sha256.convert(bytes).toString();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
