import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Permission scopes an admin can grant to an assistant.
const kAssistantScopeLabels = <String, String>{
  'campaigns': 'Campaigns (view/edit/delete)',
  'donations': 'Donations & payouts',
  'tickets': 'Support tickets',
  'users': 'Users (ban/unban/rewards)',
  'settings': 'Platform settings',
  'finance': 'Finance (withdrawals)',
  'restore': 'Restore deleted campaigns',
};

/// Admin screen: manage assistant admins with scoped permissions, restore
/// soft-deleted campaigns, and review the admin action audit log.
class AdminStaffScreen extends ConsumerStatefulWidget {
  /// When true, the "Add assistant" dialog opens automatically once loaded.
  /// Used by the team chat's "Add team member" action so it lands directly
  /// on the add flow instead of the Staff & Restore overview.
  final bool startWithAdd;

  const AdminStaffScreen({super.key, this.startWithAdd = false});

  @override
  ConsumerState<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends ConsumerState<AdminStaffScreen> {
  List<dynamic> _assistants = [];
  List<dynamic> _deleted = [];
  List<dynamic> _actions = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.startWithAdd && !_autoOpened && !_loading) {
      _autoOpened = true;
      // Auto-open the add-assistant dialog once the data is ready, so the
      // team chat's "Add team member" lands directly on the add flow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addAssistant();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final a = await api.getAdminAssistants();
      final d = await api.getDeletedCampaigns();
      final ac = await api.getAdminActions();
      if (!mounted) return;
      setState(() {
        _assistants = a['assistants'] as List<dynamic>? ?? [];
        _deleted = d['campaigns'] as List<dynamic>? ?? [];
        _actions = ac['actions'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load. Try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _addAssistant() async {
    final api = ref.read(apiClientProvider);
    final searchController = TextEditingController();
    List<dynamic> results = [];
    Map<dynamic, dynamic>? pickedUser;
    final Set<String> scopes = {'tickets'};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> doSearch() async {
            final q = searchController.text.trim();
            if (q.isEmpty) return;
            setDialogState(() => results = []);
            try {
              final r = await api.searchUsers(q);
              if (ctx.mounted) setDialogState(() => results = r['users'] ?? []);
            } catch (_) {}
          }

          return AlertDialog(
          title: const Text('Add assistant'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Search for a user by phone or username, then pick what they can do.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          labelText: 'Search user',
                          prefixIcon: Icon(LucideIcons.search, size: 18),
                        ),
                        onSubmitted: (_) => doSearch(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Search',
                      onPressed: doSearch,
                      icon: const Icon(LucideIcons.search, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (pickedUser != null)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.checkCircle, size: 18, color: AppColors.primary),
                    title: Text(pickedUser!['username'] ?? 'Giver',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(pickedUser!['phone'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      tooltip: 'Change',
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => setDialogState(() => pickedUser = null),
                    ),
                  )
                else if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No results yet — search by phone or username.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  )
                else
                  for (final u in results)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.user, size: 18, color: AppColors.primary),
                      title: Text(u['username'] ?? 'Giver',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: Text(u['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: FilledButton(
                        onPressed: () => setDialogState(() {
                          pickedUser = u;
                          results = [];
                        }),
                        child: const Text('Select'),
                      ),
                    ),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Permissions',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                for (final entry in kAssistantScopeLabels.entries)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                    value: scopes.contains(entry.key),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        scopes.add(entry.key);
                      } else {
                        scopes.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: pickedUser == null
                  ? null
                  : () async {
                      try {
                        await api.saveAssistant(
                          (pickedUser!['id'] as num?)?.toInt() ?? 0,
                          permissions: scopes.toList(),
                          phone: pickedUser!['phone'] as String?,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx, true);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Assistant added')),
                          );
                        }
                        await _load();
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                     },
               child: const Text('Save assistant'),
            ),
          ],
        );
        },
      ),
    );
    searchController.dispose();
  }

  Future<void> _editAssistant(Map<dynamic, dynamic> assistant) async {
    final api = ref.read(apiClientProvider);
    final userId = (assistant['userId'] as num?)?.toInt() ?? 0;
    final name = assistant['username'] ?? 'Giver';
    final scopes = Set<String>.from(assistant['permissions'] as List<dynamic>? ?? const []);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit assistant permissions'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Permissions for "$name".',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                for (final entry in kAssistantScopeLabels.entries)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value, style: const TextStyle(fontSize: 13)),
                    value: scopes.contains(entry.key),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        scopes.add(entry.key);
                      } else {
                        scopes.remove(entry.key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await api.updateAssistant(userId, scopes.toList());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Permissions updated')),
                    );
                  }
                  await _load();
                } on ApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeAssistant(int userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove assistant?'),
        content: Text('Revoke all admin access for "$name"? They can be re-added anytime.'),
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
    try {
      await ref.read(apiClientProvider).removeAssistant(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistant removed')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _restoreCampaign(Map<dynamic, dynamic> campaign) async {
    final id = (campaign['id'] as num?)?.toInt() ?? 0;
    final title = campaign['title'] as String? ?? 'campaign';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore campaign?'),
        content: Text('"$title" will go back live and appear publicly again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ref.read(apiClientProvider).restoreCampaign(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Campaign restored')),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Staff & Restore')),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: AppColors.gold,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textMuted,
                        onTap: (i) => setState(() => _tab = i),
                        tabs: const [
                          Tab(text: 'Assistants'),
                          Tab(text: 'Restore'),
                          Tab(text: 'Audit log'),
                        ],
                      ),
                      Expanded(
                        child: _tab == 0
                            ? _buildAssistants(theme)
                            : _tab == 1
                                ? _buildRestore(theme)
                                : _buildAudit(theme),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAssistants(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _addAssistant,
            icon: const Icon(LucideIcons.userPlus, size: 18),
            label: const Text('Add assistant'),
          ),
          const SizedBox(height: 16),
          if (_assistants.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No assistants yet. Add a trusted team member with limited access.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final a in _assistants)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _editAssistant(a),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(a['username'] ?? 'Giver',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            IconButton(
                              tooltip: 'Edit permissions',
                              icon: const Icon(LucideIcons.pencil, size: 16),
                              onPressed: () => _editAssistant(a),
                            ),
                            IconButton(
                              tooltip: 'Remove assistant',
                              icon: const Icon(LucideIcons.userX, size: 18, color: AppColors.danger),
                              onPressed: () => _removeAssistant(
                                (a['userId'] as num?)?.toInt() ?? 0,
                                a['username'] ?? 'Giver',
                              ),
                            ),
                          ],
                        ),
                        Text(a['phone'] ?? '', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in (a['permissions'] as List<dynamic>? ?? []))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  kAssistantScopeLabels[p] ?? p,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to edit permissions',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
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

  Widget _buildRestore(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_deleted.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 40, color: AppColors.primaryLight),
                  SizedBox(height: 12),
                  Text('No deleted campaigns. Soft-deleted campaigns appear here so you can bring them back.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.archive, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Deleted campaigns (${_deleted.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            for (final c in _deleted)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.archiveRestore, size: 20, color: AppColors.primary),
                  ),
                  title: Text(
                    c['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c['hostName'] != null ? 'Hosted by ${c['hostName']}' : 'Deleted campaign',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      Text(
                        (c['createdAt'] as String? ?? '').replaceAll('T', ' '),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _restoreCampaign(c),
                    icon: const Icon(LucideIcons.rotateCcw, size: 14),
                    label: const Text('Restore'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudit(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_actions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No sensitive actions logged yet.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final a in _actions)
              ListTile(
                dense: true,
                leading: Icon(
                  a['action'] == 'campaign_delete'
                      ? LucideIcons.trash2
                      : a['action'] == 'campaign_restore'
                          ? LucideIcons.archiveRestore
                          : LucideIcons.history,
                  size: 18,
                  color: a['action'] == 'campaign_delete'
                      ? AppColors.danger
                      : AppColors.primary,
                ),
                title: Text(
                  '${a['actorName'] ?? 'Admin'} — ${a['action'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: Text(
                  a['details'] ?? '',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  (() {
                    final s = (a['createdAt'] as String? ?? '');
                    return s.length >= 10 ? s.substring(0, 10) : s;
                  })(),
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ),
        ],
      ),
    );
  }
}
