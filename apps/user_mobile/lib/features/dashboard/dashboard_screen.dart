import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatefulWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? _lastBackPressedAt;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final selectedIndex = _calculateSelectedIndex(context);
    final String location = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.fullPath;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        final router = GoRouter.of(context);
        if (router.canPop()) {
          _lastBackPressedAt = null;
          router.pop();
          return;
        }

        // We are at a top-level dashboard route. If it's not Home, switch to Home
        // instead of minimizing the app.
        final location = router.routerDelegate.currentConfiguration.fullPath;
        final isHome =
            location.startsWith('/dashboard/home') ||
            location.startsWith('/dashboard/about');
        final isTopLevelDashboard = location.startsWith('/dashboard/');
        if (isTopLevelDashboard && !isHome) {
          _lastBackPressedAt = null;
          router.go('/dashboard/home');
          return; // handled back by switching to Home
        }

        // At true root (already on Home): require double-back to exit
        final now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Press back again to exit')),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Row(
          children: [
            if (!isMobile)
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) => _onItemTapped(index, context),
                labelType: NavigationRailLabelType.all,
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.house),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.fileInvoiceDollar),
                    label: Text('Tax'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.mapPin),
                    label: Text('Tracker'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.newspaper),
                    label: Text('News'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.circleExclamation),
                    label: Text('Complaints'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.calendarCheck),
                    label: Text('Booking'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(FontAwesomeIcons.user),
                    label: Text('Profile'),
                  ),
                ],
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (c, anim) =>
                    FadeTransition(opacity: anim, child: c),
                child: KeyedSubtree(
                  key: ValueKey(location),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: isMobile
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: _FrostedNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) => _onItemTapped(index, context),
                  items: const [
                    _NavItem(icon: FontAwesomeIcons.house, label: 'Home'),
                    _NavItem(
                      icon: FontAwesomeIcons.fileInvoiceDollar,
                      label: 'Tax',
                    ),
                    _NavItem(icon: FontAwesomeIcons.mapPin, label: 'Tracker'),
                    _NavItem(icon: FontAwesomeIcons.newspaper, label: 'News'),
                    _NavItem(
                      icon: FontAwesomeIcons.circleExclamation,
                      label: 'Complaints',
                    ),
                    _NavItem(
                      icon: FontAwesomeIcons.calendarCheck,
                      label: 'Booking',
                    ),
                    _NavItem(icon: FontAwesomeIcons.user, label: 'Profile'),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final GoRouter route = GoRouter.of(context);
    final String location = route.routerDelegate.currentConfiguration.fullPath;

    if (location.startsWith('/dashboard/home') ||
        location.startsWith('/dashboard/about')) {
      return 0;
    }
    if (location.startsWith('/dashboard/tax')) {
      return 1;
    }
    if (location.startsWith('/dashboard/tracker')) {
      return 2;
    }
    if (location.startsWith('/dashboard/news')) {
      return 3;
    }
    if (location.startsWith('/dashboard/complaints')) {
      return 4;
    }
    if (location.startsWith('/dashboard/bookings')) {
      return 5;
    }
    if (location.startsWith('/dashboard/profile')) {
      return 6;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard/home');
        break;
      case 1:
        context.go('/dashboard/tax');
        break;
      case 2:
        context.go('/dashboard/tracker');
        break;
      case 3:
        context.go('/dashboard/news');
        break;
      case 4:
        context.go('/dashboard/complaints');
        break;
      case 5:
        context.go('/dashboard/bookings');
        break;
      case 6:
        context.go('/dashboard/profile');
        break;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _FrostedNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _FrostedNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Tooltip(
                message: item.label,
                waitDuration: const Duration(milliseconds: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      item.icon,
                      size: 20,
                      color: selected ? primary : inactive,
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 4,
                      width: 22,
                      decoration: BoxDecoration(
                        color: selected ? primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
