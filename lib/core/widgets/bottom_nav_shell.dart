import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../l10n.dart';
import '../theme.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell> {
  int _currentIndex = 0;
  bool _showNav = true;

  static const _tabs = [
    _NavTab('/', LucideIcons.home, 'nav.campaigns', AppColors.primary),
    _NavTab('/events', LucideIcons.ticket, 'nav.events', AppColors.gold),
    _NavTab('/host', LucideIcons.user, 'nav.host', AppColors.primary),
    _NavTab('/settings', LucideIcons.settings, 'nav.settings', AppColors.textMuted),
  ];

  @override
  void initState() {
    super.initState();
    _syncIndex();
  }

  void _syncIndex() {
    final loc = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc == _tabs[i].path || loc.startsWith('${_tabs[i].path}/')) {
        if (_currentIndex != i) {
          _currentIndex = i;
        }
        return;
      }
    }
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return;
    // Ignore horizontal scrolls — the home carousel's PageView auto-slides and
    // would otherwise toggle the nav bar on/off (flicker) as its pages move.
    if (notification.metrics.axis != Axis.vertical) return;
    final metrics = notification.metrics;
    final atTop = metrics.pixels <= 0;
    final scrollingUp = notification.scrollDelta != null && notification.scrollDelta! < 0;
    final show = atTop || scrollingUp;
    if (show != _showNav) {
      setState(() => _showNav = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncIndex();
    final loc = GoRouterState.of(context).matchedLocation;
    final lang = ref.watch(languageProvider);
    final showNavOnRoute = _tabs.any((tab) => loc == tab.path);
    final showNav = showNavOnRoute && _showNav;
    return Scaffold(
      // The shell must NOT resize for the keyboard: every form screen inside
      // it has its own Scaffold + viewInsets padding. Two nested Scaffolds
      // resizing together makes the IME flicker/close on some devices.
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _handleScrollNotification(notification);
          return false;
        },
        child: widget.child,
      ),
      bottomNavigationBar: showNav
          ? Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (index == _currentIndex) return;
                  _currentIndex = index;
                  context.go(_tabs[index].path);
                },
                indicatorColor: AppColors.primary.withValues(alpha: 0.1),
                surfaceTintColor: Colors.transparent,
                destinations: [
                  for (final tab in _tabs)
                    NavigationDestination(
                      icon: Icon(tab.icon,
                          size: 22, color: AppColors.textMuted),
                      selectedIcon: Icon(tab.icon,
                          size: 22, color: tab.color),
                      label: tr(lang, tab.labelKey),
                      tooltip: tr(lang, tab.labelKey),
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

class _NavTab {
  final String path;
  final IconData icon;
  final String labelKey;
  final Color color;

  const _NavTab(this.path, this.icon, this.labelKey, this.color);
}