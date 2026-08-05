import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BottomNavShell extends StatefulWidget {
  final Widget child;

  const BottomNavShell({super.key, required this.child});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _NavTab('/', LucideIcons.home, 'Campaigns'),
    _NavTab('/pledges', LucideIcons.calendarClock, 'Pledges'),
    _NavTab('/host', LucideIcons.user, 'Host'),
    _NavTab('/settings', LucideIcons.settings, 'Settings'),
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

  @override
  Widget build(BuildContext context) {
    _syncIndex();
    final loc = GoRouterState.of(context).matchedLocation;
    final showNav = _tabs.any((tab) => loc == tab.path);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: showNav
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                if (index == _currentIndex) return;
                _currentIndex = index;
                context.go(_tabs[index].path);
              },
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.icon),
                    label: tab.label,
                  ),
              ],
            )
          : null,
    );
  }
}

class _NavTab {
  final String path;
  final IconData icon;
  final String label;

  const _NavTab(this.path, this.icon, this.label);
}