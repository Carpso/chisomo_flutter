import 'package:flutter/material.dart';

/// The circular Kingdom Sponsor brand mark.
///
/// Used as the placeholder/identity icon wherever the app needs to signal
/// "this is Kingdom Sponsor" (nav buttons, empty states, stat tiles) instead
/// of generic icon shapes.
class AppBrandIcon extends StatelessWidget {
  final double size;
  final Color? shadowColor;
  final bool withShadow;

  const AppBrandIcon({
    super.key,
    this.size = 24,
    this.shadowColor,
    this.withShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = ClipOval(
      child: Image.asset(
        'assets/app_icon_circle.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.circle,
          size: size,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    if (!withShadow) return icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: 0.25),
            blurRadius: size / 4,
            offset: Offset(0, size / 12),
          ),
        ],
      ),
      child: icon,
    );
  }
}
