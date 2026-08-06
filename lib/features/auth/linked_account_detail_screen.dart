import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../../core/widgets/avatar.dart';

class LinkedAccountDetailScreen extends ConsumerStatefulWidget {
  final int linkId;

  const LinkedAccountDetailScreen({super.key, required this.linkId});

  @override
  ConsumerState<LinkedAccountDetailScreen> createState() => _LinkedAccountDetailScreenState();
}

class _LinkedAccountDetailScreenState extends ConsumerState<LinkedAccountDetailScreen> {
  Map<String, dynamic>? _link;
  List<dynamic> _combinedDonations = [];
  bool _loading = true;
  String? _error;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final links = await ref.read(apiClientProvider).getLinks();
      final linkList = links['links'] as List<dynamic>? ?? [];
      final link = linkList.firstWhere(
        (l) => l['id'] == widget.linkId,
        orElse: () => null,
      );
      if (link == null) {
        setState(() { _error = 'Link not found'; _loading = false; });
        return;
      }
      // Fetch combined donations from the linked account
      final donations = await ref.read(apiClientProvider).get('/api/user/links/${widget.linkId}/donations', auth: true);
      if (mounted) {
        setState(() {
          _link = link;
          _combinedDonations = donations['donations'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load link details.'; _loading = false; });
    }
  }

  Future<void> _removeLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove link?'),
        content: const Text('This account will no longer be linked. You will not see their giving or they yours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _removing = true);
    try {
      await ref.read(apiClientProvider).delete('/api/user/links/${widget.linkId}', auth: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link removed')),
        );
        context.go('/settings');
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove the link.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherUser = _link?['otherUser'] as Map<String, dynamic>?;
    final username = otherUser?['username'] as String? ?? 'Unknown';
    final linkType = _link?['linkType'] as String? ?? 'family';
    final isPending = (_link?['status'] as String? ?? '') == 'pending';
    final isInitiator = _link?['isInitiator'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linked account'),
        actions: [
          if (!isPending)
            IconButton(
              icon: _removing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.link2Off),
              tooltip: 'Remove link',
              onPressed: _removing ? null : _removeLink,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Account card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Avatar(name: username, radius: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(username, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                    Text('${linkType.capitalize()} link', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                              if (isPending)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isInitiator ? 'Waiting' : 'Pending',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.gold),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Linked',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Pending actions
                      if (isPending && !isInitiator)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Link request', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('$username wants to link as ${linkType}.', style: theme.textTheme.bodySmall),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _respond(true),
                                        icon: const Icon(LucideIcons.check),
                                        label: const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _respond(false),
                                        icon: const Icon(LucideIcons.x),
                                        label: const Text('Decline'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Combined giving
                      Text('Combined giving', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (_combinedDonations.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(LucideIcons.heartHandshake, size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No donations yet',
                                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Donations from both accounts will appear here.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final d in _combinedDonations) ...[
                                ListTile(
                                  dense: true,
                                  leading: const Icon(LucideIcons.coins, color: AppColors.primary, size: 20),
                                  title: Text('${d['displayName'] ?? 'Giver'} • ${formatKwacha(d['amountCents'] ?? 0)}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('${d['campaignTitle'] ?? ''}\n${d['createdAt'] ?? ''}'),
                                  isThreeLine: true,
                                ),
                                if (d != _combinedDonations.last) const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _respond(bool accept) async {
    try {
      final api = ref.read(apiClientProvider);
      if (accept) {
        await api.acceptLink(widget.linkId);
      } else {
        await api.rejectLink(widget.linkId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'Account linked!' : 'Link request declined.')),
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
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    }
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
