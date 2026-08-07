import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

/// Full detail of one contribution — every status (pending, confirmed,
/// failed) is visible to the superadmin.
class TransactionDetailScreen extends ConsumerWidget {
  final int transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      transactionDetailProvider(transactionId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction detail')),
      body: detail.when(
        loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(friendlyError(e), textAlign: TextAlign.center),
          ),
        ),
        data: (t) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(transactionDetailProvider(transactionId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      formatKwacha(t.amountCents),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _StatusChip(status: t.status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _Row(icon: LucideIcons.tent, label: 'Campaign', value: t.campaignTitle),
                  _Row(
                    icon: LucideIcons.smartphone,
                    label: 'Donor phone',
                    value: t.phone.isEmpty ? '—' : t.phone,
                  ),
                  if (t.donorUsername != null)
                    _Row(icon: LucideIcons.atSign, label: 'Username', value: t.donorUsername!),
                  if (!t.isAnonymous && t.hideAmount)
                    const _Row(
                      icon: LucideIcons.eyeOff,
                      label: 'Amount hidden',
                      value: 'Donor hid the amount',
                    ),
                  _Row(icon: LucideIcons.calendar, label: 'Created', value: t.createdAt),
                  if (t.confirmedAt != null)
                    _Row(icon: LucideIcons.checkCircle2, label: 'Confirmed', value: t.confirmedAt!),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _Row(
                    icon: LucideIcons.receipt,
                    label: 'Platform processing fee',
                    value: formatKwacha(t.platformFeeCents),
                  ),
                  _Row(
                    icon: LucideIcons.wallet,
                    label: 'Lipila processing fee',
                    value: formatKwacha(t.lipilaFeeCents),
                  ),
                  _Row(
                    icon: LucideIcons.landmark,
                    label: 'Host receives',
                    value: formatKwacha(t.payoutCents),
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  if (t.lipilaReference != null)
                    _ReferenceRow(icon: LucideIcons.hash, label: 'Reference', value: t.lipilaReference!),
                  if (t.lipilaIdentifier != null)
                    _ReferenceRow(icon: LucideIcons.qrCode, label: 'Lipila ID', value: t.lipilaIdentifier!),
                  if (t.lipilaReference == null && t.lipilaIdentifier == null)
                    const _Row(
                      icon: LucideIcons.info,
                      label: 'Payment details',
                      value: 'No payment identifiers recorded',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (t.status == 'confirmed')
              FilledButton.icon(
                onPressed: () async {
                  final url = ref.read(apiClientProvider).receiptUrl(t.id);
                  if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open the receipt.')),
                      );
                    }
                  }
                },
                icon: const Icon(LucideIcons.fileText, size: 18),
                label: const Text('Open PDF receipt'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.push('/campaign/${t.campaignId}'),
              icon: const Icon(LucideIcons.eye, size: 18),
              label: const Text('View campaign'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

final transactionDetailProvider =
    FutureProvider.family<TransactionDetail, int>((ref, id) async {
  final ledger = ref.read(adminLedgerProvider.notifier);
  return ledger.transactionDetail(id);
});

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Row({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReferenceRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          ),
          Flexible(
            child: InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied')),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.copy, size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' || 'success' || 'complete' => AppColors.primary,
      'pending' => AppColors.gold,
      _ => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
