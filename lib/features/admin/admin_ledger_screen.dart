import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class AdminTransactionsScreen extends ConsumerWidget {
  const AdminTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: ledger.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          final txs = data.transactions;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminLedgerProvider),
            child: txs.isEmpty
                ? const _Empty(message: 'No contributions yet.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: txs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _TxTile(tx: txs[i]),
                  ),
          );
        },
      ),
    );
  }
}

class AdminDisbursementsScreen extends ConsumerWidget {
  const AdminDisbursementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(adminLedgerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payouts & settlements'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(adminLedgerProvider),
          ),
        ],
      ),
      body: ledger.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (data) {
          final disbs = data.disbursements;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminLedgerProvider),
            child: disbs.isEmpty
                ? const _Empty(message: 'No payouts or fee settlements yet.')
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: disbs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _DisbTile(d: disbs[i]),
                  ),
          );
        },
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
          '${tx.displayName} · ${formatKwacha(tx.amountCents)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${tx.campaignTitle}\n${tx.phone}\n${tx.createdAt}${tx.lipilaReference == null ? '' : '\n${tx.lipilaReference}'}',
        ),
        isThreeLine: true,
        trailing: _StatusChip(status: tx.status),
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
    return Card(
      child: ListTile(
        leading: Icon(
          isSweep ? LucideIcons.piggyBank : LucideIcons.send,
          color: isSweep ? AppColors.gold : AppColors.primary,
        ),
        title: Text(
          '${isSweep ? 'Fee sweep' : 'Host payout'} · ${formatKwacha(d.amountCents)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${d.campaignTitle}\n${d.createdAt}${d.lipilaReference == null ? '' : '\n${d.lipilaReference}'}',
        ),
        isThreeLine: true,
        trailing: _StatusChip(status: d.status),
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
