import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny JSON cache in SharedPreferences so the app still shows the last
/// known data when the network is unavailable (offline mode).
class OfflineCache {
  Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_cache_$key');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_cache_$key', jsonEncode(json));
  }

  Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_cache_$key');
  }
}

final offlineCacheProvider = Provider<OfflineCache>((ref) => OfflineCache());

/// True while the app is showing cached data because the API is unreachable.
class OfflineMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final offlineModeProvider = NotifierProvider<OfflineMode, bool>(OfflineMode.new);
