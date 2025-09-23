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
            Text('TrackWaste', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Version 1.0.0', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              'TrackWaste helps you manage waste pickups, pay taxes, and track services with ease. Built with Flutter.',
              style: theme.textTheme.bodyLarge,
            ),
            const Spacer(),
            Center(
              child: Text(
                '© ${DateTime.now().year} TrackWaste',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
