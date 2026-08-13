import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_icon_spinner.dart';
import '../auth/auth_controller.dart';

/// Internal Kingdom Sponsor team group chat — staff (admins + assistants)
/// discuss the work, share images, and see everyone's messages in one thread.
class TeamChatScreen extends ConsumerStatefulWidget {
  const TeamChatScreen({super.key});

  @override
  ConsumerState<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends ConsumerState<TeamChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _uploading = false;
  String? _error;
  Timer? _poll;
  String _roomName = 'Team Chat';

  @override
  void initState() {
    super.initState();
    _loadRoomName();
    _load();
    // Lightweight polling so the group thread stays live.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_sending && !_loading) _load(silent: true);
    });
  }

  Future<void> _loadRoomName() async {
    try {
      final name = await ref.read(apiClientProvider).getTeamRoomName();
      if (mounted && name.isNotEmpty) setState(() => _roomName = name);
    } catch (_) {}
  }

  Future<void> _renameRoom() async {
    final controller = TextEditingController(text: _roomName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename team chat'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Room name', isDense: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(apiClientProvider).renameTeamRoom(name);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ok == true) await _loadRoomName();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final msgs = await ref.read(apiClientProvider).getTeamMessages();
      if (!mounted) return;
      final wasAtBottom = _scroll.hasClients &&
          (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 80);
      setState(() => _messages = msgs);
      if (wasAtBottom || !silent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {
      if (!silent && mounted) setState(() => _error = 'Could not load the team chat.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).sendTeamMessage(text);
      _controller.clear();
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ref.read(apiClientProvider).uploadTeamImage(bytes, file.name);
      if (url.isEmpty) throw Exception('upload failed');
      await ref.read(apiClientProvider).sendTeamMessage('Shared an image', imageUrl: url);
      await _load(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not upload the image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final myUsername = me?.username;

    return Scaffold(
      appBar: AppBar(
        title: Text(_roomName),
        actions: [
          if (ref.watch(authControllerProvider).value?.isAdmin == true) ...[
            IconButton(
              tooltip: 'Add team member',
              icon: const Icon(LucideIcons.userPlus, size: 18),
              onPressed: () => context.push('/admin/staff'),
            ),
            IconButton(
              tooltip: 'Rename room',
              icon: const Icon(LucideIcons.pencil, size: 18),
              onPressed: _renameRoom,
            ),
          ],
          IconButton(icon: const Icon(LucideIcons.refreshCw), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: AppIconSpinner())
                : _error != null && _messages.isEmpty
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = (m['username'] as String?) == myUsername;
                          return _MessageBubble(message: m, mine: mine);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.15))),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Share an image',
                    icon: _uploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.image, color: AppColors.primary),
                    onPressed: _uploading ? null : _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message the team…',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.send, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;

  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final body = message['body'] as String? ?? '';
    final imageUrl = message['imageUrl'] as String?;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Text(message['username'] as String? ?? 'Team',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.gold)),
            if (imageUrl != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(imageUrl, width: 220, height: 160, fit: BoxFit.cover),
              ),
            ],
            if (body.isNotEmpty) ...[
              if (imageUrl != null) const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(color: mine ? Colors.white : AppColors.textDark, fontSize: 13.5, height: 1.3)),
            ],
            const SizedBox(height: 2),
            Text(
              (message['createdAt'] as String? ?? '').toString().replaceAll('T', ' '),
              style: TextStyle(fontSize: 9.5, color: mine ? Colors.white70 : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
