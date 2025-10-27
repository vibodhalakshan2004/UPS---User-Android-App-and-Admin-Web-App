import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;

import '../../auth/auth_service.dart';
import '../../core/app_logo.dart';
import 'auth_flow_controller.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  double _strength = 0.0;
  String _strengthLabel = 'Too short';
  late final AuthFlowController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = ref.read(authFlowControllerProvider.notifier);
    _passwordController.addListener(_computeStrength);
  }

  @override
  void dispose() {
    _flowController.reset();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _computeStrength() {
    final p = _passwordController.text;
    double s = 0;
    if (p.length >= 8) s += 0.3;
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

  Future<void> _submit() async {
    final controller = ref.read(authFlowControllerProvider.notifier);
    controller.clearBanner();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await controller.register(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        _RegistrationFormCard(
                          formKey: _formKey,
                          nameController: _nameController,
                          emailController: _emailController,
                          phoneController: _phoneController,
                          passwordController: _passwordController,
                          confirmController: _confirmController,
                          flowState: flowState,
                          strength: _strength,
                          strengthLabel: _strengthLabel,
                          onSubmit: _submit,
                          onClearBanner: flowController.clearBanner,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            flowController.reset();
                            context.go('/auth');
                          },
                          child: const Text('Already have an account? Sign in'),
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

class _RegistrationFormCard extends StatelessWidget {
  const _RegistrationFormCard({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmController,
    required this.flowState,
    required this.strength,
    required this.strengthLabel,
    required this.onSubmit,
    required this.onClearBanner,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final AuthFlowState flowState;
  final double strength;
  final String strengthLabel;
  final VoidCallback onSubmit;
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
                'Create your profile',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us how to reach you. Your account keeps all municipal services in one place.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                onChanged: (_) => onClearBanner(),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
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
                  return emailRegex.hasMatch(v) ? null : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (_) => onClearBanner(),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!RegExp(r'^[0-9+\-()\s]{7,}$').hasMatch(v)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
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
                validator: (value) {
                  final v = value ?? '';
                  if (v.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(v)) {
                    return 'Include at least one uppercase letter';
                  }
                  if (!RegExp(r'[a-z]').hasMatch(v)) {
                    return 'Include at least one lowercase letter';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(v)) {
                    return 'Include at least one number';
                  }
                  if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) {
                    return 'Include at least one special character';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: strength,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      color: strength < 0.6
                          ? theme.colorScheme.error
                          : (strength < 0.8
                                ? theme.colorScheme.secondary
                                : Colors.green),
                      minHeight: 6,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(strengthLabel, style: theme.textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_person_rounded),
                ),
                obscureText: true,
                onChanged: (_) => onClearBanner(),
                validator: (value) => value == passwordController.text
                    ? null
                    : 'Passwords do not match',
              ),
              const SizedBox(height: 8),
              Text(
                'By continuing you agree to receive important municipal notifications and service updates.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
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
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Create account'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
