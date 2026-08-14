import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

/// Admin Sponsor Desk manager — curate the weekly batch of grant/empowerment
/// opportunities and publish them to active hosts (push + in-app notification).
class AdminSponsorDeskScreen extends ConsumerStatefulWidget {
  const AdminSponsorDeskScreen({super.key});

  @override
  ConsumerState<AdminSponsorDeskScreen> createState() => _AdminSponsorDeskScreenState();
}

class _AdminSponsorDeskScreenState extends ConsumerState<AdminSponsorDeskScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _publishing = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref.read(apiClientProvider).getAdminSponsorDesk();
      if (mounted) {
        setState(() {
          _items = rows.whereType<Map>().map((o) => Map<String, dynamic>.from(o)).toList();
          _selected.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load the Sponsor Desk.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final titleController = TextEditingController(text: existing?['title'] ?? '');
    final orgController = TextEditingController(text: existing?['organization'] ?? '');
    final amountController = TextEditingController(text: existing?['amountLabel'] ?? '');
    final linkController = TextEditingController(text: existing?['link'] ?? '');
    final deadlineController = TextEditingController(
      text: existing?['deadline'] != null ? safeDate(existing!['deadline']) : '',
    );
    final descController = TextEditingController(text: existing?['description'] ?? '');
    final matchController = TextEditingController(
      text: (existing?['matchCategories'] as List? ?? []).join(', '),
    );
    String category = (existing?['category'] as String? ?? 'Grant').trim();
    String audience = (existing?['audience'] as String? ?? 'hosts').trim();
    final categories = ['Grant', 'Empowerment', 'Matching funds', 'Loan / financing', 'In-kind', 'Mentorship', 'Scholarship'];
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New opportunity' : 'Edit opportunity'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: orgController,
                  decoration: const InputDecoration(labelText: 'Organization / funder', isDense: true),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(category) ? category : 'Grant',
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Grant'),
                  decoration: const InputDecoration(labelText: 'Category', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (e.g. "Up to K50,000")',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: deadlineController,
                  decoration: const InputDecoration(
                    labelText: 'Deadline (YYYY-MM-DD, optional)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkController,
                  decoration: const InputDecoration(
                    labelText: 'Application link (https://…)',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: matchController,
                  decoration: const InputDecoration(
                    labelText: 'Best-match categories (comma-separated campaign categories)',
                    hintText: 'e.g. Medical & Health, Children & Orphans',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: ['hosts', 'events', 'all'].contains(audience) ? audience : 'hosts',
                  items: const [
                    DropdownMenuItem(value: 'hosts', child: Text('Campaign hosts')),
                    DropdownMenuItem(value: 'events', child: Text('Event hosts')),
                    DropdownMenuItem(value: 'all', child: Text('All hosts')),
                  ],
                  onChanged: (v) => setDialogState(() => audience = v ?? 'hosts'),
                  decoration: const InputDecoration(labelText: 'Audience', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final body = <String, dynamic>{
      'title': titleController.text.trim(),
      'organization': orgController.text.trim(),
      'category': category,
      'amountLabel': amountController.text.trim(),
      'deadline': deadlineController.text.trim(),
      'link': linkController.text.trim(),
      'description': descController.text.trim(),
      'audience': audience,
      'matchCategories': matchController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    };
    if (existing != null) body['id'] = existing['id'];
    try {
      await ref.read(apiClientProvider).saveSponsorDesk(body);
      messenger.showSnackBar(SnackBar(content: Text(existing == null ? 'Opportunity saved (draft)' : 'Opportunity updated')));
      await _load();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save. Try again.')));
    }
  }

  Future<void> _publishSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one opportunity to publish.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publish to active hosts?'),
        content: Text(
          'This pushes a notification to every approved host with an active '
          'campaign (${ids.length} opportunity${ids.length == 1 ? '' : 'ies'}). '
          'They can see the full list in their Sponsor Desk.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _publishing = true);
    try {
      final res = await ref.read(apiClientProvider).publishSponsorDesk(ids);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Published to ${res['hostsNotified'] ?? 0} hosts'),
        ));
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not publish. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> o) async {
    final id = (o['id'] as num?)?.toInt() ?? 0;
    final newStatus = o['status'] == 'archived' ? 'active' : 'archived';
    try {
      await ref.read(apiClientProvider).setSponsorDeskStatus(id, newStatus);
      await _load();
    } catch (_) {}
  }

  Future<void> _delete(Map<String, dynamic> o) async {
    final id = (o['id'] as num?)?.toInt() ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this opportunity?'),
        content: const Text('This removes it permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteSponsorDesk(id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor Desk'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add opportunity'),
      ),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Curate 3–5 opportunities a week and publish them to '
                          'active hosts. Keeps hosts coming back for funding '
                          'intelligence, not just payment processing.',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _publishing ? null : _publishSelected,
                        icon: _publishing
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.send, size: 15),
                        label: Text(_publishing ? 'Publishing…' : 'Publish (${_selected.length})'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No opportunities yet. Tap "+ Add opportunity".'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 96),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) {
                            final o = _items[i];
                            final id = (o['id'] as num?)?.toInt() ?? 0;
                            final published = o['published'] == true;
                            final archived = o['status'] == 'archived';
                            final selected = _selected.contains(id);
                            return Card(
                              margin: EdgeInsets.zero,
                              color: archived
                                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                  : null,
                              child: ListTile(
                                leading: Checkbox(
                                  value: selected,
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  }),
                                ),
                                title: Text(
                                  o['title'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    decoration: archived ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${o['organization'] ?? ''} • ${o['category'] ?? 'Grant'}'
                                  '${o['amountLabel'] != null && (o['amountLabel'] as String).isNotEmpty ? ' • ${o['amountLabel']}' : ''}'
                                  '${o['deadline'] != null ? ' • due ${safeDate(o['deadline'])}' : ''}\n'
                                  '${published ? 'Published' : 'Draft'} • ${archived ? 'Archived' : 'Active'}'
                                  ' • ${o['appliedCount'] ?? 0} applied',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(LucideIcons.pencil, size: 16),
                                      onPressed: () => _edit(o),
                                    ),
                                    IconButton(
                                      tooltip: archived ? 'Restore' : 'Archive',
                                      icon: Icon(
                                        archived ? LucideIcons.rotateCcw : LucideIcons.archive,
                                        size: 16,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () => _toggleStatus(o),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                                      onPressed: () => _delete(o),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
