import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.displayName ?? 'User'}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'about') {
                context.go('/dashboard/about');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('About')),
            ],
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rightFromBracket),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/auth');
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildDashboardGrid(context),
            const SizedBox(height: 24),
            Text(
              'Recent Activity',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: <Widget>[
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.fileInvoiceDollar,
          label: 'Pay Tax',
          onTap: () => context.go('/dashboard/tax'),
        ),
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.mapPin,
          label: 'Waste Tracker',
          onTap: () => context.go('/dashboard/tracker'),
        ),
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.newspaper,
          label: 'News',
          onTap: () => context.go('/dashboard/news'),
        ),
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.circleExclamation,
          label: 'Complaints',
          onTap: () => context.go('/dashboard/complaints'),
        ),
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.calendarCheck,
          label: 'Booking',
          onTap: () => context.go('/dashboard/bookings'),
        ),
        _buildDashboardCard(
          context,
          icon: FontAwesomeIcons.user,
          label: 'Profile',
          onTap: () => context.go('/dashboard/profile'),
        ),
      ],
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FaIcon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context) {
    // Replace with actual data later
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        _buildActivityItem(
          context,
          icon: FontAwesomeIcons.solidCreditCard,
          title: 'Tax Payment Successful',
          subtitle: 'Paid Rs. 50.00',
        ),
        _buildActivityItem(
          context,
          icon: FontAwesomeIcons.truck,
          title: 'Waste Pickup Completed',
          subtitle: 'Your waste has been collected',
        ),
        _buildActivityItem(
          context,
          icon: FontAwesomeIcons.solidCalendarCheck,
          title: 'Booking Confirmed',
          subtitle: 'Scheduled for tomorrow',
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: FaIcon(icon, color: theme.colorScheme.secondary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
