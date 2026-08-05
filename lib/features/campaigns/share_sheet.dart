import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../campaigns/models.dart';

/// Returns the signed-in user's referral code for link tagging (best-effort).
Future<String?> _refQuery(ApiClient api) async {
  try {
    final res = await api.getMyReferral();
    final code = res['code'] as String?;
    return (code == null || code.trim().isEmpty) ? null : code.trim();
  } catch (_) {
    return null;
  }
}

/// Bottom sheet offering WhatsApp share, a QR code with app icon, and copy-link.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, Campaign campaign) async {
  final api = ref.read(apiClientProvider);
  final auth = ref.read(authControllerProvider).value;
  final refParam = auth != null ? await _refQuery(api) : null;
  final refSuffix = refParam == null ? '' : '?ref=$refParam';
  final url = '${api.shareUrl(campaign.id)}$refSuffix';
  final deepLink = '${api.deepLink(campaign.id)}$refSuffix';
  final playStore = ApiClient.playStoreUrl;
  final text =
      '${campaign.title}\n${campaign.description}\nGive here: $url\nNo app yet? Get Kingdom Sponsor: $playStore';
  final waUrl = 'https://wa.me/?text=${Uri.encodeComponent(text)}';

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom + 16,
        top: 16,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                if (!await launchUrl(Uri.parse(deepLink), mode: LaunchMode.externalApplication)) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Open the app from the Play Store first.')),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.smartphone, size: 18),
              label: const Text('Open in app'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
              onPressed: () async {
                if (!await launchUrl(Uri.parse(playStore), mode: LaunchMode.externalApplication)) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Could not open the Play Store.')),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.shoppingBag, size: 18),
              label: const Text('No app? Get it on Play Store'),
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
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: url,
                          size: 180,
                          backgroundColor: Colors.white,
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            'assets/kingdom_sponsor_app_icon.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.auto_awesome, size: 24),
                          ),
                        ),
                      ],
                    ),
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
    ),
  );
}
