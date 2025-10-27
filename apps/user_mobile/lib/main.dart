import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'firebase_options.dart';

import 'core/theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/registration_screen.dart';
import 'features/booking/booking_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/tax/tax_screen.dart';
import 'features/tracker/tracker_screen.dart';
import 'auth/auth_service.dart';
import 'features/auth/auth_flow_controller.dart';
import 'features/home/about_screen.dart';
import 'features/news/news_screen.dart';
import 'features/news/news_detail_screen.dart';
import 'features/complaints/complaints_screen.dart';

// ThemeProvider is now defined in core/theme.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Ensure auth uses local persistence (explicit; mobile defaults to local)
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (_) {
    // Some platforms may not support changing persistence; ignore.
  }

  // Capture framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logClientError('flutter_error', details.exceptionAsString(), details.stack);
  };

  // Catch errors outside Flutter zones (e.g., platform/engine callbacks)
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logClientError('platform_error', error.toString(), stack);
    return true; // mark as handled to avoid default crash
  };

  // Guard all async errors too
  final authService = FirebaseAuthService();

  runZonedGuarded(
    () {
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
      runApp(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => authService),
          ],
          child: MyApp(authService: authService),
        ),
      );
    },
    (Object error, StackTrace stack) {
      _logClientError('zone_error', error.toString(), stack);
    },
  );
}

Future<void> _logClientError(String type, String message, StackTrace? stack) async {
  // Best-effort, never throw. Rate-limit by sampling to avoid write floods.
  try {
    // Only attempt if signed in, to honor Firestore rules
    if (FirebaseAuth.instance.currentUser == null) return;
    // Simple 1-in-4 sampling
    if (DateTime.now().millisecond % 4 != 0) return;
    await FirebaseFirestore.instance.collection('client_logs').add({
      'type': type,
      'message': message,
      'stack': stack?.toString(),
      'ts': FieldValue.serverTimestamp(),
      'platform': 'android',
    });
  } catch (_) {
    // ignore logging failures
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Log only meaningful transitions and only if signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Best-effort, sampled
    try {
      if (DateTime.now().microsecond % 3 != 0) return;
      FirebaseFirestore.instance.collection('client_logs').add({
        'type': 'lifecycle',
        'message': 'state=${state.name}',
        'stack': null,
        'ts': FieldValue.serverTimestamp(),
        'platform': 'android',
      });
    } catch (_) {}
  }
}

class MyApp extends StatelessWidget {
  const MyApp({required this.authService, super.key});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return legacy_provider.MultiProvider(
      providers: [
        legacy_provider.ChangeNotifierProvider<AuthService>.value(
          value: authService,
        ),
      ],
      child: Builder(
        builder: (context) {
          final router = _createRouter(authService);
          return MaterialApp.router(
            title: 'UPS',
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

GoRouter _createRouter(AuthService authService) {
  return GoRouter(
    refreshListenable: authService,
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final bool ready = authService.isReady;
      final bool loggedIn = authService.user != null;
      final String loc = state.matchedLocation;
      final bool isSplash = loc == '/';
      final bool isAuth = loc == '/auth';
      final bool isRegister = loc == '/register';
      final bool isAuthFlow = isAuth || isRegister;

      if (!ready) {
        // Stay on splash until Firebase restores session
        return isSplash ? null : '/';
      }

      if (!loggedIn) {
        // Allow navigating between /auth and /register when logged out
        return isAuthFlow ? null : '/auth';
      }

      // Logged in
      if (isAuthFlow || isSplash) {
        return '/dashboard/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const _SplashScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => DashboardScreen(child: child),
        routes: [
          GoRoute(
            path: '/dashboard/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/dashboard/about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: '/dashboard/tax',
            builder: (context, state) => const TaxScreen(),
          ),
          GoRoute(
            path: '/dashboard/tracker',
            builder: (context, state) => const TrackerScreen(),
          ),
          GoRoute(
            path: '/dashboard/news',
            builder: (context, state) => const NewsScreen(),
          ),
          GoRoute(
            path: '/dashboard/news/:id',
            builder: (context, state) =>
                NewsDetailScreen(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/dashboard/complaints',
            builder: (context, state) => const ComplaintsScreen(),
          ),
          GoRoute(
            path: '/dashboard/bookings',
            builder: (context, state) => const BookingScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/security',
            builder: (context, state) => const SecurityScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
