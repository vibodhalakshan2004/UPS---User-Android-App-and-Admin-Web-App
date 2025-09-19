import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_service.dart';
import '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.gear),
            onPressed: () => context.go('/dashboard/profile/settings'),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching data'));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('User profile not found'));
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: userData['photoURL'] != null
                            ? NetworkImage(userData['photoURL'])
                            : null,
                        child: userData['photoURL'] == null
                            ? const FaIcon(FontAwesomeIcons.user, size: 50)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userData['displayName'] ?? 'No Name',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userData['email'] ?? 'No Email',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),
                      _buildProfileMenu(context),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const FaIcon(
                          FontAwesomeIcons.rightFromBracket,
                          color: Colors.white,
                        ),
                        label: const Text('Sign Out'),
                        onPressed: () async {
                          await authService.signOut();
                          if (context.mounted) {
                            context.go('/auth');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.solidUser,
          title: 'Edit Profile',
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.solidBell,
          title: 'Notifications',
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.shieldHalved,
          title: 'Security',
          onTap: () {},
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.circleInfo,
          title: 'About',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: FaIcon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(title),
        trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.brightness_5),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.brightness_2),
                ),
              ],
              selected: <ThemeMode>{themeProvider.themeMode},
              onSelectionChanged: (Set<ThemeMode> newSelection) {
                if (newSelection.isNotEmpty) {
                  themeProvider.setThemeMode(newSelection.first);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
