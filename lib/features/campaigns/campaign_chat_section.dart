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
  final _scrollController = ScrollController();
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
    _scrollController.dispose();
    super.dispose();
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
      // Scroll to bottom when a new message arrives (only if we were near the
      // bottom or this is the first load).
      if (_messages.length != prevCount && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
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
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final mine = m['isMine'] == true;
                  final isHost = m['isHost'] == true;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                                  (m['name'] as String? ?? 'Supporter')
                                      .toUpperCase(),
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
                },
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
