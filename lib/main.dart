import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthService())],
      child: Builder(
        builder: (context) {
          final auth = Provider.of<AuthService>(context, listen: false);
          // Single router instance that auto-refreshes via refreshListenable
          final router = _createRouter(auth);
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
            builder: (context, state) => NewsDetailScreen(id: state.pathParameters['id']!),
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
