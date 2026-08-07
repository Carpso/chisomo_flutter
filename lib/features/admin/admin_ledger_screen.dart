import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/api_client.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends ConsumerState<AdminTransactionsScreen> {
  static const _filters = <String, String?>{
    'All': null,
    'Confirmed': 'confirmed',
    'Pending': 'pending',
    'Failed': 'failed',
  };

  String _filter = 'All';
  bool _loadingMore = false;

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(adminLedgerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(adminLedgerProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(entry.key),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ledger.when(
              loading: () => const Center(child: AppIconSpinner()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(friendlyError(e), textAlign: TextAlign.center),
                ),
              ),
              data: (data) {
                final filter = _filters[_filter];
                final txs = filter == null
                    ? data.transactions
                    : data.transactions.where((t) => t.status == filter).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminLedgerProvider),
                  child: txs.isEmpty
                      ? const _Empty(message: 'No contributions yet.')
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: txs.length + 1,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) => i < txs.length
                              ? _TxTile(tx: txs[i])
                              : Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: _loadingMore
                                        ? null
                                        : () async {
                                            setState(() => _loadingMore = true);
                                            try {
                                              await ref
                                                  .read(adminLedgerProvider.notifier)
                                                  .loadMoreTransactions();
                                            } catch (_) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Could not load more. Try again.')));
                                              }
                                            } finally {
                                              if (mounted) {
                                                setState(() =>
                                                    _loadingMore = false);
                                              }
                                            }
                                          },
                                    icon: _loadingMore
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(LucideIcons.chevronsDown,
                                            size: 16),
                                    label: Text(_loadingMore
                                        ? 'Loading…'
                                        : 'Load more'),
                                  ),
                                ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDisbursementsScreen extends ConsumerStatefulWidget {
  const AdminDisbursementsScreen({super.key});

  @override
  ConsumerState<AdminDisbursementsScreen> createState() => _AdminDisbursementsScreenState();
}

class _AdminDisbursementsScreenState extends ConsumerState<AdminDisbursementsScreen> {
  int _balanceCents = 0;
  bool _balanceLoading = true;
  String? _balanceError;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() { _balanceLoading = true; _balanceError = null; });
    try {
      final res = await ref.read(apiClientProvider).getWalletBalance();
      if (mounted) setState(() { _balanceCents = res['balanceCents'] as int? ?? 0; _balanceLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _balanceLoading = false; _balanceError = 'Could not fetch the wallet balance.'; });
    }
  }

  Future<void> _triggerDisburse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trigger auto-disburse?'),
        content: const Text('This will attempt to disburse all eligible campaign balances now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trigger')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ref.read(apiClientProvider).triggerDisburse();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Disburse triggered')),
        );
        ref.invalidate(adminLedgerProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();
    var busy = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Manual withdrawal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (K)', prefixText: 'K '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number', hintText: '+260...'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: busy ? null : () async {
                setDialogState(() => busy = true);
                try {
                  final amount = _parseAmountCents(amountController.text.trim());
                  final phone = phoneController.text.trim();
                  if (amount == null || amount <= 0) {
                    setDialogState(() => busy = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount (e.g. 50.00)')),
                      );
                    }
                    return;
                  }
                  if (!_balanceLoading && _balanceError == null && amount > _balanceCents) {
                    setDialogState(() => busy = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Amount exceeds the wallet balance.')),
                      );
                    }
                    return;
                  }
                  if (!_balanceLoading && _balanceError != null) {
                    setDialogState(() => busy = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wallet balance is unavailable — try again shortly.')),
                      );
                    }
                    return;
                  }
                  if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
                    setDialogState(() => busy = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a complete phone number (e.g. +260 977 123 456).')),
                      );
                    }
                    return;
                  }
                  final res = await ref.read(apiClientProvider).adminWithdraw(amount, phone);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(res['message'] as String? ?? 'Withdrawal initiated')),
                    );
                  }
                } catch (e) {
                  setDialogState(() => busy = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                }
              },
              child: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    phoneController.dispose();
    if (ok == true) { await _loadBalance(); ref.invalidate(adminLedgerProvider); }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(adminLedgerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payouts & settlements'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: () { ref.invalidate(adminLedgerProvider); _loadBalance(); }),
        ],
      ),
      body: Column(
        children: [
          // Wallet balance card
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.gold.withValues(alpha: 0.08)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.wallet, color: AppColors.gold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lipila wallet balance', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                      if (_balanceLoading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (_balanceError != null)
                        Row(
                          children: [
                            Flexible(
                              child: Text(_balanceError!,
                                  style: TextStyle(color: AppColors.danger, fontSize: 13)),
                            ),
                            TextButton(
                              onPressed: _loadBalance,
                              child: const Text('Retry'),
                            ),
                          ],
                        )
                      else
                        Text(formatKwacha(_balanceCents), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _triggerDisburse,
                  icon: const Icon(LucideIcons.zap, size: 14),
                  label: const Text('Disburse'),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: _showWithdrawDialog,
                  icon: const Icon(LucideIcons.send, size: 16),
                  label: const Text('Withdraw'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ledger.when(
              loading: () => const Center(child: AppIconSpinner()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e), textAlign: TextAlign.center))),
              data: (data) {
                final disbs = data.disbursements;
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminLedgerProvider),
                  child: disbs.isEmpty
                      ? const _Empty(message: 'No payouts or fee settlements yet.')
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          itemCount: disbs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) => _DisbTile(d: disbs[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final AdminTransaction tx;

  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(LucideIcons.coins, color: AppColors.primary),
        title: Text(
          '${tx.displayName} Â· ${formatKwacha(tx.amountCents)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${tx.campaignTitle}\n${tx.phone}\n${tx.createdAt}${tx.lipilaReference == null ? '' : '\n${tx.lipilaReference}'}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(status: tx.status),
            const SizedBox(width: 4),
            const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
          ],
        ),
        onTap: () => context.push('/admin/transactions/${tx.id}'),
      ),
    );
  }
}

class _DisbTile extends StatelessWidget {
  final Disbursement d;

  const _DisbTile({required this.d});

  @override
  Widget build(BuildContext context) {
    final isSweep = d.kind == 'sweep';
    final isFailed = d.status == 'failed';
    return Card(
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSweep ? LucideIcons.piggyBank : LucideIcons.send,
                    color: isFailed ? AppColors.danger : (isSweep ? AppColors.gold : AppColors.primary),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${isSweep ? 'Fee sweep' : (d.kind == 'admin_withdraw' ? 'Admin withdraw' : 'Host payout')} — ${formatKwacha(d.amountCents)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  _StatusChip(status: d.status),
                  const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.campaignTitle, style: TextStyle(color: AppColors.textDark)),
                    if (d.hostPhone != null) ...[
                      const SizedBox(height: 2),
                      Text('To: ${d.hostPhone}', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                    const SizedBox(height: 2),
                    Text(d.createdAt, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    if (d.lipilaFeeCents > 0) ...[
                      const SizedBox(height: 2),
                      Text('Fees: ${formatKwacha(d.lipilaFeeCents + d.platformFeeCents)}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                    if (isFailed) ...[
                      const SizedBox(height: 2),
                      const Text('Failed', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${d.kind == 'sweep' ? 'Fee sweep' : 'Payout'} #${d.id}'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Amount: ${formatKwacha(d.amountCents)}'),
            const SizedBox(height: 4),
            Text('Status: ${d.status}'),
            const SizedBox(height: 4),
            Text('Campaign: ${d.campaignTitle}'),
            if (d.hostPhone != null) ...[
              const SizedBox(height: 4),
              Text('To: ${d.hostPhone}'),
            ],
            if (d.lipilaFeeCents > 0) ...[
              const SizedBox(height: 4),
              Text('Lipila processing fee: ${formatKwacha(d.lipilaFeeCents)}'),
            ],
            if (d.platformFeeCents > 0) ...[
              const SizedBox(height: 4),
              Text('Platform processing fee: ${formatKwacha(d.platformFeeCents)}'),
            ],
            const SizedBox(height: 4),
            Text('Date: ${d.createdAt}'),
            if (d.lipilaReference != null) ...[
              const SizedBox(height: 4),
              Text('Ref: ${d.lipilaReference}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// Parses a Kwacha amount string (e.g. "50.00") into integer cents.
/// Returns null if the input is not a valid non-negative amount.
int? _parseAmountCents(String text) {
  final cleaned = text.trim();
  if (cleaned.isEmpty) return null;
  final parts = cleaned.split('.');
  if (parts.length > 2) return null;
  final wholeStr = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
  if (wholeStr.isEmpty) return null;
  final whole = int.tryParse(wholeStr);
  if (whole == null) return null;
  int cents = 0;
  if (parts.length == 2) {
    final frac = parts[1].padRight(2, '0');
    if (frac.length > 2 || int.tryParse(frac.substring(0, 2)) == null) return null;
    cents = int.parse(frac.substring(0, 2));
  }
  return whole * 100 + cents;
}

class _Empty extends StatelessWidget {
  final String message;

  const _Empty({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(LucideIcons.inbox, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
      ],
    );
  }
}
