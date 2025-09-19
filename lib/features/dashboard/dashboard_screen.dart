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
                  icon: Icon(FontAwesomeIcons.newspaper),
                  label: 'News',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.circleExclamation),
                  label: 'Complaints',
                ),
                BottomNavigationBarItem(
                  icon: Icon(FontAwesomeIcons.calendarCheck),
                  label: 'Booking',
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

    if (location.startsWith('/dashboard/home') || location.startsWith('/dashboard/about')) {
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
