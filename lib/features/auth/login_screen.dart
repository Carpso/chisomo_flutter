import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/router.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/phone_field.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _otpController = TextEditingController();
  String _phoneE164 = '';
  bool _otpSent = false;
  bool _submitting = false;
  String? _error;
  String? _debugCode;
  DateTime? _lastOtpRequest;
  Timer? _cooldownTimer;
  static const _otpCooldown = Duration(seconds: 30);

  bool get _canSendOtp =>
      _lastOtpRequest == null ||
      DateTime.now().difference(_lastOtpRequest!) > _otpCooldown;

  int get _otpCooldownSeconds => _lastOtpRequest == null
      ? 0
      : _otpCooldown.inSeconds -
          DateTime.now().difference(_lastOtpRequest!).inSeconds;

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_canSendOtp) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _submitting = true;
      _error = null;
      _debugCode = null;
    });
    _lastOtpRequest = DateTime.now();
    _startCooldownTimer();
    try {
      final debugCode =
          await ref.read(authControllerProvider.notifier).requestOtp(_phoneE164);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _debugCode = debugCode;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final referral = ref.read(referralCodeProvider);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(_phoneE164, _otpController.text.trim(), referralCode: referral);
      ref.read(referralCodeProvider.notifier).set(null);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFE9DD), Color(0xFFFFF5EC), AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black12,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/kingdom_sponsor_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Kingdom Sponsor',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _otpSent
                            ? 'Enter the 6-digit code sent to your phone'
                            : 'Sign in with your mobile number to give or fundraise',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 28),
                      if (!_otpSent)
                        PhoneField(
                          onChanged: (e164) => _phoneE164 = e164,
                        )
                      else
                        ...[
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '\u2022\u2022\u2022\u2022\u2022\u2022',
                              prefixIcon: Icon(LucideIcons.shieldCheck),
                            ),
                          ),
                          if (_debugCode != null)
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Sandbox code',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    _debugCode!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 8,
                                      fontFamily: 'Courier',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      if (_error != null)
                        ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                      const SizedBox(height: 20),
                       ElevatedButton(
                         onPressed: _submitting || (!_otpSent && !_canSendOtp)
                             ? null
                             : (_otpSent ? _verify : _sendOtp),
                         child: _submitting
                             ? SizedBox(
                                 width: 22,
                                 height: 22,
                                 child: AppIconSpinner(size: 22),
                               )
                             : _otpSent
                                 ? Text('Verify code')
                                 : !_canSendOtp
                                     ? Text('Wait ${_otpCooldownSeconds}s')
                                     : Text('Send code'),
                       ),
                      if (_otpSent)
                        TextButton(
                          onPressed: () => setState(() => _otpSent = false),
                          child: const Text('Change number'),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Hosting a fundraiser? Sign in, open the "Host" tab, then tap "New campaign".',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
