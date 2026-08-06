import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_sponsor_app/features/auth/auth_controller.dart';

void main() {
  group('AuthState.copyWith', () {
    const base = AuthState(
      token: 'tok',
      phone: '+260970000000',
      username: 'giver1',
      name: 'Giver One',
      avatarUrl: 'https://example.com/a.png',
      isHost: true,
      isAdmin: false,
      hostStatus: 'approved',
    );

    test('preserves untouched fields', () {
      final updated = base.copyWith(username: 'giver2');
      expect(updated.token, 'tok');
      expect(updated.phone, '+260970000000');
      expect(updated.username, 'giver2');
      expect(updated.name, 'Giver One');
      expect(updated.avatarUrl, 'https://example.com/a.png');
      expect(updated.isHost, isTrue);
      expect(updated.isAdmin, isFalse);
      expect(updated.hostStatus, 'approved');
    });

    test('updates name and avatarUrl', () {
      final updated = base.copyWith(
        name: 'Giver Two',
        avatarUrl: 'https://example.com/b.png',
      );
      expect(updated.name, 'Giver Two');
      expect(updated.avatarUrl, 'https://example.com/b.png');
      expect(updated.username, 'giver1');
    });

    test('copyWith on empty AuthState keeps loggedOut state', () {
      final updated = const AuthState().copyWith(username: 'x');
      expect(updated.loggedIn, isFalse);
      expect(updated.username, 'x');
    });
  });
}
