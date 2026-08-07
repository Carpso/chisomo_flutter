import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the session token using encrypted storage only.
class SessionStore {
  static const key = 'kingdom_sponsor_token';
  static const _secure = FlutterSecureStorage();

  static Future<String?> read() async {
    try {
      return await _secure.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String token) async {
    await _secure.write(key: key, value: token);
  }

  static Future<void> delete() async {
    await _secure.delete(key: key);
  }
}
