import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session token twice so users stay logged in:
/// - [FlutterSecureStorage] (encrypted, primary)
/// - [SharedPreferences] (plain-text fallback that survives Android backup
///   and device transfer, where the Keystore-protected copy cannot be
///   decrypted after a restore)
class SessionStore {
  static const key = 'kingdom_sponsor_token';
  static const _secure = FlutterSecureStorage();

  static Future<String?> read() async {
    try {
      final secure = await _secure.read(key: key);
      if (secure != null && secure.isNotEmpty) return secure;
    } catch (_) {}
    try {
      return (await SharedPreferences.getInstance()).getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String token) async {
    try {
      await _secure.write(key: key, value: token);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, token);
    } catch (_) {}
  }

  static Future<void> delete() async {
    try {
      await _secure.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
