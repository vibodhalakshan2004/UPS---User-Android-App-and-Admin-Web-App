import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  final Widget child;

  const DashboardScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
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
                  icon: Icon(FontAwesomeIcons.calendarCheck),
                  label: Text('Bookings'),
                ),
                NavigationRailDestination(
                  icon: Icon(FontAwesomeIcons.user),
                  label: Text('Profile'),
                ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => _onItemTapped(index, context),
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.house),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.fileInvoiceDollar),
                  label: 'Tax',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.mapPin),
                  label: 'Tracker',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.calendarCheck),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.user),
                  label: 'Profile',
                ),
              ],
            )
          : null,
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final GoRouter route = GoRouter.of(context);
    final String location = route.routerDelegate.currentConfiguration.fullPath;

    if (location.startsWith('/dashboard/home')) {
      return 0;
    }
    if (location.startsWith('/dashboard/tax')) {
      return 1;
    }
    if (location.startsWith('/dashboard/tracker')) {
      return 2;
    }
    if (location.startsWith('/dashboard/bookings')) {
      return 3;
    }
    if (location.startsWith('/dashboard/profile')) {
      return 4;
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
        context.go('/dashboard/bookings');
        break;
      case 4:
        context.go('/dashboard/profile');
        break;
    }
  }
}
