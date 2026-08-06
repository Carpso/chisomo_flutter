import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme.dart';

/// A small circled "i" that opens a bottom-sheet explanation when tapped.
/// Used to surface feature explanations without cluttering the UI.
class InfoBadge extends StatelessWidget {
  final String text;
  final String? title;
  final double size;

  const InfoBadge({
    super.key,
    required this.text,
    this.title,
    this.size = 18,
  });

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                text,
                style: Theme.of(ctx)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.textMuted.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.info, size: size - 6, color: AppColors.textMuted),
      ),
    );
  }
}
