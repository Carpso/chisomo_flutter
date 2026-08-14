import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin: who can actually receive push notifications on their phone (even with
/// the app closed) vs. who hasn't opened the app / registered a device token.
/// Tap a user to send them a test notification directly.
class AdminPushUsersScreen extends ConsumerStatefulWidget {
  const AdminPushUsersScreen({super.key});

  @override
  ConsumerState<AdminPushUsersScreen> createState() => _AdminPushUsersScreenState();
}

class _AdminPushUsersScreenState extends ConsumerState<AdminPushUsersScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  bool _reachableOnly = false;
  final Set<int> _sending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .getPushUsers(q: _searchController.text.trim());
      if (mounted) {
        setState(() {
          _users = (res['users'] as List<dynamic>? ?? [])
              .whereType<Map>()
              .map((u) => Map<String, dynamic>.from(u))
              .toList();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load users.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _reachableCount => _users.where((u) => u['reachable'] == true).length;
  int get _notReachableCount => _users.length - _reachableCount;

  Future<void> _sendTest(Map<String, dynamic> u) async {
    final id = (u['id'] as num?)?.toInt() ?? 0;
    setState(() => _sending.add(id));
    try {
      final res = await ref.read(apiClientProvider).post(
        '/api/admin/push/test-user',
        {'userId': id},
        auth: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] as String? ?? 'Test push sent'),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send test push.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _reachableOnly
        ? _users.where((u) => u['reachable'] == true).toList()
        : _users;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Push reachability'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _load(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by phone, username or name',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _SummaryChip(
                        icon: LucideIcons.checkCircle,
                        color: AppColors.primary,
                        label: 'Reachable: $_reachableCount',
                      ),
                      _SummaryChip(
                        icon: LucideIcons.alertCircle,
                        color: AppColors.danger,
                        label: 'Not reachable: $_notReachableCount',
                      ),
                      ChoiceChip(
                        label: Text(_reachableOnly ? 'Reachable only' : 'All users',
                            style: const TextStyle(fontSize: 12)),
                        selected: _reachableOnly,
                        onSelected: (v) => setState(() => _reachableOnly = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Reachable = has a registered device token, so pushes arrive even when the app is closed. '
                'Users who haven\'t opened the app once show as not reachable.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.4),
              ),
            ),
          ),
          Expanded(
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
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: shown.isEmpty
                            ? ListView(
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(48),
                                    child: Column(
                                      children: [
                                        Icon(LucideIcons.bellOff, size: 44, color: AppColors.textMuted),
                                        SizedBox(height: 12),
                                        Text('No users match.',
                                            style: TextStyle(color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 32),
                                itemCount: shown.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 6),
                                itemBuilder: (context, i) {
                                  final u = shown[i];
                                  final reachable = u['reachable'] == true;
                                  final id = (u['id'] as num?)?.toInt() ?? 0;
                                  final sending = _sending.contains(id);
                                  final tokens = (u['tokenCount'] as num?)?.toInt() ?? 0;
                                  final lastSeen = u['tokenLastSeenAt'] as String?;
                                  final hostStatus = (u['hostStatus'] as String? ?? 'none');
                                  final isHost = hostStatus == 'approved';
                                  final enabled = u['notificationsEnabled'] == true;
                                  return Card(
                                    margin: EdgeInsets.zero,
                                    color: reachable
                                        ? null
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    child: ListTile(
                                      leading: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: (reachable ? AppColors.primary : AppColors.textMuted)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          reachable ? LucideIcons.smartphone : LucideIcons.bellOff,
                                          size: 19,
                                          color: reachable ? AppColors.primary : AppColors.textMuted,
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${u['name'] ?? u['username'] ?? u['phone'] ?? ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                            ),
                                          ),
                                          if (isHost) ...[
                                            const SizedBox(width: 4),
                                            const Icon(LucideIcons.badgeCheck, size: 13, color: AppColors.primary),
                                          ],
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${u['phone'] ?? ''}'
                                        '${tokens > 0 ? ' • $tokens device${tokens == 1 ? '' : 's'}' : ''}'
                                        '${lastSeen != null ? ' • last seen ${safeDate(lastSeen)}' : ''}\n'
                                        '${reachable ? 'Reachable' : 'Not reachable'}'
                                        '${!enabled && reachable ? ' • notifications OFF' : ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5),
                                      ),
                                      isThreeLine: true,
                                      trailing: reachable
                                          ? IconButton(
                                              tooltip: 'Send test push',
                                              icon: sending
                                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                  : const Icon(LucideIcons.bellRing, size: 17, color: AppColors.primary),
                                              onPressed: sending ? null : () => _sendTest(u),
                                            )
                                          : null,
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

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SummaryChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
