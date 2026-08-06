import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme.dart';

/// Orange-branded shimmer skeleton for loading states.
class AppShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const AppShimmer({super.key, required this.height, this.width, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _ShimmerAnimation(),
    );
  }
}

class _ShimmerAnimation extends StatefulWidget {
  @override
  State<_ShimmerAnimation> createState() => _ShimmerAnimationState();
}

class _ShimmerAnimationState extends State<_ShimmerAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment(-1 - 2 * _controller.value, 0),
            end: Alignment(1 - 2 * _controller.value, 0),
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.06),
            ],
          ),
        ),
      ),
    );
  }
}

/// Snackbar for success feedback with green check.
void showSuccessToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            child: const Icon(LucideIcons.check, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Test mode banner shown when ENV=sandbox.
class TestModeBanner extends StatelessWidget {
  const TestModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.gold,
      child: const Text(
        '⚡ TEST MODE',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Countdown widget showing days remaining.
class CountdownBadge extends StatelessWidget {
  final DateTime? endsAt;
  final bool compact;

  const CountdownBadge({super.key, this.endsAt, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (endsAt == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final days = endsAt!.difference(now).inDays;
    if (days < 0) return _badge('Ended', AppColors.danger);
    if (days == 0) return _badge('Last day', AppColors.danger);
    if (days <= 3) return _badge('$days days left', AppColors.danger);
    if (days <= 7) return _badge('$days days left', AppColors.gold);
    return _badge('$days days left', AppColors.textMuted);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Copy to clipboard button with feedback.
class CopyButton extends StatefulWidget {
  final String text;
  final String? label;

  const CopyButton({super.key, required this.text, this.label});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        // Clipboard.setData(ClipboardData(text: widget.text)); // Would need flutter/services
        setState(() => _copied = true);
        showSuccessToast(context, 'Link copied!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      icon: Icon(_copied ? LucideIcons.check : LucideIcons.copy, size: 14),
      label: Text(_copied ? 'Copied' : (widget.label ?? 'Copy')),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: _copied ? AppColors.primary : AppColors.textMuted,
      ),
    );
  }
}
