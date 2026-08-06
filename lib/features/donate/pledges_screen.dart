import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaigns_controller.dart';
import '../campaigns/models.dart';

class PledgesScreen extends ConsumerWidget {
  const PledgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pledges = ref.watch(pledgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly giving')),
      body: pledges.when(
        loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(pledgesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(pledgesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _HowItWorksCard(),
              const SizedBox(height: 16),
              if (items.isNotEmpty) ...[
                _MonthlyCommitment(items: items),
                const SizedBox(height: 16),
              ],
              if (items.isEmpty)
                const _EmptyState()
              else
                for (final pledge in items) ...[
                  _PledgeCard(pledge: pledge),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.info, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'How monthly giving works',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pick an amount and a day, and Kingdom Sponsor gently SMS-reminds you to give '
              'to that fundraiser every month. It is only a reminder — we never charge your '
              'phone. You can change or stop it any time.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyCommitment extends StatelessWidget {
  final List<Pledge> items;

  const _MonthlyCommitment({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = items.where((p) => p.active).toList();
    final total = active.fold<int>(0, (sum, p) => sum + p.amountCents);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.calendarClock, color: Color(0xFF8A6A00), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly giving habit',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${active.length} ${active.length == 1 ? 'reminder' : 'reminders'} active'
                    '${total > 0 ? ' — up to ${formatKwacha(total)} a month' : ''}. '
                    'Never a charge, just a nudge.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.bellPlus, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'No monthly reminders yet',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Open any fundraiser and toggle "Give every month" while donating. '
              'We will remind you on your chosen day each month — you decide when, '
              'and it is never a charge.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(LucideIcons.tent, size: 18),
            label: const Text('Browse fundraisers'),
          ),
        ],
      ),
    );
  }
}

class _PledgeCard extends ConsumerWidget {
  final Pledge pledge;

  const _PledgeCard({required this.pledge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/campaign/${pledge.campaignId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pledge.campaignTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!pledge.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Cancelled',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(label: 'Reminder amount', value: formatKwacha(pledge.amountCents)),
                  const SizedBox(width: 10),
                  _Stat(
                    label: 'Reminds on day',
                    value: _dayLabel(pledge.dayOfMonth),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    pledge.active ? LucideIcons.bellRing : LucideIcons.bellOff,
                    size: 15,
                    color: pledge.active ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pledge.active
                          ? 'We will SMS you on the ${_dayLabel(pledge.dayOfMonth)} of each month as a gentle nudge.'
                          : 'This reminder is off. Donate again to turn it back on.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
              if (pledge.lastRemindedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Last reminder sent: ${pledge.lastRemindedAt}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              if (pledge.active) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/campaign/${pledge.campaignId}'),
                        icon: const Icon(LucideIcons.tent, size: 16),
                        label: const Text('Open fundraiser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        try {
                          final res = await ref
                              .read(pledgesProvider.notifier)
                              .cancel(pledge.campaignId);
                          messenger.showSnackBar(SnackBar(
                              content: Text(res['message'] as String? ?? 'Reminder cancelled')));
                        } on ApiException catch (e) {
                          messenger.showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      },
                      icon: const Icon(LucideIcons.bellOff, size: 16),
                      label: const Text('Stop'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _dayLabel(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
