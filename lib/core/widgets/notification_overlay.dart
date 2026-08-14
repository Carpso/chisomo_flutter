import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../push_service.dart';
import '../theme.dart';
import 'app_brand_icon.dart';

/// In-app notification banner that slides down from the top when a push arrives
/// while the app is in the foreground — the "smart pop-up" so an alert is never
/// silent even when the user is looking at the app. Tapping it routes to the
/// notification's deep link (campaign, event, airtime, sponsor desk, …).
class NotificationOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationOverlay({super.key, required this.child});

  @override
  ConsumerState<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends ConsumerState<NotificationOverlay> {
  OverlayEntry? _currentBanner;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onInAppBanner = _onNotification;
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _currentBanner?.remove();
    super.dispose();
  }

  void _onNotification(String title, String body, String? route) {
    if (!mounted) return;
    if (title.isEmpty && body.isEmpty) return;

    _dismissTimer?.cancel();
    _currentBanner?.remove();

    final overlay = Overlay.of(context);

    _currentBanner = OverlayEntry(
      builder: (_) => _NotificationBanner(
        title: title,
        body: body,
        onTap: () {
          _dismissBanner();
          if (route != null && route.isNotEmpty && mounted) {
            context.go(route);
          }
        },
        onDismiss: _dismissBanner,
      ),
    );

    overlay.insert(_currentBanner!);
    _dismissTimer = Timer(const Duration(seconds: 5), _dismissBanner);
  }

  void _dismissBanner() {
    _dismissTimer?.cancel();
    _currentBanner?.remove();
    _currentBanner = null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (_) => widget.onDismiss(),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const AppBrandIcon(size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
