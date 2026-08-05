import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../campaigns/campaigns_controller.dart';

class AuthState {
  final String? token;
  final String? phone;
  final String? username;
  final String? name;
  final String? avatarUrl;
  final bool isHost;
  final bool isAdmin;
  final String hostStatus;

  const AuthState({
    this.token,
    this.phone,
    this.username,
    this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isAdmin = false,
    this.hostStatus = 'none',
  });

  bool get loggedIn => token != null;

  AuthState copyWith({String? username, String? name, String? avatarUrl}) => AuthState(
        token: token,
        phone: phone,
        username: username ?? this.username,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isHost: isHost,
        isAdmin: isAdmin,
        hostStatus: hostStatus,
      );
}

class AuthController extends AsyncNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();
  static const tokenStorageKey = ApiClient.tokenStorageKey;

  @override
  Future<AuthState> build() async {
    final token = await _storage.read(key: tokenStorageKey);
    final api = ref.read(apiClientProvider);
    api.token = token;
    if (token == null) return const AuthState();
    try {
      final me = await api.get('/api/host/me', auth: true);
      return AuthState(
        token: token,
        phone: me['user']?['phone'] as String?,
        username: me['user']?['username'] as String?,
        name: me['user']?['name'] as String?,
        avatarUrl: me['user']?['avatarUrl'] as String?,
        isHost: me['user']?['isHost'] == true,
        isAdmin: me['user']?['isAdmin'] == true,
        hostStatus: me['user']?['hostStatus'] as String? ?? 'none',
      );
    } catch (_) {
      return const AuthState();
    }
  }

  /// Forget every cached provider so screens reload for the new account
  /// (same phone sharing multiple numbers used to show stale data until
  /// the user pulled to refresh several times).
  void _resetData() {
    ref.invalidate(campaignsProvider);
    ref.invalidate(hostProvider);
    ref.invalidate(pledgesProvider);
    ref.invalidate(adminDataProvider);
    ref.invalidate(adminLedgerProvider);
    ref.invalidate(promotionsProvider);
    ref.invalidate(promotionInfoProvider);
    ref.invalidate(myPromotionsProvider);
  }

  Future<String?> requestOtp(String phone) async {
    final res = await ref.read(apiClientProvider).post('/api/auth/request-otp', {'phone': phone});
    return res['debugCode'] as String?;
  }

  Future<void> verifyOtp(String phone, String code, {String? referralCode}) async {
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.post('/api/auth/verify-otp', {
        'phone': phone,
        'code': code,
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referralCode': referralCode.trim(),
      });
      final token = res['token'] as String;
      api.token = token;
      await _storage.write(key: tokenStorageKey, value: token);
      state = AsyncValue.data(AuthState(
        token: token,
        phone: res['user']?['phone'] as String?,
        username: res['user']?['username'] as String?,
        name: res['user']?['name'] as String?,
        avatarUrl: res['user']?['avatarUrl'] as String?,
        isHost: res['user']?['isHost'] == true,
        isAdmin: res['user']?['isAdmin'] == true,
        hostStatus: res['user']?['hostStatus'] as String? ?? 'none',
      ));
      _resetData();
    } on ApiException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: tokenStorageKey);
    ref.read(apiClientProvider).token = null;
    state = const AsyncValue.data(AuthState());
    _resetData();
  }

  /// Updates the display name/username on the server and in local auth state.
  Future<void> saveProfile({String? name, String? username}) async {
    final res = await ref.read(apiClientProvider).updateProfile(
          name: name,
          username: username == null || username.trim().isEmpty ? null : username.trim(),
        );
    final current = state.value ?? const AuthState();
    state = AsyncValue.data(AuthState(
      token: current.token,
      phone: current.phone,
      username: res['user']?['username'] as String? ?? current.username,
      name: res['user']?['name'] as String?,
      avatarUrl: current.avatarUrl,
      isHost: current.isHost,
      isAdmin: current.isAdmin,
      hostStatus: current.hostStatus,
    ));
  }

  /// Saves the uploaded profile photo URL into local auth state.
  void setAvatar(String url) {
    final current = state.value ?? const AuthState();
    state = AsyncValue.data(current.copyWith(avatarUrl: url));
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
