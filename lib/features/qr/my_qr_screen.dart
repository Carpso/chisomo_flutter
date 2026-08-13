import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';

/// Shows the signed-in user's profile QR code. An admin scans it to confirm
/// the person and view their profile.
class MyQrScreen extends ConsumerWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final phone = auth?.phone ?? '';
    final username = auth?.username ?? 'Giver';
    final name = auth?.name;
    final data = 'KSQR|$phone|$username|${name ?? ''}';

    return Scaffold(
      appBar: AppBar(title: const Text('My QR Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Show this code to a Kingdom Sponsor admin to confirm your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: QrImageView(
                  data: data,
                  size: 260,
                  backgroundColor: Colors.white,
                  embeddedImage: const AssetImage('assets/kingdom_sponsor_app_icon.jpg'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(56, 56)),
                ),
              ),
              const SizedBox(height: 24),
              Text(username,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (name != null && name.isNotEmpty)
                Text(name, style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(phone, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Icon(LucideIcons.lock, size: 14, color: AppColors.textMuted),
              const SizedBox(height: 2),
              const Text('Your number is never shown publicly — the code only identifies you to staff.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
