import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Sign-in failed.');
    } catch (_) {
      setState(() => _error = 'Sign-in failed.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 960;
          final messenger = ScaffoldMessenger.of(context);

          void handleForgotPassword() {
            setState(() => _error = null);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Please contact your system administrator to reset admin credentials.'),
              ),
            );
          }

          final card = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 16,
              color: theme.colorScheme.surface.withValues(alpha: 0.95),
              shadowColor: Colors.black.withValues(alpha: 0.18),
              surfaceTintColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 38, 34, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 30,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UPS Admin',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Municipal control centre',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Sign in',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Access bookings, complaints, and live tracker tools with your admin credentials.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Work email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Minimum 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: error == null
                            ? const SizedBox(height: 0)
                            : Container(
                                key: ValueKey(error),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: theme.colorScheme.error),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Access console'),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: _loading ? null : handleForgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          return Stack(
            children: [
              const _LoginBackdrop(),
              Positioned(
                top: 24,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.apartment, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Udubaddawa PS',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Flex(
                        direction: wide ? Axis.horizontal : Axis.vertical,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide) ...[const Expanded(child: _LoginHeroPanel()), const SizedBox(width: 32)],
                          Flexible(
                            flex: wide ? 0 : 1,
                            child: card,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298), Color(0xFF4E8DF5)],
        ),
      ),
      child: Stack(
        children: const [
          _GlowCircle(top: -160, right: -90, size: 280),
          _GlowCircle(bottom: -200, left: -120, size: 360),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({this.top, this.left, this.right, this.bottom, required this.size});

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x55FFFFFF), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.9),
            theme.colorScheme.secondary,
          ],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 42, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _LoginHeroBadge(icon: Icons.bolt_rounded, label: 'Real-time municipal operations'),
          SizedBox(height: 36),
          Text(
            'Coordinate bookings,\nresolve complaints,\ntrack fleet status.',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 34,
              height: 1.2,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Unify every department with a single dashboard. Alerts, approvals, and field crews stay in sync.',
            style: TextStyle(
              color: Color(0xFFEFF3FF),
              fontSize: 18,
              height: 1.5,
            ),
          ),
          SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LoginHeroBadge(icon: Icons.query_stats_outlined, label: 'Insights at a glance'),
              _LoginHeroBadge(icon: Icons.shield_outlined, label: 'Secure access only'),
              _LoginHeroBadge(icon: Icons.route_outlined, label: 'Live fleet visibility'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginHeroBadge extends StatelessWidget {
  const _LoginHeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
