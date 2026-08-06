import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

class BadgeTier {
  final String id;
  final String label;
  final int priceCents;
  final int days;

  const BadgeTier({required this.id, required this.label, required this.priceCents, required this.days});

  factory BadgeTier.fromJson(String id, Map<String, dynamic> j) => BadgeTier(
        id: id,
        label: j['label'] as String ?? id,
        priceCents: j['priceCents'] as int? ?? 0,
        days: j['days'] as int? ?? 30,
      );
}

class BadgeConfig {
  final bool enabled;
  final Map<String, BadgeTier> tiers;

  const BadgeConfig({required this.enabled, required this.tiers});

  factory BadgeConfig.fromJson(Map<String, dynamic> j) => BadgeConfig(
        enabled: j['enabled'] == true,
        tiers: (j['tiers'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, BadgeTier.fromJson(k, v as Map<String, dynamic>))),
      );
}

/// Host Badge Subscription Screen
class HostBadgeScreen extends ConsumerStatefulWidget {
  const HostBadgeScreen({super.key});

  @override
  ConsumerState<HostBadgeScreen> createState() => _HostBadgeScreenState();
}

class _HostBadgeScreenState extends ConsumerState<HostBadgeScreen> {
  BadgeConfig? _config;
  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ref.read(apiClientProvider).get('/api/host/badge-config'),
        ref.read(apiClientProvider).get('/api/host/badge-status', auth: true),
      ]);
      if (mounted) {
        setState(() {
          _config = BadgeConfig.fromJson(results[0]);
          _status = results[1] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(String tierId) async {
    final tier = _config?.tiers[tierId];
    if (tier == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Subscribe to ${tier.label}?'),
        content: Text('You will be charged ${formatKwacha(tier.priceCents)} for ${tier.days} days.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Subscribe')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).post('/api/host/badge/subscribe', {'tier': tierId}, auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription activated! Your badge is now live.')),
        );
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process subscription.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _config;
    final status = _status;

    if (_loading) return const Scaffold(body: Center(child: AppIconSpinner()));
    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Host Badge')),
        body: Center(child: Text('Could not load badge info', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted))),
      );
    }

    final hasActiveBadge = status?['hasActiveBadge'] == true;
    final currentTier = status?['tier'] as String?;
    final expiresAt = status?['expiresAt'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Verified Host Badge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current status
          if (hasActiveBadge)
            Card(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.badgeCheck, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Badge: ${config.tiers[currentTier]?.label ?? currentTier ?? 'Unknown'}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (expiresAt != null) Text('Expires: ${expiresAt.substring(0, 10)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Badge benefits
          Text('Verified Host Benefits', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _benefit(LucideIcons.badgeCheck, 'Orange verified badge on all campaigns'),
                  _benefit(LucideIcons.trendingUp, 'Priority placement in campaign lists'),
                  _benefit(LucideIcons.headphones, 'Priority support response'),
                  _benefit(LucideIcons.users, 'Multiple admin accounts (Pro)'),
                  _benefit(LucideIcons.barChart3, 'Monthly analytics reports (Pro)'),
                  _benefit(LucideIcons.zap, 'Zero platform fees on first K500 (Annual)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Pricing tiers
          Text('Choose Your Plan', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (!config.enabled)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(LucideIcons.clock, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('Coming Soon', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('The verified host program is not yet active. Check back soon!', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            )
          else
            for (final tier in config.tiers.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: hasActiveBadge && currentTier == tier.id ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: hasActiveBadge && currentTier == tier.id ? 0.2 : 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            tier.id == 'annual' ? LucideIcons.crown : (tier.id == 'pro' ? LucideIcons.star : LucideIcons.badgeCheck),
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tier.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text('${formatKwacha(tier.priceCents)} / ${tier.days} days', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: hasActiveBadge && currentTier == tier.id ? null : () => _subscribe(tier.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(hasActiveBadge && currentTier == tier.id ? 'Active' : 'Subscribe'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Admin: Badge Config
class BadgeAdminConfig extends ConsumerStatefulWidget {
  const BadgeAdminConfig({super.key});

  @override
  ConsumerState<BadgeAdminConfig> createState() => _BadgeAdminConfigState();
}

class _BadgeAdminConfigState extends ConsumerState<BadgeAdminConfig> {
  bool _enabled = false;
  Map<String, int> _prices = {'basic': 5000, 'pro': 15000, 'annual': 120000};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get('/api/host/badge-config');
      if (mounted) {
        final tiers = res['tiers'] as Map<String, dynamic>?;
        setState(() {
          _enabled = res['enabled'] == true;
          if (tiers != null) {
            _prices = tiers.map((k, v) => MapEntry(k, (v as Map<String, dynamic>)['priceCents'] as int? ?? 0));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).put('/api/admin/host/badge-config', {
        'enabled': _enabled,
        'basicPriceCents': _prices['basic'],
        'proPriceCents': _prices['pro'],
        'annualPriceCents': _prices['annual'],
      }, auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Badge settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.badgeCheck, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Verified Host Badge', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_enabled ? 'Enabled — hosts can subscribe' : 'Disabled — shows "Coming Soon"', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Basic: K${(_prices['basic'] ?? 0) / 100}', style: theme.textTheme.bodySmall)),
                Expanded(child: Text('Pro: K${(_prices['pro'] ?? 0) / 100}', style: theme.textTheme.bodySmall)),
                Expanded(child: Text('Annual: K${(_prices['annual'] ?? 0) / 100}', style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.save, size: 16),
              label: Text(_saving ? 'Saving...' : 'Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
