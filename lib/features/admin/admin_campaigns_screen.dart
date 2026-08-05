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

class AdminCampaignsScreen extends ConsumerStatefulWidget {
  const AdminCampaignsScreen({super.key});

  @override
  ConsumerState<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends ConsumerState<AdminCampaignsScreen> {
  List<Campaign>? _campaigns;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await ref.read(apiClientProvider).getAdminCampaigns();
      if (!mounted) return;
      setState(() {
        _campaigns = rows
            .map((r) => Campaign.fromJson((r as Map).cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load campaigns.');
    }
  }

  Future<void> _confirmDelete(Campaign campaign) async {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: AlertDialog(
          title: const Text('Delete campaign?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"${campaign.title}" will be removed from the platform immediately. The host and everyone who donated to it will be alerted (push + SMS).',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why is this campaign being removed? Shown to the host and donors.',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(LucideIcons.messageSquare, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (ok != true) return;

    try {
      await ref
          .read(apiClientProvider)
          .deleteCampaign(campaign.id, reason: reasonController.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('"${campaign.title}" deleted. Host and donors were alerted.')),
      );
      await _load();
      ref.invalidate(adminDataProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = _campaigns;
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: campaigns == null
            ? ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: AppIconSpinner(size: 32)),
                    ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: campaigns.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = campaigns[i];
                  final deleted = c.status == 'deleted';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            (deleted ? AppColors.textMuted : AppColors.primary).withValues(alpha: 0.12),
                        child: Icon(
                          deleted ? LucideIcons.archive : LucideIcons.tent,
                          size: 18,
                          color: deleted ? AppColors.textMuted : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        deleted
                            ? 'Deleted'
                            : '${formatKwacha(c.raisedCents)} raised \u00b7 ${formatKwacha(c.availableCents ?? 0)} available',
                      ),
                      isThreeLine: false,
                      trailing: deleted
                          ? null
                          : IconButton(
                              tooltip: 'Delete campaign',
                              icon: const Icon(LucideIcons.trash2, color: AppColors.danger),
                              onPressed: () => _confirmDelete(c),
                            ),
                      onTap: deleted ? null : () => context.push('/campaign/${c.id}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
