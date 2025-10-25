import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:provider/provider.dart' as legacy_provider;

import 'package:myapp/auth/auth_service.dart';
import 'package:myapp/features/auth/auth_flow_controller.dart';
import 'package:myapp/features/auth/auth_screen.dart';
import 'package:myapp/features/auth/registration_screen.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({this.ready = true});

  bool ready;

  @override
  User? get user => null;

  @override
  bool get isReady => ready;

  @override
  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    return const AuthResult.success();
  }

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    return const AuthResult.success();
  }

  @override
  Future<void> signOut() async {}
}

Widget _buildTestShell({required Widget child, FakeAuthService? authService}) {
  final service = authService ?? FakeAuthService();
  return ProviderScope(
    overrides: [authServiceProvider.overrideWith((ref) => service)],
    child: legacy_provider.ChangeNotifierProvider<AuthService>.value(
      value: service,
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth screen layouts', () {
    testGoldens('AuthScreen compact and wide layouts', (tester) async {
      const surfaceSize = Size(1280, 1700);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Auth compact',
          SizedBox(
            width: 360,
            height: 780,
            child: _buildTestShell(child: const AuthScreen()),
          ),
        )
        ..addScenario(
          'Auth wide',
          SizedBox(
            width: 1024,
            height: 720,
            child: _buildTestShell(child: const AuthScreen()),
          ),
        );

      await tester.pumpWidget(MaterialApp(home: builder.build()));
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'auth_screen_layouts');
    });

    testGoldens('Registration screen compact and wide layouts', (tester) async {
      const surfaceSize = Size(1280, 1800);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final builder = GoldenBuilder.column()
        ..addScenario(
          'Register compact',
          SizedBox(
            width: 360,
            height: 880,
            child: _buildTestShell(child: const RegistrationScreen()),
          ),
        )
        ..addScenario(
          'Register wide',
          SizedBox(
            width: 1120,
            height: 760,
            child: _buildTestShell(child: const RegistrationScreen()),
          ),
        );

      await tester.pumpWidget(MaterialApp(home: builder.build()));
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'registration_screen_layouts');
    });
  });
}
