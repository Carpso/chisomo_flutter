import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/campaigns_controller.dart';

/// In-app notifications center — a history of every important event (donations,
/// tickets, milestones, support replies, admin alerts) so nothing is lost even
/// when a push is missed or blocked by the OS.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ref.read(apiClientProvider).getNotifications();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load notifications.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _unreadCount => _items.where((n) => n['read'] != true).length;

  Future<void> _markAllRead() async {
    try {
      await ref.read(apiClientProvider).markAllNotificationsRead();
      if (mounted) {
        setState(() {
          for (final n in _items) { n['read'] = true; }
        });
        ref.invalidate(unreadNotificationsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All marked as read')),
        );
      }
    } catch (_) {}
  }

  /// Shows a detailed view of the notification and marks it read.
  Future<void> _openDetail(Map<String, dynamic> n) async {
    if (n['read'] != true) {
      try {
        await ref.read(apiClientProvider).markNotificationRead(n['id'] as int);
        if (mounted) setState(() => n['read'] = true);
        ref.invalidate(unreadNotificationsProvider);
      } catch (_) {}
    }
    final data = n['data'] as Map<String, dynamic>?;
    final campaignId = data?['campaignId'];
    final ticketId = data?['ticketId'];
    final type = data?['type'] as String?;

    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n['title'] as String? ?? 'Notification',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(n['body'] as String? ?? '', style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              Text(safeDate(n['createdAt']),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          if (campaignId != null || ticketId != null)
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    if (campaignId != null && campaignId.toString().isNotEmpty) {
      context.push('/campaign/$campaignId');
    } else if (ticketId != null) {
      context.push('/settings/support');
    } else if (type == 'referral_rewarded') {
      context.push('/settings/referrals');
    } else if (type == 'airtime_delivered') {
      context.push('/airtime');
    } else if (type == 'new_user' || type == 'admin_alert' || type == 'host_application' || type == 'donation' || type == 'broadcast') {
      context.push('/admin');
    }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'donation_received':
      case 'donation_confirmed':
      case 'donation':
      case 'new_donor':
        return LucideIcons.hand;
      case 'payout_sent':
      case 'payout_failed':
      case 'airtime_sent':
      case 'airtime_delivered':
      case 'airtime_failed':
      case 'airtime_refunded':
        return LucideIcons.send;
      case 'milestone':
        return LucideIcons.trophy;
      case 'ticket_reply':
      case 'ticket_created':
      case 'ticket_closed':
        return LucideIcons.headphones;
      case 'campaign_ended':
      case 'campaign_ending':
        return LucideIcons.flag;
      case 'promotion_active':
      case 'promotion_expired':
      case 'promotion_rejected':
      case 'promotion_refunded':
        return LucideIcons.star;
      case 'referral_rewarded':
        return LucideIcons.gift;
      case 'new_user':
      case 'host_application':
      case 'admin_alert':
        return LucideIcons.shieldCheck;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _unreadOnly ? _items.where((n) => n['read'] != true).toList() : _items;
    return Scaffold(
      appBar: AppBar(
        title: Text(_unreadCount > 0 ? 'Notifications ($_unreadCount unread)' : 'Notifications'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(LucideIcons.checkCheck, size: 16),
              label: const Text('Read all'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text('All (${_items.length})', style: const TextStyle(fontSize: 12)),
                    selected: !_unreadOnly,
                    onSelected: (_) => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('Unread ($_unreadCount)', style: const TextStyle(fontSize: 12)),
                    selected: _unreadOnly,
                    onSelected: (_) => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: AppIconSpinner())
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      Center(child: OutlinedButton(onPressed: _load, child: const Text('Try again'))),
                    ],
                  )
                : shown.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(LucideIcons.bellOff, size: 44, color: AppColors.textMuted),
                                SizedBox(height: 12),
                                Text('No notifications yet.',
                                    style: TextStyle(color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final n = shown[i];
                          final read = n['read'] == true;
                          final type = n['type'] as String?;
                          return Card(
                            margin: EdgeInsets.zero,
                            color: read ? null : AppColors.primary.withValues(alpha: 0.04),
                            child: ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_iconFor(type), size: 19, color: AppColors.primary),
                              ),
                              title: Text(
                                n['title'] as String? ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: read ? AppColors.textMuted : AppColors.textDark,
                                ),
                              ),
                              subtitle: Text(
                                '${n['body'] ?? ''}\n${safeDate(n['createdAt'])}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, fontSize: 12),
                              ),
                              isThreeLine: true,
                              trailing: read
                                  ? null
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              onTap: () => _openDetail(n),
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
