import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/phone_field.dart';
import '../auth/auth_controller.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

import '../../core/receipt_service.dart';

/// Returns the USSD short code for mobile money prompts on the donor's phone.
/// Lipila triggers the payment prompt via the carrier's mobile money gateway.
/// The universal fallback USSD code for checking mobile money on all Zambian carriers is *115#.
String ussdCodeForPhone(String phoneE164) {
  // Lipila sends the USSD prompt to the donor's phone automatically.
  // If the donor doesn't receive it, dial *115# to check mobile money
  // on MTN, Airtel, or Zamtel — works across all Zambian networks.
  return '*115#';
}

class DonateScreen extends ConsumerStatefulWidget {
  final int campaignId;

  const DonateScreen({super.key, required this.campaignId});

  @override
  ConsumerState<DonateScreen> createState() => _DonateScreenState();
}

enum _Phase { form, awaitingPin, done, failed }

enum _PaymentMethod { mobileMoney, card }

class _DonateScreenState extends ConsumerState<DonateScreen> {
  static const _presets = [5000, 10000, 20000, 50000, 100000];

  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _phoneE164 = '';
  int _selectedPreset = 10000;
  bool _anonymous = false;
  bool _hideAmount = false;
  bool _submitting = false;
  bool _recurring = false;
  int _recurringDay = 1;
  _PaymentMethod _method = _PaymentMethod.mobileMoney;
  String? _checkoutUrl;

  _Phase _phase = _Phase.form;
  String? _referenceId;
  int? _contributionId;
  String? _error;
  String? _statusMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider).value;
    if (auth?.phone != null) _phoneE164 = auth!.phone!;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int get _amountCents {
    if (_selectedPreset > 0) return _selectedPreset;
    final text = _amountController.text.replaceAll(',', '').trim();
    final kwacha = double.tryParse(text) ?? 0;
    return (kwacha * 100).round();
  }

  /// Calculate total processing fees (platform + Lipila) for the current amount
  /// and payment method. Cards: 2% (K5 min) + ZMW 0.24 + Lipila's card fee.
  /// Returns null if fees config is unavailable — caller must handle.
  ({int platformFee, int lipilaFee, int totalFee, int totalPay})? _calculateFees(FeesInfo? cfg) {
    final amount = _amountCents;
    if (amount < 100 || cfg == null) return null;
    final isCard = _method == _PaymentMethod.card;
    final pct = isCard ? cfg.cardPct : cfg.platformPct;
    final minFee = isCard ? cfg.cardMinFeeCents : cfg.platformMinFeeCents;
    final lipilaPct = isCard ? cfg.cardLipilaPct : cfg.momoPct;
    final platform = minFee > (amount * pct / 100).round()
        ? minFee
        : (amount * pct / 100).round();
    final platformFee = platform + cfg.platformFixedFeeCents;
    final lipilaFee = (amount * lipilaPct / 100).round();
    return (platformFee: platformFee, lipilaFee: lipilaFee, totalFee: platformFee + lipilaFee, totalPay: amount + platformFee + lipilaFee);
  }

  static int? _suggested(int avgCents) {
    if (avgCents < 100) return null;
    final s = ((avgCents + 2500) ~/ 5000) * 5000;
    return s <= 0 ? null : s;
  }

  Future<void> _donate() async {
    final amountCents = _amountCents;
    if (amountCents < 100) {
      setState(() => _error = 'Enter an amount of at least K1.');
      return;
    }
    final phone = _phoneE164;
    if (phone.isEmpty) {
      setState(
        () => _error =
            'Enter your mobile number so we can send you a payment prompt.',
      );
      return;
    }
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      setState(
        () => _error = 'Enter a complete mobile number (e.g. +260 977 123 456).',
      );
      return;
    }
    if (_method == _PaymentMethod.card) {
      final email = _emailController.text.trim();
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        setState(() => _error = 'Enter your email address for the card receipt.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final path = _method == _PaymentMethod.card
          ? '/api/campaigns/${widget.campaignId}/contribute-card'
          : '/api/campaigns/${widget.campaignId}/contribute';
      final res = await ref.read(apiClientProvider).post(path, {
        'amountCents': amountCents,
        'phone': phone,
        'donorName': _anonymous ? null : _nameController.text.trim(),
        'isAnonymous': _anonymous,
        'hideAmount': _hideAmount,
        if (_method == _PaymentMethod.card) 'email': _emailController.text.trim(),
      });
      setState(() {
        _referenceId = res['referenceId'] as String;
        _phase = _Phase.awaitingPin;
      });
      if (_method == _PaymentMethod.card) {
        final url = res['cardRedirectionUrl'] as String? ?? '';
        _checkoutUrl = url;
        if (url.isNotEmpty) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          setState(() => _statusMessage = 'Checkout link not available yet.');
        }
      }
      _pollStatus();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reopenCheckout() async {
    final url = _checkoutUrl;
    if (url == null || url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _resendPrompt() async {
    final refId = _referenceId;
    if (refId == null) return;
    setState(() => _error = null);
    try {
      final res = await ref.read(apiClientProvider).resendPrompt(refId);
      if (mounted) {
        setState(() {
          _referenceId = res['referenceId'] as String? ?? refId;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new payment prompt has been sent.')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not resend. Try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resend the prompt. Try again.')),
        );
      }
    }
  }

  void _pollStatus() {
    _pollTimer?.cancel();
    var polls = 0;
    var consecutiveErrors = 0;
    final maxPolls = _method == _PaymentMethod.card ? 160 : 40; // card: ~8 min
    const maxConsecutiveErrors = 5;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      polls++;
      if (polls > maxPolls) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _phase = _Phase.failed;
            _statusMessage =
                'We are still waiting for your payment. If you completed it, '
                'it may take a moment to reflect — check your receipts shortly.';
          });
        }
        return;
      }
      try {
        final res = await ref
            .read(apiClientProvider)
            .get('/api/contributions/status/$_referenceId');
        consecutiveErrors = 0;
        final status = res['status'] as String? ?? 'pending';
        final contributionId = res['id'] as int?;
        if (contributionId != null) {
          _contributionId = contributionId;
        }
        if (status == 'confirmed') {
          timer.cancel();
          if (mounted) {
            if (_recurring) {
              try {
                await ref
                    .read(apiClientProvider)
                    .createPledge(
                      widget.campaignId,
                      _amountCents,
                      _recurringDay,
                    );
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Payment received, but we could not set up your '
                        'monthly pledge. You can add it from the Pledges tab.',
                      ),
                    ),
                  );
                }
              }
            }
            setState(() => _phase = _Phase.done);
            ref.invalidate(campaignDetailProvider(widget.campaignId));
            ref.invalidate(campaignsProvider);
          }
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) setState(() => _phase = _Phase.failed);
        }
      } catch (_) {
        consecutiveErrors++;
        if (consecutiveErrors >= maxConsecutiveErrors) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _phase = _Phase.failed;
              _statusMessage =
                  'Could not reach the payment service. Your payment may '
                  'still be pending — check your receipts before trying again.';
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Give')),
      body: switch (_phase) {
        _Phase.form => _buildForm(context),
        _Phase.awaitingPin => _AwaitingPin(
          referenceId: _referenceId ?? '',
          phoneE164: _phoneE164,
          isCard: _method == _PaymentMethod.card,
          onResend: _resendPrompt,
          onReopenCheckout: _reopenCheckout,
          onCancel: () {
            _pollTimer?.cancel();
            setState(() {
              _phase = _Phase.form;
              _error = null;
            });
          },
        ),
        _Phase.done => _buildDone(context),
        _Phase.failed => _buildFailed(context),
      },
    );
  }

  /// Shows the exact name this donor will appear under on the donor list:
  /// "Anonymous", their typed name, or their account username/display name.
  String _donorListLabel() {
    if (_anonymous) return 'You\'ll appear as Anonymous on the donor list.';
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) return 'You\'ll appear on the donor list as $typed.';
    final auth = ref.watch(authControllerProvider).value;
    final username = auth?.username?.trim();
    if (username != null && username.isNotEmpty) {
      return 'You\'ll appear on the donor list as $username.';
    }
    final name = auth?.name?.trim();
    if (name != null && name.isNotEmpty) {
      return 'You\'ll appear on the donor list as $name.';
    }
    return 'You\'ll appear on the donor list with your account name.';
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(campaignDetailProvider(widget.campaignId)).value;
    final avg = detail?.campaign.avgDonationCents ?? 0;
    final suggested = _suggested(avg);

    return ListView(
      padding: EdgeInsets.all(16).copyWith(
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      children: [
        if (suggested != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _selectedPreset = 0;
                  _amountController.text = '${suggested ~/ 100}';
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.lightbulb,
                        size: 18,
                        color: Color(0xFF8A6A00),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Most people give around ${formatKwacha(suggested)}. Tap to match the average.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Text(
          'Choose an amount',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text(formatKwacha(preset)),
                selected: _selectedPreset == preset,
                onSelected: (_) => setState(() {
                  _selectedPreset = preset;
                  _amountController.clear();
                }),
              ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _selectedPreset == 0,
              onSelected: (_) => setState(() => _selectedPreset = 0),
            ),
          ],
        ),
        if (_selectedPreset == 0)
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (K)',
              prefixIcon: Icon(LucideIcons.wallet),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'How would you like to pay?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_PaymentMethod>(
          segments: const [
            ButtonSegment(
              value: _PaymentMethod.mobileMoney,
              icon: Icon(LucideIcons.smartphone, size: 18),
              label: Text('Mobile Money'),
            ),
            ButtonSegment(
              value: _PaymentMethod.card,
              icon: Icon(LucideIcons.creditCard, size: 18),
              label: Text('Card'),
            ),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        if (_method == _PaymentMethod.card) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address (for your receipt)',
              hintText: 'e.g. you@example.com',
              prefixIcon: Icon(LucideIcons.mail),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Fee preview card — rebuilt locally on each keystroke via the
        // controller so the rest of the form (and field focus) stays intact.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _amountController,
          builder: (context, _, _) =>
              _amountCents >= 100 ? _buildFeeCard(context, detail?.fees) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Your name (optional)',
            hintText: 'e.g. Pastor John',
            prefixIcon: Icon(LucideIcons.user),
          ),
        ),
        const SizedBox(height: 12),
        PhoneField(
          initialValue: _phoneE164.isEmpty ? null : _phoneE164,
          onChanged: (e164) => _phoneE164 = e164,
          helperText: _method == _PaymentMethod.card
              ? 'Linked to your account for receipts and updates'
              : 'We will send a payment prompt to this number',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show as anonymous'),
          subtitle: const Text('Your name will not appear on the donor list'),
          value: _anonymous,
          onChanged: (v) => setState(() => _anonymous = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide the amount'),
          subtitle: const Text('Your contribution amount stays private'),
          value: _hideAmount,
          onChanged: (v) => setState(() => _hideAmount = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Give every month (reminder)'),
          subtitle: const Text(
            'Get an SMS on the same day each month to give again',
          ),
          value: _recurring,
          onChanged: (v) => setState(() => _recurring = v),
        ),
        if (_recurring)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
            child: DropdownButtonFormField<int>(
              initialValue: _recurringDay,
              decoration: const InputDecoration(
                labelText: 'Reminder day (1-28)',
                prefixIcon: Icon(LucideIcons.calendarDays),
              ),
              items: List.generate(28, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (v) => setState(() => _recurringDay = v ?? 1),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.sparkles,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _donorListLabel(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: (_submitting || _amountCents < 100) ? null : _donate,
          icon: _submitting
              ? const SizedBox.shrink()
              : Icon(
                  _method == _PaymentMethod.card
                      ? LucideIcons.creditCard
                      : LucideIcons.heartHandshake,
                ),
          label: _submitting
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: AppIconSpinner(size: 22, color: Colors.white),
                )
              : Text(
                  _method == _PaymentMethod.card
                      ? 'Continue to secure checkout'
                      : 'Donate ${_amountCents >= 100 ? formatKwacha(_amountCents) : ''}',
                ),
        ),
        const SizedBox(height: 8),
        _buildFeeNote(context, detail?.fees),
      ],
    );
  }

  Widget _buildFeeCard(BuildContext context, FeesInfo? fees) {
    final f = _calculateFees(fees);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Donation', style: TextStyle(color: AppColors.textMuted)),
              Text(formatKwacha(_amountCents), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          if (f != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Processing fees', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text('+${formatKwacha(f.totalFee)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('You will pay', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(formatKwacha(f.totalPay), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeeNote(BuildContext context, FeesInfo? fees) {
    final theme = Theme.of(context);
    final fixed = fees?.platformFixedFeeCents ?? 24;
    final isCard = _method == _PaymentMethod.card;
    final paymentLine = isCard
        ? 'You will be redirected to a secure card checkout.'
        : 'You will get a payment prompt on your phone.';
    final String text;
    if (fees == null) {
      text = 'A small processing fee (${formatKwacha(fixed)} + Lipila charges) applies. $paymentLine';
    } else if (isCard) {
      text = 'Processing fees (${formatKwacha(fixed)} + ${formatPct(fees.cardPct)} '
            '(${formatKwacha(fees.cardMinFeeCents)} minimum) + Lipila card charges) apply. '
            '$paymentLine';
    } else {
      text = 'Processing fees (${formatKwacha(fixed)} + ${formatPct(fees.platformPct)} '
            '(${formatKwacha(fees.platformMinFeeCents)} minimum) + Lipila charges) apply. '
            '$paymentLine';
    }
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final contributionId = _contributionId;
    final receiptState = contributionId == null
        ? null
        : ref.watch(receiptControllerProvider)[contributionId];
    final isDownloaded = receiptState?.isDownloaded ?? false;
    final isBusy =
        (receiptState?.isLoading ?? false) ||
        (receiptState?.isOpening ?? false);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.badgeCheck,
              size: 72,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Thank you!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation is confirmed. The host has been notified and the funds will reach them quickly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            if (contributionId != null) ...[
              OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => ref
                          .read(receiptControllerProvider.notifier)
                          .downloadThenView(context, ref, contributionId),
                icon: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isDownloaded ? LucideIcons.eye : LucideIcons.download,
                        size: 18,
                      ),
                label: Text(
                  isDownloaded
                      ? 'Open receipt'
                      : (isBusy ? 'Downloading…' : 'Download receipt'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to campaigns'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.xCircle, size: 72, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Payment not completed',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'The payment was cancelled or did not go through. You can try again.',
              textAlign: TextAlign.center,
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() => _phase = _Phase.form),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwaitingPin extends ConsumerWidget {
  final String referenceId;
  final String phoneE164;
  final bool isCard;
  final VoidCallback onResend;
  final VoidCallback onReopenCheckout;
  final VoidCallback onCancel;

  const _AwaitingPin({
    required this.referenceId,
    required this.phoneE164,
    required this.isCard,
    required this.onResend,
    required this.onReopenCheckout,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ussd = ussdCodeForPhone(phoneE164);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: AppIconSpinner(size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              isCard ? 'Complete your payment' : 'Check your phone',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isCard
                  ? 'We opened a secure checkout for your card. Finish the payment there to complete your donation.'
                  : 'We have sent a payment prompt to your mobile money. Enter your PIN to complete the donation.',
              textAlign: TextAlign.center,
            ),
            if (!isCard) ...[
              const SizedBox(height: 8),
              Text(
                'If you don\'t see it, dial $ussd on your phone.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            if (isCard)
              OutlinedButton.icon(
                onPressed: onReopenCheckout,
                icon: const Icon(LucideIcons.creditCard, size: 16),
                label: const Text('Reopen checkout'),
              )
            else
              OutlinedButton.icon(
                onPressed: onResend,
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Resend prompt'),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCancel,
              child: const Text('Cancel donation'),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: $referenceId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
