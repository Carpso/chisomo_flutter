import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../core/widgets/avatar.dart';

/// A private conversation between the host and confirmed supporters of a
/// campaign or event. Anyone who has donated / bought a ticket / RSVP'd can
/// read and post; new messages push to the other supporters.
class CampaignChatSection extends ConsumerStatefulWidget {
  final int campaignId;
  final bool isEvent;

  const CampaignChatSection({super.key, required this.campaignId, this.isEvent = false});

  @override
  ConsumerState<CampaignChatSection> createState() => _CampaignChatSectionState();
}

class _CampaignChatSectionState extends ConsumerState<CampaignChatSection> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  final _controller = TextEditingController();
  bool _sending = false;
  final _latestKey = GlobalKey();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Lightweight polling (every 8s) so new messages appear without a manual
    // refresh; pushes + in-app notifications handle the alert side.
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls the PAGE so the latest message is visible. Works because the
  /// message list is not itself scrollable — it flows inside the outer
  /// ListView, so this bubbles the request up to the page scrollable.
  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _latestKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 1.0,
      );
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final rows = await ref.read(apiClientProvider).getCampaignChat(widget.campaignId);
      if (!mounted) return;
      final prevCount = _messages.length;
      setState(() {
        _messages = rows.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _error = null;
        _loading = false;
      });
      // Scroll to the latest message on first load and when a new message
      // arrives (e.g. after sending or polling).
      if (_messages.isNotEmpty && (_messages.length != prevCount || prevCount == 0)) {
        _scrollToLatest();
      }
    } on ApiException catch (e) {
      if (!silent && mounted) setState(() => _error = e.message);
    } catch (_) {
      if (!silent && mounted) setState(() => _error = 'Could not load the conversation.');
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).postCampaignChat(widget.campaignId, text);
      _controller.clear();
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.statusCode == 403
              ? widget.isEvent
                  ? 'Buy a ticket or RSVP to join the event chat.'
                  : 'Give to this campaign to join the conversation.'
              : e.message),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your message. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Deletes a message (own message, or any message if the user is the host).
  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = (message['id'] as num?)?.toInt() ?? 0;
    final mine = message['isMine'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this message?'),
        content: const Text('This removes the message from the conversation.'),
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
    if (confirmed != true || !mounted || id == 0) return;
    try {
      await ref.read(apiClientProvider).deleteCampaignChat(widget.campaignId, id);
      if (mounted) {
        setState(() => _messages.removeWhere((m) => (m['id'] as num?)?.toInt() == id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mine ? 'Message deleted' : 'Message removed')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete the message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(widget.isEvent ? LucideIcons.ticket : LucideIcons.messageCircle,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isEvent ? 'Event chat' : 'Campaign chat',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  onPressed: () => _load(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_loading && _messages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null && _messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          else if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(widget.isEvent ? LucideIcons.ticket : LucideIcons.messageCircle,
                      size: 28, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    widget.isEvent
                        ? 'No messages yet. Say hi and rally your guests!'
                        : 'No messages yet. Thank your supporters and answer questions here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
            )
          else
            // Messages flow inside the page's own scroll (never a nested
            // scrollable), so the whole page scrolls everywhere — including
            // directly over the chat area. `_latestKey` lets us auto-scroll
            // the page to the newest message after sending/polling.
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, m) in _messages.indexed)
                    _MessageBubble(
                      key: i == _messages.length - 1 ? _latestKey : null,
                      message: m,
                      theme: theme,
                      onDelete: m['canDelete'] == true ? () => _deleteMessage(m) : null,
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.isEvent
                          ? 'Message your guests…'
                          : 'Message your supporters…',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.send, size: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single chat bubble rendered inline in the page scroll (not scrollable).
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final ThemeData theme;
  final VoidCallback? onDelete;

  const _MessageBubble({super.key, required this.message, required this.theme, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final mine = m['isMine'] == true;
    final isHost = m['isHost'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine
              ? AppColors.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!mine) ...[
                  Avatar(
                    url: m['avatarUrl'] as String?,
                    name: m['name'] as String? ?? 'S',
                    radius: 10,
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    (m['name'] as String? ?? 'Supporter').toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isHost ? AppColors.gold : AppColors.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (isHost) ...[
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.badgeCheck, size: 10, color: AppColors.gold),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              m['body'] as String? ?? '',
              style: const TextStyle(fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 2),
            Text(
              safeDateTime(m['createdAt']),
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
