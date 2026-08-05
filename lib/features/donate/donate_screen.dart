import 'dart:async';
import 'dart:math' as math;
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

class _DonateScreenState extends ConsumerState<DonateScreen> {
  static const _presets = [5000, 10000, 20000, 50000, 100000];

  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  String _phoneE164 = '';
  int _selectedPreset = 10000;
  bool _anonymous = false;
  bool _hideAmount = false;
  bool _submitting = false;
  bool _recurring = false;
  int _recurringDay = 1;

  _Phase _phase = _Phase.form;
  String? _referenceId;
  int? _contributionId;
  String? _error;
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
    super.dispose();
  }

  int get _amountCents {
    if (_selectedPreset > 0) return _selectedPreset;
    return (double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0).round() * 100;
  }

  static int? _suggested(int avgCents) {
    if (avgCents < 100) return null;
    final s = avgCents ~/ 5000 * 5000;
    if (s <= 0) return null;
    return s == avgCents ? avgCents : s + 5000;
  }

  Future<void> _donate() async {
    final amountCents = _amountCents;
    if (amountCents < 100) {
      setState(() => _error = 'Enter an amount of at least K1');
      return;
    }
    final phone = _phoneE164;
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your mobile number so we can send you a payment prompt');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).post(
            '/api/campaigns/${widget.campaignId}/contribute',
            {
              'amountCents': amountCents,
              'phone': phone,
              'donorName': _anonymous ? null : _nameController.text.trim(),
              'isAnonymous': _anonymous,
              'hideAmount': _hideAmount,
            },
          );
      setState(() {
        _referenceId = res['referenceId'] as String;
        _phase = _Phase.awaitingPin;
      });
      _pollStatus();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not resend. Try again.');
      }
    }
  }

  void _pollStatus() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final res = await ref
            .read(apiClientProvider)
            .get('/api/contributions/status/$_referenceId');
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
                await ref.read(apiClientProvider).createPledge(
                      widget.campaignId,
                      _amountCents,
                      _recurringDay,
                    );
              } catch (_) {}
            }
            setState(() => _phase = _Phase.done);
            ref.invalidate(campaignDetailProvider(widget.campaignId));
            ref.invalidate(campaignsProvider);
          }
        } else if (status == 'failed') {
          timer.cancel();
          if (mounted) setState(() => _phase = _Phase.failed);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Give')),
      body: switch (_phase) {
        _Phase.form => _buildForm(context),
       _Phase.awaitingPin => _AwaitingPin(
              referenceId: _referenceId ?? '',
              phoneE164: _phoneE164,
              onResend: _resendPrompt,
            ),
        _Phase.done => _buildDone(context),
        _Phase.failed => _buildFailed(context),
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(campaignDetailProvider(widget.campaignId)).value;
    final avg = detail?.campaign.avgDonationCents ?? 0;
    final suggested = _suggested(avg);

    return ListView(
      padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.lightbulb, size: 18, color: Color(0xFF8A6A00)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Most people give around ${formatKwacha(suggested)}. Tap to match the average.',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textDark),
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
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        if (_selectedPreset == 0) ...[
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountController,
            builder: (context, _, _) =>
                _buildFeeBreakdown(context, detail?.fees),
          ),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (K)',
              prefixIcon: Icon(LucideIcons.wallet),
            ),
          ),
        ],
        if (_selectedPreset > 0) _buildFeeBreakdown(context, detail?.fees),
        const SizedBox(height: 20),
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
          helperText: 'We will send a payment prompt to this number',
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
          subtitle: const Text('Get an SMS on the same day each month to give again'),
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
              const Icon(LucideIcons.sparkles, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You\'ll appear on the donor list with a fun giver name, like '
                  'GenerousGiver664',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: (_submitting || _amountCents < 100) ? null : _donate,
          icon: const Icon(LucideIcons.heartHandshake),
          label: _submitting
               ? SizedBox(
                   width: 22, height: 22,
                   child: AppIconSpinner(size: 22, color: Colors.white),
                 )
              : Text('Donate ${_amountCents >= 100 ? formatKwacha(_amountCents) : ''}'),
        ),
        const SizedBox(height: 8),
        _buildFeeNote(context, detail?.fees),
      ],
    );
  }

  Widget _buildFeeBreakdown(BuildContext context, FeesInfo? fees) {
    final theme = Theme.of(context);
    final amountCents = _amountCents;
    if (fees == null || amountCents < 100) return const SizedBox.shrink();
    final platform =
        math.max(fees.platformMinFeeCents, (amountCents * fees.platformPct / 100).round());
    final momo = (amountCents * fees.momoPct / 100).round();
    final total = amountCents + platform + momo;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You will pay ${formatKwacha(total)}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatKwacha(amountCents)} donation + ${formatKwacha(platform)} platform fee + ${formatKwacha(momo)} mobile money',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeNote(BuildContext context, FeesInfo? fees) {
    final theme = Theme.of(context);
    final text = fees == null
        ? 'A small platform fee and mobile money charges apply. You will get a payment prompt on your phone.'
        : 'A platform fee of ${formatKwacha(fees.platformMinFeeCents)} minimum (${formatPct(fees.platformPct)} above that) plus ${formatPct(fees.momoPct)} mobile money applies. You will get a payment prompt on your phone.';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.badgeCheck, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Thank you!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your donation is confirmed. The host has been notified and the funds will reach them quickly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            if (_contributionId != null) ...[
              OutlinedButton.icon(
                onPressed: () async {
                  final url = ref
                      .read(apiClientProvider)
                      .receiptUrl(_contributionId!);
                  final uri = Uri.parse(url);
                  final messenger = ScaffoldMessenger.of(context);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Could not open receipt')),
                    );
                  }
                },
                icon: const Icon(LucideIcons.download, size: 18),
                label: const Text('Download receipt'),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(onPressed: () => context.go('/'), child: const Text('Back to campaigns')),
          ],
        ),
      ),
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.xCircle, size: 72, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'Payment not completed',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'The payment was cancelled or did not go through. You can try again.',
              textAlign: TextAlign.center,
            ),
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
  final VoidCallback onResend;

  const _AwaitingPin({required this.referenceId, required this.phoneE164, required this.onResend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ussd = ussdCodeForPhone(phoneE164);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Check your phone',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'We have sent a payment prompt to your mobile money. Enter your PIN to complete the donation.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'If you don\'t see it, dial $ussd on your phone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onResend,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Resend prompt'),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference: $referenceId',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
