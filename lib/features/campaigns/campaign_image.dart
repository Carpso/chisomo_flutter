import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';

/// Campaign cover/logo image. Falls back to the Kingdom Sponsor app icon
/// when the campaign has no image or it fails to load. Images are cached on
/// disk so they still appear offline after the first load.
class CampaignImage extends StatelessWidget {
  final Campaign campaign;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CampaignImage({
    super.key,
    required this.campaign,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  String? get _url => campaign.logoUrl ?? campaign.imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return _appIcon();
    return CachedNetworkImage(
      imageUrl: '$url?t=${campaign.createdAt}',
      width: width,
      height: height,
      fit: fit,
      errorWidget: (_, _, _) => _appIcon(),
    );
  }

  Widget _appIcon() => Image.asset(
        'assets/kingdom_sponsor_app_icon.jpg',
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome, size: 28),
      );
}
