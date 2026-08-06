import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/router.dart';
import '../../core/session_store.dart';
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
  bool _hadStoredSession = false;

  bool get _canSendOtp =>
      _lastOtpRequest == null ||
      DateTime.now().difference(_lastOtpRequest!) > _otpCooldown;

  int get _otpCooldownSeconds {
    if (_lastOtpRequest == null) return 0;
    final remaining =
        _otpCooldown.inSeconds - DateTime.now().difference(_lastOtpRequest!).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

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
  void initState() {
    super.initState();
    _checkStoredSession();
  }

  Future<void> _checkStoredSession() async {
    final session = await SessionStore.read();
    if (mounted) setState(() => _hadStoredSession = session != null && session.isNotEmpty);
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
    try {
      final debugCode =
          await ref.read(authControllerProvider.notifier).requestOtp(_phoneE164);
      if (!mounted) return;
      setState(() {
        _lastOtpRequest = DateTime.now();
        _otpSent = true;
        _debugCode = debugCode;
      });
      _startCooldownTimer();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error =
            '${e.message} No code was sent, so you can retry right away.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not send the code. Check your connection and try again.');
      }
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
      final isNewUser = await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(_phoneE164, _otpController.text.trim(), referralCode: referral);
      ref.read(referralCodeProvider.notifier).set(null);
      if (mounted && isNewUser) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Welcome to Kingdom Sponsor'),
            content: const Text(
              'Your mobile number will be used for mobile money disbursement '
              'of funds raised through your campaigns. Make sure it is the number '
              'linked to your mobile money account.',
              style: TextStyle(height: 1.5),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/');
                },
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        context.go('/');
      }
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
    final auth = ref.watch(authControllerProvider);
    // Only show signed-out modal if there was a stored session that expired
    // (not for new users who never signed in)
    final authValue = auth.value;
    final showSignedOutModal = authValue?.signedOut == true && authValue?.token == null && _hadStoredSession;
    if (showSignedOutModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Session expired'),
              content: const Text(
                'Your session has expired. Please sign in again to continue.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(authControllerProvider.notifier).clearSignedOut();
                  },
                  child: const Text('Sign in'),
                ),
              ],
            ),
          );
        }
        ref.read(authControllerProvider.notifier).clearSignedOut();
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
              padding: const EdgeInsets.all(20).copyWith(
                bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Card(
                elevation: 6,
                shadowColor: Colors.black12,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/kingdom_sponsor_app_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.auto_awesome, size: 36, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 12),
                      // SMS network status notice
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.info, size: 14, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SMS verification works on Airtel & Zamtel. MTN OTP is temporarily unavailable.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textDark,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_otpSent)
                        PhoneField(
                          onChanged: (e164) => _phoneE164 = e164,
                        )
                      else
                        ...[
                          TextField(
                            controller: _otpController,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.trim().length == 6 && !_submitting) {
                                _verify();
                              }
                            },
                            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '\u2022\u2022\u2022\u2022\u2022\u2022',
                              prefixIcon: Icon(LucideIcons.shieldCheck),
                            ),
                          ),
                          if (!kReleaseMode && _debugCode != null)
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
                      if (_otpSent) ...[
                        TextButton(
                          onPressed: () => setState(() => _otpSent = false),
                          child: const Text('Change number'),
                        ),
                        TextButton(
                          onPressed:
                              _submitting || !_canSendOtp ? null : _sendOtp,
                          child: Text(!_canSendOtp
                              ? 'Resend code in ${_otpCooldownSeconds}s'
                              : 'Resend code'),
                        ),
                      ],
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
