import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../campaigns/models.dart';

/// Bottom sheet offering WhatsApp share, a QR code, and copy-link.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, Campaign campaign) async {
  final url = ref.read(apiClientProvider).shareUrl(campaign.id);
  final text = '${campaign.title}\n${campaign.description}\nGive here: $url';
  final waUrl = 'https://wa.me/?text=${Uri.encodeComponent(text)}';

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share ${campaign.title}',
            textAlign: TextAlign.center,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: const Color(0xFF06281B),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              if (!await launchUrl(Uri.parse(waUrl), mode: LaunchMode.externalApplication)) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Could not open WhatsApp. Try the copy link button.')),
                  );
                }
              }
            },
            icon: const Icon(LucideIcons.messageCircle),
            label: const Text('Share on WhatsApp'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Link copied')));
              }
            },
            icon: const Icon(LucideIcons.copy, size: 18),
            label: const Text('Copy link'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: url,
                  size: 180,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  'Scan to open this fundraiser',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
