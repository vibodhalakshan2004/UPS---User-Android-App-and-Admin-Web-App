import 'package:flutter/material.dart';

import '../../core/app_logo.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Logo
            Center(
              child: const AppLogo(size: 80, showTitle: true, title: 'UPS'),
            ),
            const SizedBox(height: 24),
            Text('UPS Super Services', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Version 1.0.0', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              'UPS brings municipal and community essentials into a single super app—pay taxes, reserve grounds or cemetery slots, follow news, and track water truck deliveries with one login.',
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            Center(
              child: Text(
                '© ${DateTime.now().year} UPS Citizen Services',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
