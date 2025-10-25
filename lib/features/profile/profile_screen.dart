import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_service.dart';

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
          onTap: () => context.go('/dashboard/profile/edit'),
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.solidBell,
          title: 'Notifications',
          onTap: () => context.go('/dashboard/profile/notifications'),
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.shieldHalved,
          title: 'Security',
          onTap: () => context.go('/dashboard/profile/security'),
        ),
        _buildMenuItem(
          context,
          icon: FontAwesomeIcons.circleInfo,
          title: 'About',
          onTap: () => context.go('/dashboard/about'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: const Text('Only light theme is available in this app.'),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            _nameCtrl.text = data?['displayName'] ?? user.displayName ?? '';
            _phoneCtrl.text = data?['phone'] ?? '';
            _emailCtrl.text = data?['email'] ?? user.email ?? '';
            _addressCtrl.text = data?['address'] ?? '';
            return Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter your email';
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      return emailRegex.hasMatch(v.trim())
                          ? null
                          : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      // Capture context-dependent objects before any awaits to avoid using
                      // BuildContext across async gaps.
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      String? error;
                      bool emailChangeInitiated = false;
                      try {
                        // Update auth email if changed
                        final newEmail = _emailCtrl.text.trim();
                        if (newEmail.isNotEmpty &&
                            newEmail != (user.email ?? '')) {
                          // In recent FlutterFire versions, updating email should go through verification
                          // to prevent account hijacking. This will send a verification link to the new email
                          // and only apply the change after the user confirms.
                          await user.verifyBeforeUpdateEmail(newEmail);
                          emailChangeInitiated = true;
                        }

                        // Optionally keep FirebaseAuth displayName in sync
                        if ((_nameCtrl.text.trim()).isNotEmpty &&
                            _nameCtrl.text.trim() != (user.displayName ?? '')) {
                          await user.updateDisplayName(_nameCtrl.text.trim());
                        }
                        // Update Firestore profile document. Do not write 'email' here; rules allow only display fields on self-update.
                        final updateData = <String, dynamic>{
                          'displayName': _nameCtrl.text.trim(),
                          'phone': _phoneCtrl.text.trim(),
                          'address': _addressCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update(updateData);
                      } on FirebaseAuthException catch (e) {
                        if (e.code == 'requires-recent-login') {
                          error =
                              'Please re-login and try updating your email again.';
                        } else if (e.code == 'email-already-in-use') {
                          error = 'That email is already in use.';
                        } else if (e.code == 'invalid-email') {
                          error = 'The email address is invalid.';
                        } else {
                          error = 'Failed to update profile (${e.code}).';
                        }
                      } catch (e) {
                        error = 'Failed to update profile.';
                      }
                      if (error != null) {
                        messenger.showSnackBar(SnackBar(content: Text(error)));
                        return;
                      }
                      if (emailChangeInitiated) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'We\'ve sent a verification link to ${_emailCtrl.text.trim()}. Your email will update after confirmation.',
                            ),
                          ),
                        );
                      }
                      navigator.pop();
                    },
                    child: const Text('Save Changes'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Account'),
                    onPressed: () async {
                      // Capture helpers prior to awaits
                      final messenger = ScaffoldMessenger.of(context);
                      final router = GoRouter.of(context);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Account?'),
                          content: const Text(
                            'This will permanently delete your account and profile data. This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;

                      try {
                        // Best-effort delete Firestore profile first
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .delete()
                            .catchError((_) {});

                        // Delete Firebase Auth user (may require recent login)
                        await user.delete();

                        // Navigate to auth screen
                        router.go('/auth');
                      } on FirebaseAuthException catch (e) {
                        String msg;
                        if (e.code == 'requires-recent-login') {
                          msg =
                              'Please re-login and try again to delete your account.';
                        } else {
                          msg = 'Failed to delete account (${e.code}).';
                        }
                        messenger.showSnackBar(SnackBar(content: Text(msg)));
                      } catch (e) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to delete account.'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  double _strength = 0.0;
  String _strengthLabel = 'Too short';

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_computeStrength);
  }

  void _computeStrength() {
    final p = _passwordCtrl.text;
    double s = 0;
    if (p.length >= 6) s += 0.3;
    if (RegExp(r'[A-Z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[a-z]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p)) s += 0.2;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p)) s += 0.1;
    s = s.clamp(0.0, 1.0);
    String label;
    if (s < 0.3) {
      label = 'Too short';
    } else if (s < 0.6) {
      label = 'Weak';
    } else if (s < 0.8) {
      label = 'Medium';
    } else {
      label = 'Strong';
    }
    setState(() {
      _strength = s;
      _strengthLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : 'Min 6 characters',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _strength,
                      backgroundColor: Colors.grey.shade300,
                      color: _strength < 0.6
                          ? Colors.red
                          : (_strength < 0.8 ? Colors.orange : Colors.green),
                      minHeight: 6,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_strengthLabel),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) =>
                    v == _passwordCtrl.text ? null : 'Passwords do not match',
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  // Capture context dependent helpers before awaiting
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  String? error;
                  try {
                    await auth.user?.updatePassword(_passwordCtrl.text);
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      error =
                          'Please re-login and try again to change your password.';
                    } else {
                      error = 'Failed to update password (${e.code}).';
                    }
                  } catch (e) {
                    error = 'Failed to update password.';
                  }
                  if (error != null) {
                    messenger.showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
                  navigator.pop();
                },
                child: const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool email = true;
  bool push = true;
  bool sms = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Email Notifications'),
            value: email,
            onChanged: (v) => setState(() => email = v),
          ),
          SwitchListTile(
            title: const Text('Push Notifications'),
            value: push,
            onChanged: (v) => setState(() => push = v),
          ),
          SwitchListTile(
            title: const Text('SMS Notifications'),
            value: sms,
            onChanged: (v) => setState(() => sms = v),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              // Persist preferences (Firestore or local storage) if needed
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save Preferences'),
          ),
        ],
      ),
    );
  }
}
