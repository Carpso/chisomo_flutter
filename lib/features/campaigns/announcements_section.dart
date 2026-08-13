import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/theme.dart';

/// Shows the host's moderated updates ("Updates from the host") on a campaign
/// or event page. Only approved updates are returned by the API.
class AnnouncementsSection extends ConsumerStatefulWidget {
  final int campaignId;
  final bool isEvent;

  const AnnouncementsSection({super.key, required this.campaignId, this.isEvent = false});

  @override
  ConsumerState<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends ConsumerState<AnnouncementsSection> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(apiClientProvider).getAnnouncements(widget.campaignId);
  }

  void _retry() {
    setState(() {
      _future = ref.read(apiClientProvider).getAnnouncements(widget.campaignId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError && items.isEmpty) {
          return Row(
            children: [
              const Icon(LucideIcons.megaphone, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not load updates from the host.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              TextButton(onPressed: _retry, child: const Text('Retry')),
            ],
          );
        }
        if (snapshot.hasData && items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEvent ? 'Updates from the host' : 'Updates from the host',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final a in items)
                    ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.megaphone, size: 20, color: AppColors.primary),
                      title: Text(
                        a['body'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${a['author'] ?? 'Host'} · ${safeDate(a['createdAt'])}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
