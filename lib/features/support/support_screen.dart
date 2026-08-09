import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  List<dynamic> _tickets = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await ref.read(apiClientProvider).getSupportTickets();
      if (mounted) setState(() => _tickets = tickets);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your requests.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose() async {
    final subject = TextEditingController();
    final message = TextEditingController();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Contact support'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subject,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'What do you need help with?',
                    prefixIcon: Icon(LucideIcons.messageCircle),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: message,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    hintText: 'Describe your issue…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([subject, message]),
              builder: (context, _) {
                final ready = subject.text.trim().isNotEmpty &&
                    message.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: saving || !ready
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await ref.read(apiClientProvider).createSupportTicket(
                                  subject.text.trim(),
                                  message.text.trim(),
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Request sent. The admin will reply shortly.')),
                              );
                            }
                          } on ApiException catch (e) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx)
                                  .showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          } catch (_) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Could not send the request. Try again.')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) await _fetch();
    subject.dispose();
    message.dispose();
  }

  Future<void> _reply(Map<String, dynamic> ticket, {required bool asAdmin}) async {
    final text = TextEditingController();
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(asAdmin ? 'Reply to #${ticket['id']}' : 'Add a message'),
          content: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: TextField(
              controller: text,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: text,
              builder: (context, _, __) {
                final ready = text.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: saving || !ready
                      ? null
                      : () async {
                          setDialogState(() => saving = true);
                          try {
                            await ref
                                .read(apiClientProvider)
                                .replySupportTicket(ticket['id'] as int, text.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Reply sent.')),
                              );
                            }
                          } on ApiException catch (e) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx)
                                  .showSnackBar(SnackBar(content: Text(e.message)));
                            }
                          } catch (_) {
                            setDialogState(() => saving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Could not send. Try again.')),
                              );
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                );
              },
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) await _fetch();
    text.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & support'),
        actions: [
          IconButton(
            tooltip: 'New request',
            icon: const Icon(LucideIcons.plus),
            onPressed: _compose,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: AppIconSpinner())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _fetch,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(LucideIcons.headphones,
                                        color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Need help?',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Send a message to the admin and we will reply here and by SMS.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _compose,
                                  icon: const Icon(LucideIcons.plus, size: 16),
                                  label: const Text('New request'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'My requests',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (_tickets.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(LucideIcons.inbox,
                                    size: 32, color: AppColors.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  'No requests yet.',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final t in _tickets)
                          Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t['subject'] ?? 'Request',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      _StatusChip(status: t['status'] ?? ''),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t['message'] ?? '',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  if (t['adminReply'] != null) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.07),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(LucideIcons.shield,
                                                  size: 14, color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Admin reply',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.primary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            t['adminReply'] as String,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '${safeDate(t['createdAt'])} • '
                                        '${_statusLabel(t['status'] ?? '')}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: AppColors.textMuted),
                                      ),
                                      const Spacer(),
                                      if (_busy.contains(t['id']))
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      else
                                        TextButton.icon(
                                          onPressed: () => _reply(t, asAdmin: false),
                                          icon: const Icon(LucideIcons.reply, size: 15),
                                          label: const Text('Reply'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'open' => 'Awaiting reply',
        'answered' => 'Answered',
        'closed' => 'Closed',
        _ => status,
      };
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  static String _label(String s) => switch (s) {
        'open' => 'Awaiting reply',
        'answered' => 'Answered',
        'closed' => 'Closed',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'open' => AppColors.gold,
      'answered' => AppColors.primary,
      'closed' => AppColors.textMuted,
      _ => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
