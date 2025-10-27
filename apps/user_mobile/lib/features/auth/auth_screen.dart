import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;

import '../../auth/auth_service.dart';
import '../../core/app_logo.dart';
import 'auth_flow_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final AuthFlowController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = ref.read(authFlowControllerProvider.notifier);
  }

  @override
  void dispose() {
    _flowController.reset();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(authFlowControllerProvider.notifier);
    controller.clearBanner();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await controller.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = legacy_provider.Provider.of<AuthService>(context);
    final flowState = ref.watch(authFlowControllerProvider);
    final flowController = _flowController;

    ref.listen<AuthFlowState>(authFlowControllerProvider, (previous, next) {
      final banner = next.banner;
      if (banner != null && banner.type == AuthBannerType.success) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(banner.message)));
        });
      }
    });

    if (!authService.isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth > 600
                  ? 48.0
                  : 24.0;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LoginFormCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          flowState: flowState,
                          onSubmit: _submit,
                          onPasswordReset: () => flowController
                              .sendPasswordReset(_emailController.text.trim()),
                          onGoogleSignIn: flowController.signInWithGoogle,
                          onClearBanner: flowController.clearBanner,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            flowController.reset();
                            context.go('/register');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          child: const Text('New to UPS? Create an account'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.flowState,
    required this.onSubmit,
    required this.onPasswordReset,
    required this.onGoogleSignIn,
    required this.onClearBanner,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AuthFlowState flowState;
  final VoidCallback onSubmit;
  final VoidCallback onPasswordReset;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onClearBanner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banner = flowState.banner;
    final isProcessing = flowState.isProcessing;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppLogo(size: 60, showTitle: true, title: 'UPS'),
              const SizedBox(height: 16),
              Text(
                'Sign in to continue',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use your registered email address to access the full dashboard.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => onClearBanner(),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Enter your email';
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  return emailRegex.hasMatch(v)
                      ? null
                      : 'Enter a valid email address';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                obscureText: true,
                onChanged: (_) => onClearBanner(),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isProcessing ? null : onPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: banner == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(banner.message + banner.type.name),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              (banner.type == AuthBannerType.error
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              banner.type == AuthBannerType.error
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              color: banner.type == AuthBannerType.error
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                banner.message,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: banner.type == AuthBannerType.error
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onClearBanner,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign in'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isProcessing ? null : onGoogleSignIn,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
