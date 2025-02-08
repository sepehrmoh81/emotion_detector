import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wrappers/SecureStorageWrapper.dart';
import 'emotion_detection_screen.dart';

class LicenseVerificationScreen extends StatefulWidget {
  final String uuid;

  const LicenseVerificationScreen({super.key, required this.uuid});

  @override
  State<LicenseVerificationScreen> createState() => _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState extends State<LicenseVerificationScreen> {
  final SecureStorageWrapper storage = SecureStorageWrapper();
  final TextEditingController _licenseController = TextEditingController();

  Future<void> _verifyLicense() async {
    final inputLicense = _licenseController.text.trim();
    final bytes = utf8.encode(widget.uuid);
    final hash = sha256.convert(bytes).toString();
    final correctLicense = hash.substring(8, 24);

    if (inputLicense == correctLicense) {
      await storage.write('license_verified', 'true');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const EmotionDetectionScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid license key')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('License Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please enter your license key to activate the app',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        widget.uuid,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.uuid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('UUID copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _licenseController,
              decoration: const InputDecoration(
                labelText: 'License Key',
                border: OutlineInputBorder(),
                hintText: 'Enter your license key',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyLicense,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                child: Text(
                  'Verify License',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
