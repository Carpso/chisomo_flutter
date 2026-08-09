import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../campaigns/models.dart';

/// Downloads the campaign image (network URL or bundled asset) to a temp file
/// so it can be attached to a native share (WhatsApp, etc.). Returns null if
/// there is no image to share.
Future<XFile?> _resolveCampaignImageFile(Campaign campaign) async {
  final image = campaign.logoUrl ?? campaign.imageUrl;
  if (image == null || image.isEmpty) return null;
  try {
    final dir = await getTemporaryDirectory();
    final ext = image.toLowerCase().endsWith('.webp') ? 'webp' : 'png';
    final file = File('${dir.path}/ks_share_${campaign.id}.$ext');
    if (image.startsWith('assets/')) {
      final data = await rootBundle.load(image);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } else {
      final res = await http.get(Uri.parse(image));
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes, flush: true);
    }
    return XFile(file.path, mimeType: ext == 'webp' ? 'image/webp' : 'image/png');
  } catch (_) {
    return null;
  }
}

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
  // Prefer the server-issued short link (deterministic, always resolves);
  // fall back to the long share page. A referral tag needs the long URL so
  // the param survives (short links don't forward query params).
  final baseShare = campaign.shareUrl ?? api.shareUrl(campaign.id);
  final longShare = api.shareUrl(campaign.id);
  final url = refParam == null ? baseShare : '$longShare$refSuffix';
  final shortDisplay = refParam == null ? baseShare : longShare;
  final deepLink = '${api.deepLink(campaign.id)}$refSuffix';
  final donateDeep = '${api.donateDeepLink(campaign.id)}$refSuffix';
  final playStore = ApiClient.playStoreUrl;

  // Share message template: title, description, raised total, then the link.
  final statsLine = StringBuffer()
    ..write(campaign.raisedLabel)
    ..write(' raised');
  if (campaign.donorCount > 0) statsLine.write(' \u00b7 ${campaign.donorCount} donors');
  if (campaign.hostName != null && campaign.hostName!.isNotEmpty) {
    statsLine.write(' \u00b7 ${campaign.hostName}');
  }
  final text = '${campaign.title}\n'
      '${campaign.description}\n'
      '$statsLine\n\n'
      'Give here: $url\n'
      'Open in app: $deepLink\n'
      'No app? Get Kingdom Sponsor: $playStore';

  // wa.me supports only text — no image attachment param.
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                // Native share (default top option): attaches the campaign image
                // alongside the message so recipients see the photo.
                final messenger = ScaffoldMessenger.of(ctx);
                final img = await _resolveCampaignImageFile(campaign);
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: text,
                      files: img == null ? [] : [img],
                      subject: campaign.title,
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(img == null
                          ? 'Could not open the share sheet. Try copy link.'
                          : 'Could not share with the image. Try the WhatsApp button.')),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.share2, size: 18),
              label: const Text('Share with image'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.12),
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
              label: const Text('Copy Link'),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              ),
              onPressed: () async {
                if (!await launchUrl(Uri.parse(donateDeep), mode: LaunchMode.externalApplication)) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Open the app from the Play Store first, then use the donate button.')),
                    );
                  }
                }
              },
              icon: const Icon(LucideIcons.wallet, size: 18),
              label: Text(
                'Donate now',
                style: TextStyle(color: AppColors.primary),
              ),
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
              icon: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  'assets/play_store_badge.png',
                  height: 22,
                  errorBuilder: (_, __, ___) =>
                      const Icon(LucideIcons.shoppingBag, size: 18),
                ),
              ),
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
                          data: shortDisplay,
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
