import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/app_widgets.dart';
import 'sponsor_desk.dart';

/// Sponsor Desk — curated grant & empowerment opportunities for active hosts.
/// The admin publishes a weekly batch; hosts open the app to see + apply, so
/// Kingdom Sponsor becomes their funding-intelligence source, not just the
/// payment processor.
class SponsorDeskScreen extends ConsumerWidget {
  const SponsorDeskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(sponsorDeskProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor Desk'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () => ref.invalidate(sponsorDeskProvider),
          ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: AppIconSpinner()),
        error: (e, _) => _ErrorRetry(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(sponsorDeskProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(40),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.briefcase,
                      size: 34, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No opportunities right now',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We curate active grants and empowerment programmes for '
                  'our hosts. Check back soon — new opportunities are added weekly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(sponsorDeskProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              itemCount: items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _HeaderBanner();
                }
                return _OpportunityCard(opportunity: items[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.briefcase, color: Colors.white, size: 22),
          const SizedBox(height: 8),
          Text(
            'Funding opportunities for your campaign',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Grants, empowerment programmes and matching funds we\'ve '
            'hand-picked for active hosts. Tap one to apply.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends ConsumerStatefulWidget {
  final SponsorOpportunity opportunity;

  const _OpportunityCard({required this.opportunity});

  @override
  ConsumerState<_OpportunityCard> createState() => _OpportunityCardState();
}

class _OpportunityCardState extends ConsumerState<_OpportunityCard> {
  bool _applying = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _applied = widget.opportunity.appliedCount > 0;
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    try {
      await ref.read(apiClientProvider).applySponsorDesk(widget.opportunity.id);
      if (mounted) {
        setState(() => _applied = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application recorded — our team will follow up.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record your application.')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final o = widget.opportunity;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: o.hasLink
            ? () => launchUrl(Uri.parse(o.link), mode: LaunchMode.externalApplication)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      o.category.isEmpty ? 'Grant' : o.category,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (o.matched) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles, size: 11, color: AppColors.gold),
                          SizedBox(width: 3),
                          Text('Best match',
                              style: TextStyle(
                                  fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.gold)),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (o.amountLabel.isNotEmpty)
                    Text(
                      o.amountLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                o.title,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
              ),
              if (o.organization.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(LucideIcons.building2, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        o.organization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (o.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  o.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (o.hasDeadline)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.calendarClock, size: 13, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text(
                          'Deadline: ${safeDate(o.deadline)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
                        ),
                      ],
                    ),
                  if (o.hasLink)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.externalLink, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Apply now',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _applied
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: null,
                            icon: const Icon(LucideIcons.checkCircle, size: 16, color: AppColors.primary),
                            label: const Text('Applied'),
                          )
                        : FilledButton.icon(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                            onPressed: _applying ? null : _apply,
                            icon: _applying
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(LucideIcons.send, size: 15),
                            label: Text(_applying ? 'Recording…' : 'I applied'),
                          ),
                ),
              ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.wifiOff, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
