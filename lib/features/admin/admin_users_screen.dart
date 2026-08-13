import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../campaigns/models.dart';

/// Full admin user directory: every registered account by name + number, with
/// their giving total, host status and referral invites. Tap a user to view
/// their details.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  List<AdminUser> _users = [];
  bool _loading = true;
  String? _error;

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
          .getAdminUsers(q: _searchController.text.trim(), limit: 300);
      if (mounted) {
        setState(() {
          _users = (res['users'] as List<dynamic>? ?? [])
              .map((u) => AdminUser.fromJson(u as Map<String, dynamic>))
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

  void _showUserDetails(AdminUser u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Phone', u.phone),
              _detailRow('Username', u.username),
              if (u.name != null) _detailRow('Name', u.name!),
              _detailRow('Joined', safeDate(u.createdAt)),
              if (u.lastLoginAt != null) _detailRow('Last login', safeDate(u.lastLoginAt!)),
              _detailRow('Host status', _hostLabel(u.hostStatus)),
              if (u.hostOrg != null) _detailRow('Organisation', u.hostOrg!),
              if (u.orgType != null) _detailRow('Org type', _orgTypeLabel(u.orgType!)),
              _detailRow('Total given', formatKwacha(u.givenCents)),
              _detailRow('Referrals', '${u.invites} invite${u.invites == 1 ? '' : 's'}'),
              if (u.kycStatus != 'none') ...[
                const SizedBox(height: 6),
                _detailRow('KYC', '${_kycLabel(u.kycStatus)}${u.kycType != null ? ' • ${_kycTypeLabel(u.kycType!)}' : ''}'),
                if (u.kycDocUrl != null)
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(u.kycDocUrl!)),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.eye, size: 14, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text('View document',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
              ],
              if (u.banned) ...[
                const SizedBox(height: 6),
                Text(
                  'Banned: ${u.banReason ?? 'No reason given'}',
                  style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          if (u.hostStatus == 'approved' || u.hostStatus == 'pending')
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _editHostApplication(u);
              },
              icon: const Icon(LucideIcons.pencil, size: 15),
              label: const Text('Edit application'),
            ),
        ],
      ),
    );
  }

  /// Admin edits an approved/pending host's application (org, role, type).
  Future<void> _editHostApplication(AdminUser u) async {
    final org = TextEditingController(text: u.hostOrg ?? '');
    final role = TextEditingController();
    String orgType = u.orgType ?? 'individual';
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit host application'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: org,
                  decoration: const InputDecoration(
                    labelText: 'Organisation',
                    prefixIcon: Icon(LucideIcons.building2, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    hintText: 'e.g. Treasurer, Founder',
                    prefixIcon: Icon(LucideIcons.userCheck, size: 18),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: orgType,
                  items: const [
                    DropdownMenuItem(value: 'individual', child: Text('Individual / church member')),
                    DropdownMenuItem(value: 'ngo', child: Text('NGO / non-profit organisation')),
                    DropdownMenuItem(value: 'agency', child: Text('Fundraising agency')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => orgType = v);
                  },
                  decoration: const InputDecoration(labelText: 'Org type'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await ref.read(apiClientProvider).updateHostApplication(
                          u.id,
                          org: org.text.trim(),
                          role: role.text.trim(),
                          orgType: orgType,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Host application updated')),
                          );
                        }
                      } catch (_) {
                        setDialogState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Could not update. Try again.')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    org.dispose();
    role.dispose();
    if (ok == true) {
      await _load();
    }
  }

  String _orgTypeLabel(String t) {
    switch (t) {
      case 'ngo':
        return 'NGO / non-profit';
      case 'agency':
        return 'Fundraising agency';
      default:
        return 'Individual';
    }
  }

  String _kycLabel(String s) {
    switch (s) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'submitted':
        return 'Submitted';
      default:
        return 'None';
    }
  }

  String _kycTypeLabel(String t) {
    switch (t) {
      case 'nrc':
        return 'NRC';
      case 'ngo_cert':
        return 'NGO cert';
      case 'endorsement':
        return 'Endorsement';
      default:
        return 'Doc';
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _hostLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved host';
      case 'pending':
        return 'Host application pending';
      case 'rejected':
        return 'Host application rejected';
      default:
        return 'Not a host';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username or phone…',
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
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
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
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 12),
                            Center(
                              child: OutlinedButton(
                                onPressed: _load,
                                child: const Text('Try again'),
                              ),
                            ),
                          ],
                        )
                      : _users.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Column(
                                    children: [
                                      Icon(LucideIcons.users,
                                          size: 44, color: AppColors.textMuted),
                                      SizedBox(height: 12),
                                      Text('No users found.',
                                          style: TextStyle(color: AppColors.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _users.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 6),
                              itemBuilder: (context, i) => _UserTile(
                                user: _users[i],
                                onTap: () => _showUserDetails(_users[i]),
                              ),
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(
            (user.displayName.isNotEmpty ? user.displayName[0] : '?').toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        title: Text(user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${user.phone}\nJoined ${safeDate(user.createdAt)}${user.lastLoginAt != null ? ' • Last login ${safeDate(user.lastLoginAt!)}' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (user.hostStatus == 'approved')
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.primary),
                  SizedBox(width: 3),
                  Text('Host', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            if (user.banned)
              const Text('Banned',
                  style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w700)),
            Text(formatKwacha(user.givenCents),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
