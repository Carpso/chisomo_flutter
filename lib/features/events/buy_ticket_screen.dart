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

/// Dedicated event ticket purchase screen: pick a tier + quantity, then pay
/// with mobile money (PIN prompt) or card. Everything is event-branded —
/// no "donate" wording anywhere.
class BuyTicketScreen extends ConsumerStatefulWidget {
  final int eventId;

  const BuyTicketScreen({super.key, required this.eventId});

  @override
  ConsumerState<BuyTicketScreen> createState() => _BuyTicketScreenState();
}

enum _Phase { form, awaitingPin, done, failed }

enum _PaymentMethod { mobileMoney, card }

class _BuyTicketScreenState extends ConsumerState<BuyTicketScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String _phoneE164 = '';
  EventTier? _selectedTier;
  int _qty = 1;
  _PaymentMethod _method = _PaymentMethod.mobileMoney;
  String? _checkoutUrl;
  bool _submitting = false;
  String? _error;
  String? _statusMessage;
  String? _referenceId;
  _Phase _phase = _Phase.form;
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
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  int get _amountCents => (_selectedTier?.amountCents ?? 0) * _qty;

  Future<void> _purchase() async {
    final tier = _selectedTier;
    if (tier == null) {
      setState(() => _error = 'Pick a ticket tier to continue.');
      return;
    }
    final phone = _phoneE164;
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your mobile number for the payment prompt.');
      return;
    }
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      setState(() => _error = 'Enter a complete mobile number (e.g. +260 977 123 456).');
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
      final api = ref.read(apiClientProvider);
      final Map<String, dynamic> res;
      if (_method == _PaymentMethod.card) {
        final fullName = _nameController.text.trim();
        res = await api.post('/api/campaigns/${widget.eventId}/contribute-card', {
          'amountCents': _amountCents,
          'tierName': tier.name,
          'ticketQty': _qty,
          'phone': phone,
          'donorName': fullName,
          'email': _emailController.text.trim(),
          'isAnonymous': false,
          'hideAmount': false,
        });
      } else {
        res = await api.buyTickets(
          widget.eventId,
          tierName: tier.name,
          ticketQty: _qty,
          amountCents: _amountCents,
          phone: phone,
          donorName: _nameController.text.trim(),
        );
      }
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

  void _pollStatus() {
    _pollTimer?.cancel();
    var polls = 0;
    // Card checkout can take a while; MoMo prompts also need time for the
    // user to notice the prompt and enter their PIN (Lipila status-check may
    // not settle for ~90s). Keep polling generously instead of failing fast.
    final maxPolls = _method == _PaymentMethod.card ? 240 : 100;
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
        final status = res['status'] as String? ?? 'pending';
        if (status == 'confirmed') {
          timer.cancel();
          if (mounted) {
            setState(() => _phase = _Phase.done);
            ref.invalidate(campaignDetailProvider(widget.eventId));
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Buy ticket')),
      body: switch (_phase) {
        _Phase.form => _buildForm(context),
        _Phase.awaitingPin => _AwaitingPin(
            referenceId: _referenceId ?? '',
            phoneE164: _phoneE164,
            isCard: _method == _PaymentMethod.card,
            onResend: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final res = await ref
                    .read(apiClientProvider)
                    .resendPrompt(_referenceId ?? '');
                if (!mounted) return;
                setState(() => _referenceId = res['referenceId'] as String? ?? _referenceId);
                messenger.showSnackBar(
                  const SnackBar(content: Text('A new payment prompt has been sent.')),
                );
              } on ApiException catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            onReopenCheckout: () async {
              final url = _checkoutUrl;
              if (url == null || url.isEmpty) return;
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
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

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final detail = ref.watch(campaignDetailProvider(widget.eventId)).value;
    final c = detail?.campaign;

    return ListView(
      padding: EdgeInsets.all(16).copyWith(bottom: 16 + MediaQuery.viewInsetsOf(context).bottom),
      children: [
        if (c != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (c.eventDate != null)
                    Text(c.eventDate!,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Choose a ticket tier',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final tier in (c?.eventTiers ?? const <EventTier>[]))
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => setState(() {
                _selectedTier = tier;
                _qty = 1;
              }),
              leading: Icon(
                _selectedTier?.name == tier.name ? LucideIcons.checkCircle : LucideIcons.circle,
                color: _selectedTier?.name == tier.name ? AppColors.primary : AppColors.textMuted,
              ),
              title: Text(tier.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${formatKwacha(tier.amountCents)} per ticket'),
              trailing: const Icon(LucideIcons.ticket, color: AppColors.primary),
            ),
          ),
        if (_selectedTier != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Text('How many tickets?', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    icon: const Icon(LucideIcons.minus),
                  ),
                  Text('$_qty', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _qty < 10 ? () => setState(() => _qty++) : null,
                    icon: const Icon(LucideIcons.plus),
                  ),
                  const Spacer(),
                  Text(
                    formatKwacha(_amountCents),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'How would you like to pay?',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        const SizedBox(height: 12),
        Container(
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
                  const Text('Tickets', style: TextStyle(color: AppColors.textMuted)),
                  Text(
                    '$_qty × ${_selectedTier == null ? '—' : formatKwacha(_selectedTier!.amountCents)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Processing fees', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const Text('Included in the prompt', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('You will pay', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    _amountCents > 0 ? formatKwacha(_amountCents) : '—',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A small processing fee (K0.48 + 1%, K3 minimum + Lipila charges) is added to your payment.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppColors.primary,
          ),
          onPressed: (_submitting || _selectedTier == null) ? null : _purchase,
          icon: _submitting
              ? const SizedBox(width: 22, height: 22, child: AppIconSpinner(size: 22, color: Colors.white))
              : const Icon(LucideIcons.ticket),
          label: Text(
            _selectedTier == null
                ? 'Pick a tier to continue'
                : 'Buy $_qty ticket${_qty == 1 ? '' : 's'} ${formatKwacha(_amountCents)}',
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.badgeCheck, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Ticket confirmed!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your $_qty ticket${_qty == 1 ? '' : 's'} are confirmed. The host has been notified — '
              'show your phone at the door to check in.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/events'),
              child: const Text('Back to events'),
            ),
            TextButton(
              onPressed: () => context.push('/event/${widget.eventId}'),
              child: const Text('View the event page'),
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 56, height: 56, child: AppIconSpinner(size: 56)),
            const SizedBox(height: 24),
            Text(
              isCard ? 'Complete your payment' : 'Check your phone',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isCard
                  ? 'We opened a secure checkout for your card. Finish the payment there to complete your ticket purchase.'
                  : 'We have sent a payment prompt to your mobile money. Enter your PIN to confirm your tickets.',
              textAlign: TextAlign.center,
            ),
            if (!isCard) ...[
              const SizedBox(height: 8),
              Text(
                'If you don\'t see it, dial *115# on your phone.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
              child: const Text('Cancel purchase'),
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
