import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';

class AuthState {
  final String? token;
  final String? phone;
  final bool isHost;
  final bool isAdmin;
  final String hostStatus;

  const AuthState({
    this.token,
    this.phone,
    this.isHost = false,
    this.isAdmin = false,
    this.hostStatus = 'none',
  });

  bool get loggedIn => token != null;
}

class AuthController extends AsyncNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'kingdom_sponsor_token';

  @override
  Future<AuthState> build() async {
    final token = await _storage.read(key: _tokenKey);
    final api = ref.read(apiClientProvider);
    api.token = token;
    if (token == null) return const AuthState();
    try {
      final me = await api.get('/api/host/me', auth: true);
      return AuthState(
        token: token,
        phone: me['user']?['phone'] as String?,
        isHost: me['user']?['isHost'] == true,
        isAdmin: me['user']?['isAdmin'] == true,
        hostStatus: me['user']?['hostStatus'] as String? ?? 'none',
      );
    } catch (_) {
      return const AuthState();
    }
  }

  Future<String?> requestOtp(String phone) async {
    final res = await ref.read(apiClientProvider).post('/api/auth/request-otp', {'phone': phone});
    return res['debugCode'] as String?;
  }

  Future<void> verifyOtp(String phone, String code) async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.post('/api/auth/verify-otp', {'phone': phone, 'code': code});
      final token = res['token'] as String;
      api.token = token;
      await _storage.write(key: _tokenKey, value: token);
      state = AsyncValue.data(AuthState(
        token: token,
        phone: res['user']?['phone'] as String?,
        isHost: res['user']?['isHost'] == true,
        isAdmin: res['user']?['isAdmin'] == true,
        hostStatus: res['user']?['hostStatus'] as String? ?? 'none',
      ));
    } on ApiException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    ref.read(apiClientProvider).token = null;
    state = const AsyncValue.data(AuthState());
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
