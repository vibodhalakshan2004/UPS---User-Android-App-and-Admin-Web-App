import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

// ThemeProvider class to manage the theme state
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'TrackWaste',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router(authService),
          );
        },
      ),
    );
  }
}

GoRouter _router(AuthService authService) {
  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: authService,
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = authService.user != null;
      final bool loggingIn =
          state.matchedLocation == '/auth' ||
          state.matchedLocation == '/register';

      if (!loggedIn) {
        return loggingIn ? null : '/auth';
      }

      if (loggingIn) {
        return '/dashboard/home';
      }

      return null;
    },
    routes: <RouteBase>[
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
            path: '/dashboard/tax',
            builder: (context, state) => const TaxScreen(),
          ),
          GoRoute(
            path: '/dashboard/tracker',
            builder: (context, state) => const TrackerScreen(),
          ),
          GoRoute(
            path: '/dashboard/bookings',
            builder: (context, state) => const BookingScreen(),
          ),
          GoRoute(
            path: '/dashboard/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}
