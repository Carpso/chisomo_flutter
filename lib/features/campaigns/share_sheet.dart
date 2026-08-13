import 'dart:io';
import 'dart:ui' as ui;

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

/// Generates a branded 1080x1080 share card (gradient + title + amount + host)
/// when a campaign has no photo, so every share still looks professional.
Future<XFile?> _generateShareCard(Campaign campaign) async {
  try {
    const width = 1080.0;
    const height = 1080.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const rect = ui.Rect.fromLTWH(0, 0, width, height);

    // Background gradient.
    final paint = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(width, height),
        [const ui.Color(0xFF1d4ed8), const ui.Color(0xFF0f172a)],
      );
    canvas.drawRect(rect, paint);

    // Accent bar.
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, width, 18),
      ui.Paint()..color = const ui.Color(0xFFE65100),
    );

    // Brand.
    _drawText(canvas, 'Kingdom Sponsor',
        const ui.Offset(80, 90), 54, const ui.Color(0xFFFCD34D), bold: true);
    // Title (wrapped, up to 4 lines).
    final title = campaign.title;
    final titleStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.left,
      maxLines: 4,
      fontSize: 76,
      fontWeight: FontWeight.w800,
      textDirection: ui.TextDirection.ltr,
    );
    final titleBuilder = ui.ParagraphBuilder(titleStyle)
      ..addText(title);
    final titlePara = titleBuilder.build()..layout(const ui.ParagraphConstraints(width: width - 160));
    canvas.drawParagraph(titlePara, const ui.Offset(80, 220));

    // Raised amount + host.
    final meta = '${campaign.raisedLabel} raised'
        '${campaign.hostName != null && campaign.hostName!.isNotEmpty ? '  •  ${campaign.hostName}' : ''}';
    _drawText(canvas, meta, const ui.Offset(80, 720), 44, const ui.Color(0xFF94A3B8));
    _drawText(canvas, 'Give on Kingdom Sponsor',
        const ui.Offset(80, 940), 40, const ui.Color(0xFFE2E8F0), bold: true);

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ks_card_${campaign.id}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return XFile(file.path, mimeType: 'image/png');
  } catch (_) {
    return null;
  }
}

void _drawText(ui.Canvas canvas, String text, ui.Offset offset, double fontSize, ui.Color color, {bool bold = false}) {
  final style = ui.ParagraphStyle(
    textAlign: ui.TextAlign.left,
    maxLines: 1,
    fontSize: fontSize,
    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    textDirection: ui.TextDirection.ltr,
  );
  final b = ui.ParagraphBuilder(style)..addText(text);
  final para = b.build()..layout(const ui.ParagraphConstraints(width: 900));
  canvas.drawParagraph(para, offset);
}

/// Downloads the campaign image (network URL or bundled asset) to a temp file
/// so it can be attached to a native share (WhatsApp, etc.). Falls back to a
/// generated branded card when the campaign has no photo.
Future<XFile?> _resolveCampaignImageFile(Campaign campaign) async {
  final image = campaign.logoUrl ?? campaign.imageUrl;
  if (image == null || image.isEmpty) {
    return _generateShareCard(campaign);
  }
  try {
    final dir = await getTemporaryDirectory();
    final ext = image.toLowerCase().endsWith('.webp') ? 'webp' : 'png';
    final file = File('${dir.path}/ks_share_${campaign.id}.$ext');
    if (image.startsWith('assets/')) {
      final data = await rootBundle.load(image);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } else {
      final res = await http.get(Uri.parse(image));
      if (res.statusCode != 200) return _generateShareCard(campaign);
      await file.writeAsBytes(res.bodyBytes, flush: true);
    }
    return XFile(file.path, mimeType: ext == 'webp' ? 'image/webp' : 'image/png');
  } catch (_) {
    return _generateShareCard(campaign);
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
  final deepLink = campaign.isEvent
      ? '${api.eventDeepLink(campaign.id)}$refSuffix'
      : '${api.deepLink(campaign.id)}$refSuffix';
  final donateDeep = campaign.isEvent
      ? '${api.eventTicketDeepLink(campaign.id)}$refSuffix'
      : '${api.donateDeepLink(campaign.id)}$refSuffix';
  final playStore = ApiClient.playStoreUrl;

  // Share message template: title, one-line summary, and the web link. The
  // web page handles payment/ticket-buying (and offers an "Open in app"
  // fallback), so the raw deep link is left out of the message — it only
  // confused recipients.
  final statsLine = StringBuffer()
    ..write(campaign.raisedLabel)
    ..write(campaign.isEvent ? ' in ticket sales' : ' raised');
  if (campaign.donorCount > 0) statsLine.write(' \u00b7 ${campaign.donorCount} ${campaign.isEvent ? 'tickets' : 'donors'}');
  if (campaign.hostName != null && campaign.hostName!.isNotEmpty) {
    statsLine.write(' \u00b7 ${campaign.hostName}');
  }
  final text = '${campaign.title}\n'
      '$statsLine\n'
      '$url';

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
                      SnackBar(content: Text(campaign.isEvent
                          ? 'Open the app from the Play Store first, then use the Buy tickets button.'
                          : 'Open the app from the Play Store first, then use the donate button.')),
                    );
                  }
                }
              },
              icon: Icon(
                campaign.isEvent ? LucideIcons.ticket : LucideIcons.wallet,
                size: 18,
              ),
              label: Text(
                campaign.isEvent ? 'Buy tickets now' : 'Donate now',
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
                    campaign.isEvent
                        ? 'Scan to buy tickets for this event'
                        : 'Scan to open this fundraiser',
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
