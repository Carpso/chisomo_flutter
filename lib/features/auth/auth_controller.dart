import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/push_service.dart';
import '../../core/session_store.dart';
import '../campaigns/campaigns_controller.dart';

class AuthState {
  final String? token;
  final String? phone;
  final String? username;
  final String? name;
  final String? avatarUrl;
  final bool isHost;
  final bool isAdmin;
  final Set<String> assistantScopes;
  final String hostStatus;
  final bool signedOut;

  const AuthState({
    this.token,
    this.phone,
    this.username,
    this.name,
    this.avatarUrl,
    this.isHost = false,
    this.isAdmin = false,
    this.assistantScopes = const {},
    this.hostStatus = 'none',
    this.signedOut = false,
  });

  bool get loggedIn => token != null;

  /// True when this account can reach the admin dashboard: a superadmin, or an
  /// assistant with at least one permission scope.
  bool get isStaff => isAdmin || assistantScopes.isNotEmpty;

  /// True when this account holds the given permission scope (superadmins
  /// always pass, matching the backend's requireStaff).
  bool canScope(String scope) => isAdmin || assistantScopes.contains(scope);

  AuthState copyWith({String? username, String? name, String? avatarUrl, bool? signedOut}) => AuthState(
        token: token,
        phone: phone,
        username: username ?? this.username,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isHost: isHost,
        isAdmin: isAdmin,
        assistantScopes: assistantScopes,
        hostStatus: hostStatus,
        signedOut: signedOut ?? this.signedOut,
      );
}

class AuthController extends AsyncNotifier<AuthState> {
  static const tokenStorageKey = ApiClient.tokenStorageKey;

  @override
  Future<AuthState> build() async {
    final token = await SessionStore.read();
    final api = ref.read(apiClientProvider);
    api.token = token;
    if (token == null) return const AuthState();

    Map<String, dynamic>? me;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        me = await api.get('/api/host/me', auth: true);
        break;
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          // Token is no longer valid: clear it and sign out for real.
          await SessionStore.delete();
          api.token = null;
          return const AuthState();
        }
      } catch (_) {}
      if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
    }

    // Transient failure (server briefly unreachable, e.g. right after an app
    // update): keep the session instead of logging the user out.
    final user = me?['user'];
    if (user == null) return AuthState(token: token);

    return AuthState(
      token: token,
      phone: user['phone'] as String?,
      username: user['username'] as String?,
      name: user['name'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      isHost: user['isHost'] == true,
      isAdmin: user['isAdmin'] == true,
      assistantScopes: (user['assistantScopes'] as List<dynamic>? ?? const [])
          .map((s) => s.toString())
          .toSet(),
      hostStatus: user['hostStatus'] as String? ?? 'none',
    );
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

  Future<bool> verifyOtp(String phone, String code, {String? referralCode}) async {
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
      await SessionStore.write(token);
      state = AsyncValue.data(AuthState(
        token: token,
        phone: res['user']?['phone'] as String?,
        username: res['user']?['username'] as String?,
        name: res['user']?['name'] as String?,
        avatarUrl: res['user']?['avatarUrl'] as String?,
        isHost: res['user']?['isHost'] == true,
        isAdmin: res['user']?['isAdmin'] == true,
        assistantScopes: (res['user']?['assistantScopes'] as List<dynamic>? ?? const [])
            .map((s) => s.toString())
            .toSet(),
        hostStatus: res['user']?['hostStatus'] as String? ?? 'none',
      ));
      _resetData();
      unawaited(ensurePushRegistered());
      return res['isNewUser'] == true;
    } on ApiException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  void setSignedOut() {
    final current = state.value ?? const AuthState();
    state = AsyncValue.data(current.copyWith(signedOut: true));
  }

  void clearSignedOut() {
    final current = state.value ?? const AuthState();
    if (current.signedOut) {
      state = AsyncValue.data(current.copyWith(signedOut: false));
    }
  }

  Future<void> logout() async {
    await SessionStore.delete();
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

/// Bumped whenever linked-account state changes (accept/reject/unlink). The
/// Settings screen watches this so a returning `context.go('/settings')` that
/// reuses the mounted route still refreshes its links list.
class LinksVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final linksVersionProvider = NotifierProvider<LinksVersion, int>(LinksVersion.new);
