import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  double _strength = 0.0;
  String _strengthLabel = 'Too short';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_computeStrength);
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
    Provider.of<AuthService>(context, listen: false).clearErrorMessage();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    // Capture helpers before awaits
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final success = await authService.signUpWithEmailAndPassword(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
      _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      router.go('/dashboard/home');
    } else {
      final msg = Provider.of<AuthService>(context, listen: false).errorMessage ?? 'Registration failed. Please try again.';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 100, width: 100),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join our community!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // Registration Form Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            validator: (value) => value!.isEmpty
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Enter your email';
                              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              return emailRegex.hasMatch(v) ? null : 'Enter a valid email';
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              final v = value?.trim() ?? '';
                              if (v.isEmpty) return 'Please enter your phone number';
                              if (!RegExp(r'^[0-9+\-()\s]{7,}$').hasMatch(v)) return 'Enter a valid phone number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            obscureText: true,
                            validator: (value) {
                              final v = value ?? '';
                              if (v.length < 8) return 'Password must be at least 8 characters';
                              if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
                              if (!RegExp(r'[a-z]').hasMatch(v)) return 'Include at least one lowercase letter';
                              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
                              if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) return 'Include at least one special character';
                              return null;
                            },
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
                            controller: _confirmController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm Password',
                            ),
                            obscureText: true,
                            validator: (value) => value == _passwordController.text ? null : 'Passwords do not match',
                          ),
                          const SizedBox(height: 24),

                          // Error Message
                          if (authService.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(
                                authService.errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          // Submit Button
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _submit,
                                  child: const Text('Register'),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Login Link
                TextButton(
                  onPressed: () {
                    authService.clearErrorMessage();
                    context.go('/auth');
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
