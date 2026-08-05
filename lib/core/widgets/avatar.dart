import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Profile photo with a colored-initial fallback (offline-safe via cache).
class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  final Color? background;

  const Avatar({
    super.key,
    this.url,
    required this.name,
    this.radius = 18,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final bg = background ?? AppColors.primary.withValues(alpha: 0.12);
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(
          initial,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.8,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      backgroundImage: CachedNetworkImageProvider(url!),
      onBackgroundImageError: (_, _) {},
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
