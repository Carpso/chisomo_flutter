import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'money.dart';
import 'theme.dart';

class DonorBadge {
  final String name;
  final int minCents;
  final IconData icon;
  final Color color;

  const DonorBadge(this.name, this.minCents, this.icon, this.color);
}

const donorBadges = <DonorBadge>[
  DonorBadge('Giver', 0, LucideIcons.heart, Color(0xFF94A3B8)),
  DonorBadge('Supporter', 10000, LucideIcons.heartHandshake, Color(0xFF22C55E)),
  DonorBadge('Champion', 50000, LucideIcons.shieldCheck, Color(0xFF3B82F6)),
  DonorBadge('Sponsor', 200000, LucideIcons.crown, Color(0xFFD4A017)),
];

DonorBadge badgeFor(int totalCents) {
  DonorBadge current = donorBadges.first;
  for (final b in donorBadges) {
    if (totalCents >= b.minCents) current = b;
  }
  return current;
}

/// The next badge threshold the donor is working toward, or null at max tier.
DonorBadge? nextBadgeFor(int totalCents) {
  for (final b in donorBadges) {
    if (totalCents < b.minCents) return b;
  }
  return null;
}

class BadgesCard extends StatelessWidget {
  final int totalGivenCents;

  const BadgesCard({super.key, required this.totalGivenCents});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = badgeFor(totalGivenCents);
    final next = nextBadgeFor(totalGivenCents);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(current.icon, size: 20, color: current.color),
                const SizedBox(width: 8),
                Text(
                  'Your badge: ${current.name}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ((totalGivenCents - current.minCents) /
                          (next.minCents - current.minCents))
                      .clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EDE8),
                  color: next.color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${formatKwacha(next.minCents - totalGivenCents)} to unlock ${next.name}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final b in donorBadges) _BadgePill(badge: b, unlocked: totalGivenCents >= b.minCents),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final DonorBadge badge;
  final bool unlocked;

  const _BadgePill({required this.badge, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = unlocked ? badge.color : AppColors.textMuted;
    return Column(
      children: [
        Icon(
          badge.icon,
          size: 26,
          color: color.withValues(alpha: unlocked ? 1 : 0.35),
        ),
        const SizedBox(height: 4),
        Text(
          badge.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: unlocked ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
