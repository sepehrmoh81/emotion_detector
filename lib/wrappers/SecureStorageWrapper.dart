import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageWrapper {
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _fallbackStorage;
  bool _useSecureStorage = true;

  SecureStorageWrapper({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
      const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

  Future<void> init() async {
    _fallbackStorage = await SharedPreferences.getInstance();
  }

  Future<void> write(String key, String value) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.write(key: key, value: value);
      } catch (e) {
        _useSecureStorage = false;
        await _fallbackStorage?.setString(key, value);
      }
    } else {
      await _fallbackStorage?.setString(key, value);
    }
  }

  Future<String?> read(String key) async {
    if (_useSecureStorage) {
      try {
        return await _secureStorage.read(key: key);
      } catch (e) {
        _useSecureStorage = false;
        return _fallbackStorage?.getString(key);
      }
    }
    return _fallbackStorage?.getString(key);
  }
}