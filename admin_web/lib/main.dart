import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'firebase_options.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  } catch (_) {}
  runApp(const MyApp());
}

class AuthService with ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  User? _user;
  bool _ready = false;
  AuthService() {
    _user = _auth.currentUser;
    _auth.idTokenChanges().listen((u) {
      _user = u;
      _ready = true;
      notifyListeners();
    });
    // Mark ready immediately to avoid indefinite splash if initial event is delayed
    if (!_ready) {
      _ready = true;
      // Schedule notify to avoid build during constructor
      scheduleMicrotask(() => notifyListeners());
    }
  }
  User? get user => _user;
  bool get isReady => _ready;
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class _NewsListItem extends StatelessWidget {
  const _NewsListItem({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = (data['title'] ?? 'Untitled announcement').toString();
    final summary = (data['summary'] ?? '').toString();
    final timestamp = data['publishedAt'] as Timestamp?;
    final publishedAt = timestamp?.toDate();
    final imageUrls = (data['imageUrls'] as List?) ?? const [];
    final pdfUrl = (data['pdfUrl'] as String?)?.isNotEmpty == true;
    final dateLabel = publishedAt != null
        ? DateFormat('d MMM y • h:mm a').format(publishedAt)
        : 'Draft';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (imageUrls.isNotEmpty)
                _InfoPill(
                  icon: Icons.collections_outlined,
                  label:
                      '${imageUrls.length} image${imageUrls.length == 1 ? '' : 's'}',
                ),
              if (pdfUrl)
                const _InfoPill(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF attachment',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/news/$id'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open details'),
              ),
              IconButton(
                tooltip: 'Copy share link',
                onPressed: () => _copyShareLink(context),
                icon: const Icon(Icons.link_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _copyShareLink(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    final uri = Uri(path: '/news/$id');
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    scaffold.showSnackBar(
      const SnackBar(content: Text('Share link copied to clipboard')),
    );
  }
}

class RolesService with ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final AuthService _authService;
  bool _isAdmin = false;
  bool _loaded = false;

  RolesService(this._authService) {
    // Listen to auth changes and fetch roles doc for current user
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  bool get isAdmin => _isAdmin;
  bool get loaded => _loaded;

  Future<void> _onAuthChanged() async {
    final user = _authService.user;
    if (user == null) {
      _isAdmin = false;
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      // Prefer Firebase custom claims for admin, optionally fall back to roles collection.
      // This provides stronger, token-bound admin status validated by backend rules.
      final token = await user.getIdTokenResult(true);
      final claimAdmin = (token.claims?['admin'] == true);
      bool docAdmin = false;
      try {
        final doc = await _db.collection('roles').doc(user.uid).get();
        docAdmin = (doc.data()?['admin'] == true);
      } catch (_) {
        docAdmin = false;
      }
      _isAdmin = claimAdmin || docAdmin;
    } catch (_) {
      _isAdmin = false;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, RolesService>(
          create: (context) => RolesService(context.read<AuthService>()),
          update: (context, auth, previous) => previous ?? RolesService(auth),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          final roles = context.watch<RolesService>();
          final router = _router(auth, roles);
          final app = MaterialApp.router(
            title: 'UPS Admin Panel',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            routerConfig: router,
          );
          // Wrap with SecurityOverlay only when logged in to enable inactivity auto-lock
          if (auth.user != null) {
            return SecurityOverlay(child: app);
          }
          return app;
        },
      ),
    );
  }
}

GoRouter _router(AuthService auth, RolesService roles) => GoRouter(
  // Refresh when either auth or roles state changes to re-evaluate redirects
  refreshListenable: Listenable.merge([auth, roles]),
  initialLocation: '/login',
  redirect: (context, state) {
    // Wait for auth ready: do not redirect to avoid loops/blank screen
    if (!auth.isReady) return null;
    final loggedIn = auth.user != null;
    if (!loggedIn && state.matchedLocation != '/login') return '/login';
    // If logged in, ensure role is loaded before routing to protected pages
    final protected = {
      '/dashboard',
      '/bookings',
      '/complaints',
      '/news',
      '/users',
      '/tracker',
    };
    if (loggedIn && protected.contains(state.matchedLocation)) {
      if (!roles.loaded) return null; // stay until roles load
      if (!roles.isAdmin) return '/not-authorized';
    }
    if (loggedIn &&
        (state.matchedLocation == '/' || state.matchedLocation == '/login')) {
      if (!roles.loaded) return null; // wait roles
      return roles.isAdmin ? '/dashboard' : '/not-authorized';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const _Splash()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    // Optional verify route if you decide to enforce email verification
    // GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/not-authorized',
      builder: (context, state) => const NotAuthorizedScreen(),
    ),
    GoRoute(
      path: '/bookings',
      builder: (context, state) => const BookingsAdminScreen(),
    ),
    GoRoute(
      path: '/complaints',
      builder: (context, state) => const ComplaintsAdminScreen(),
    ),
    GoRoute(
      path: '/news',
      builder: (context, state) => const NewsAdminScreen(),
    ),
    GoRoute(
      path: '/news/:id',
      builder: (context, state) =>
          NewsDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const UsersAdminScreen(),
    ),
    GoRoute(
      path: '/tracker',
      builder: (context, state) => const AdminTrackerScreen(),
    ),
  ],
);

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class NotAuthorizedScreen extends StatelessWidget {
  const NotAuthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: _AdminGradientBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 18,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Administrator access required',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You are signed in but your account lacks administrative privileges. Please contact your system administrator.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () async {
                          final router = GoRouter.of(context);
                          await AuditLog.log('sign_out', {
                            'reason': 'not_authorized',
                          });
                          await FirebaseAuth.instance.signOut();
                          router.go('/login');
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Contact system administrator'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminScaffold extends StatelessWidget {
  const _AdminScaffold({
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const _Nav(),
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: _AdminAppBar(title: title, actions: actions),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AdminAppBar({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleSpacing: 24,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102A68), Color(0xFF1F4172)],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.apartment_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        const _UserBadge(),
        const SizedBox(width: 16),
        ...(actions ?? const []),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Admin user';
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            email,
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminGradientBackground extends StatelessWidget {
  const _AdminGradientBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F1B3F), Color(0xFF101A2D), Color(0xFFF4F6FB)],
          stops: [0, 0.38, 1],
        ),
      ),
      child: child,
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: 'Operations dashboard',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: () => context.go('/tracker'),
            icon: const Icon(Icons.map_rounded),
            label: const Text('Live tracker'),
          ),
        ),
      ],
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DashboardHero(),
                    const SizedBox(height: 28),
                    const _DashboardMetrics(),
                    const SizedBox(height: 24),
                    const _DashboardQuickLinks(),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 960;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(child: _RecentBookings()),
                              SizedBox(width: 20),
                              Expanded(child: _RecentComplaints()),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            _RecentBookings(),
                            SizedBox(height: 20),
                            _RecentComplaints(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.95),
            theme.colorScheme.secondary,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55273763),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Command centre',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Monitor bookings, resolve complaints, publish news, and keep field teams aligned in real time.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFE8EFFF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _DashboardHeroChip(
                icon: Icons.query_stats_rounded,
                label: 'Live municipal metrics',
              ),
              _DashboardHeroChip(
                icon: Icons.support_agent,
                label: 'Priority complaint queue',
              ),
              _DashboardHeroChip(
                icon: Icons.route_rounded,
                label: 'Real-time fleet tracker',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardHeroChip extends StatelessWidget {
  const _DashboardHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: const [
        _StatCard(
          title: 'Members',
          icon: Icons.people_alt_rounded,
          queryType: _StatQuery.users,
          route: '/users',
        ),
        _StatCard(
          title: 'Open Complaints',
          icon: Icons.support_agent_rounded,
          queryType: _StatQuery.complaintsOpen,
          route: '/complaints',
        ),
        _StatCard(
          title: 'Pending Bookings',
          icon: Icons.pending_actions_rounded,
          queryType: _StatQuery.bookingsPending,
          route: '/bookings',
        ),
        _StatCard(
          title: 'Published News',
          icon: Icons.newspaper_rounded,
          queryType: _StatQuery.news,
          route: '/news',
        ),
      ],
    );
  }
}

class _DashboardQuickLinks extends StatelessWidget {
  const _DashboardQuickLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: const [
        _DashboardQuickLink(
          title: 'Bookings',
          description:
              'Approve or reject pending service bookings from residents.',
          icon: Icons.calendar_month_rounded,
          route: '/bookings',
        ),
        _DashboardQuickLink(
          title: 'Complaints',
          description:
              'Track issues raised by residents and update their status.',
          icon: Icons.fact_check_rounded,
          route: '/complaints',
        ),
        _DashboardQuickLink(
          title: 'News & Alerts',
          description:
              'Publish community updates, tenders, and emergency alerts.',
          icon: Icons.campaign_rounded,
          route: '/news',
        ),
        _DashboardQuickLink(
          title: 'Admin Users',
          description:
              'Manage staff access and contact details across departments.',
          icon: Icons.supervisor_account_rounded,
          route: '/users',
        ),
        _DashboardQuickLink(
          title: 'Live Tracker',
          description: 'Monitor fleet movement and dispatch routes instantly.',
          icon: Icons.route_outlined,
          route: '/tracker',
        ),
      ],
    );
  }
}

class _DashboardQuickLink extends StatelessWidget {
  const _DashboardQuickLink({
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
  });

  final String title;
  final String description;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final router = GoRouter.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => router.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDataCard extends StatelessWidget {
  const _AdminDataCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.footer,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
            if (footer != null) ...[const SizedBox(height: 20), footer!],
          ],
        ),
      ),
    );
  }
}

class _AdminDataRow extends StatelessWidget {
  const _AdminDataRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _bookingStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status.toLowerCase()) {
    case 'approved':
    case 'confirmed':
      return Colors.teal;
    case 'completed':
      return scheme.primary;
    case 'rejected':
    case 'cancelled':
      return scheme.error;
    case 'pending':
    default:
      return scheme.secondary;
  }
}

Color _complaintStatusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status.toLowerCase()) {
    case 'resolved':
    case 'closed':
      return Colors.teal;
    case 'in_progress':
    case 'processing':
    case 'investigating':
      return scheme.primary;
    case 'rejected':
    case 'dismissed':
      return scheme.error;
    case 'open':
    default:
      return scheme.secondary;
  }
}

class _RecentBookings extends StatelessWidget {
  const _RecentBookings();

  String _formatSubtitle(Map<String, dynamic> data) {
    final bookingType = (data['bookingType'] ?? data['service'] ?? 'Service')
        .toString();
    final slot = (data['timeSlot'] ?? data['slot'] ?? '').toString();
    final date = data['bookingDate'];
    DateTime? dt;
    if (date is Timestamp) dt = date.toDate();
    final formattedDate = dt != null
        ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        : 'Scheduling pending';
    final parts = <String>[bookingType];
    if (slot.isNotEmpty) parts.add(slot);
    parts.add(formattedDate);
    return parts.join(' • ');
  }

  Widget _buildRow(BuildContext context, QueryDocumentSnapshot doc) {
    final data = (doc.data() ?? {}) as Map<String, dynamic>;
    final name = (data['name'] ?? data['fullName'] ?? 'Resident').toString();
    final status = (data['status'] ?? 'pending').toString();
    return _AdminDataRow(
      icon: Icons.event_available_outlined,
      title: name,
      subtitle: _formatSubtitle(data),
      trailing: _StatusBadge(
        label: status.toUpperCase(),
        color: _bookingStatusColor(context, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminDataCard(
      title: 'Recent bookings',
      subtitle: 'Latest service requests from residents',
      icon: Icons.calendar_month_rounded,
      footer: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => context.go('/bookings'),
          icon: const Icon(Icons.arrow_outward_rounded),
          label: const Text('Manage bookings'),
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('bookingDate', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Text(
              'No bookings recorded yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _buildRow(context, docs[i]),
                if (i != docs.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RecentComplaints extends StatelessWidget {
  const _RecentComplaints();

  String _formatSubtitle(Map<String, dynamic> data) {
    final category = (data['category'] ?? data['type'] ?? 'General').toString();
    final location = (data['location'] ?? data['address'] ?? '').toString();
    final createdAt = data['createdAt'];
    DateTime? dt;
    if (createdAt is Timestamp) dt = createdAt.toDate();
    final dateLabel = dt != null
        ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        : 'Date pending';
    final parts = <String>[category];
    if (location.isNotEmpty) parts.add(location);
    parts.add(dateLabel);
    return parts.join(' • ');
  }

  Widget _buildRow(BuildContext context, QueryDocumentSnapshot doc) {
    final data = (doc.data() ?? {}) as Map<String, dynamic>;
    final name = (data['name'] ?? data['reporterName'] ?? 'Resident')
        .toString();
    final status = (data['status'] ?? 'open').toString();
    return _AdminDataRow(
      icon: Icons.report_gmailerrorred_rounded,
      title: name,
      subtitle: _formatSubtitle(data),
      trailing: _StatusBadge(
        label: status.toUpperCase(),
        color: _complaintStatusColor(context, status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AdminDataCard(
      title: 'Recent complaints',
      subtitle: 'Community issues requiring action',
      icon: Icons.support_agent_rounded,
      footer: Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => context.go('/complaints'),
          icon: const Icon(Icons.arrow_outward_rounded),
          label: const Text('Review all complaints'),
        ),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Text(
              'No complaints have been logged yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }
          final docs = snapshot.data!.docs;
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _buildRow(context, docs[i]),
                if (i != docs.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _StatQuery { users, complaintsOpen, bookingsPending, news }

class _StatCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final _StatQuery queryType;
  final String? route;
  const _StatCard({
    required this.title,
    required this.icon,
    required this.queryType,
    this.route,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  Future<int>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<int> _load() async {
    final db = FirebaseFirestore.instance;
    switch (widget.queryType) {
      case _StatQuery.users:
        return (await db.collection('users').count().get()).count ?? 0;
      case _StatQuery.complaintsOpen:
        return (await db
                    .collection('complaints')
                    .where('status', isEqualTo: 'open')
                    .count()
                    .get())
                .count ??
            0;
      case _StatQuery.bookingsPending:
        return (await db
                    .collection('bookings')
                    .where('status', isEqualTo: 'pending')
                    .count()
                    .get())
                .count ??
            0;
      case _StatQuery.news:
        return (await db.collection('news').count().get()).count ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Widget buildValue() {
      return FutureBuilder<int>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          if (!snapshot.hasData) {
            return Text(
              '—',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            );
          }
          return Text(
            snapshot.data!.toString(),
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          );
        },
      );
    }

    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: widget.route == null ? null : () => context.go(widget.route!),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                buildValue(),
                if (widget.route != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View details',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav();

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final location = router.routeInformationProvider.value.uri.toString();
    final theme = Theme.of(context);
    final items = const [
      _NavEntry('/dashboard', 'Dashboard', Icons.space_dashboard_rounded),
      _NavEntry('/bookings', 'Bookings', Icons.event_available_rounded),
      _NavEntry('/complaints', 'Complaints', Icons.support_agent_rounded),
      _NavEntry('/news', 'News & alerts', Icons.campaign_rounded),
      _NavEntry('/users', 'Admin users', Icons.supervisor_account_rounded),
      _NavEntry('/tracker', 'Live tracker', Icons.route_rounded),
    ];

    Color tileColor(bool selected) => selected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Udubaddawa PS',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Administrative console',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected =
                      location == item.route ||
                      (location.startsWith(item.route) &&
                          item.route != '/dashboard');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      tileColor: tileColor(selected),
                      leading: Icon(
                        item.icon,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        item.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        if (!selected) {
                          router.go(item.route);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await AuditLog.log('sign_out', {
                        'reason': 'user_initiated',
                      });
                      await FirebaseAuth.instance.signOut();
                      router.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Need help? Call +94 11 234 5678',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  const _NavEntry(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Try to load project logo if present; fall back to a neutral icon (no Flutter favicon)
    return Image.asset(
      'assets/images/logo.png',
      width: 32,
      height: 32,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) =>
          const Icon(Icons.apartment, size: 28),
    );
  }
}

class AdminTrackerScreen extends StatefulWidget {
  const AdminTrackerScreen({super.key});

  @override
  State<AdminTrackerScreen> createState() => _AdminTrackerScreenState();
}

class _AdminTrackerScreenState extends State<AdminTrackerScreen> {
  static const ll.LatLng _center = ll.LatLng(7.45, 80.03); // Udubaddawa area
  final MapController _mapController = MapController();

  Stream<List<_AdminMapItem>> _itemsStream() {
    return FirebaseFirestore.instance
        .collection('vehicles')
        .snapshots()
        .map((s) => s.docs.map((d) => _AdminMapItem.fromDoc(d)).toList())
        .handleError((_) => <_AdminMapItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: 'Live fleet tracker',
      floatingActionButton: _TrackerActions(onChanged: () => setState(() {})),
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<_AdminMapItem>>(
            stream: _itemsStream(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <_AdminMapItem>[];
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1100;
                    final map = _TrackerMap(
                      controller: _mapController,
                      items: items,
                      onTapItem: _showVehiclePopup,
                    );
                    final mapCard = Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            blurRadius: 32,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: map,
                        ),
                      ),
                    );
                    final panel = SizedBox(
                      width: wide ? 420 : double.infinity,
                      child: _TrackerVehiclesPanel(
                        onChanged: () => setState(() {}),
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: mapCard),
                          const SizedBox(width: 24),
                          panel,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 420, child: mapCard),
                        const SizedBox(height: 20),
                        panel,
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showVehiclePopup(_AdminMapItem item) async {
    String fmt(DateTime? dt) {
      if (dt == null) return '—';
      final d = dt.toLocal();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text('Last updated: ${fmt(item.updatedAt)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Lat: ${item.lat?.toStringAsFixed(5) ?? '—'}  •  Lng: ${item.lng?.toStringAsFixed(5) ?? '—'}',
                ),
              ],
            ),
            if (item.speedKph != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.speed, size: 16),
                  const SizedBox(width: 6),
                  Text('Speed: ${item.speedKph!.toStringAsFixed(1)} km/h'),
                ],
              ),
            ],
            if (item.heading != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.navigation, size: 16),
                  const SizedBox(width: 6),
                  Text('Heading: ${item.heading!.toStringAsFixed(0)}°'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _AdminMarkerIcon extends StatelessWidget {
  final String label;
  final Color color;
  const _AdminMarkerIcon({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color.withAlpha(230),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.local_shipping,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AdminMapItem {
  final String id;
  final String name;
  final ll.LatLng position;
  final bool active;
  final DateTime? updatedAt;
  final double? lat;
  final double? lng;
  final double? speedKph;
  final double? heading;

  const _AdminMapItem({
    required this.id,
    required this.name,
    required this.position,
    required this.active,
    this.updatedAt,
    this.lat,
    this.lng,
    this.speedKph,
    this.heading,
  });

  factory _AdminMapItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final name = (data['name'] as String?) ?? 'Vehicle';
    final active = (data['active'] as bool?) ?? false;
    DateTime? updatedAt;
    final ts = data['updatedAt'];
    if (ts is Timestamp) updatedAt = ts.toDate();
    final speed = (data['speedKph'] as num?)?.toDouble();
    final head = (data['heading'] as num?)?.toDouble();
    return _AdminMapItem(
      id: doc.id,
      name: name,
      position: (lat != null && lng != null)
          ? ll.LatLng(lat, lng)
          : _AdminTrackerScreenState._center,
      active: active,
      updatedAt: updatedAt,
      lat: lat,
      lng: lng,
      speedKph: speed,
      heading: head,
    );
  }
}

class _TrackerLegend extends StatelessWidget {
  final List<_AdminMapItem> items;
  const _TrackerLegend({required this.items});

  bool _isRecent(DateTime? dt) {
    if (dt == null) return false;
    return DateTime.now().difference(dt).inMinutes <= 5;
  }

  @override
  Widget build(BuildContext context) {
    final trucks = items.length;
    final recent = items
        .where((e) => e.active && _isRecent(e.updatedAt))
        .length;
    final stale = trucks - recent;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _chip(Icons.local_shipping, Colors.green, '$recent Recent'),
          _chip(Icons.local_shipping, Colors.red, '$stale Stale'),
          _chip(Icons.directions_car, Colors.blueGrey, '$trucks Trucks'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, Color color, String label) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      label: Text(label),
    );
  }
}

class _TrackerActions extends StatelessWidget {
  final VoidCallback onChanged;
  const _TrackerActions({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'addVehicle',
      onPressed: () => _showVehicleDialog(context),
      icon: const Icon(Icons.local_shipping),
      label: const Text('Add Truck'),
    );
  }

  Future<void> _showVehicleDialog(
    BuildContext context, {
    String? id,
    Map<String, dynamic>? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    final lat = TextEditingController(
      text: (existing?['lat']?.toString()) ?? '',
    );
    final lng = TextEditingController(
      text: (existing?['lng']?.toString()) ?? '',
    );
    bool active = (existing?['active'] as bool?) ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(id == null ? 'Add Truck' : 'Edit Truck'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: lat,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lng,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Checkbox(
                    value: active,
                    onChanged: (v) {
                      active = v ?? true;
                      (c as Element).markNeedsBuild();
                    },
                  ),
                  const Text('Active'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final n = name.text.trim();
    final la = double.tryParse(lat.text.trim());
    final ln = double.tryParse(lng.text.trim());
    if (n.isEmpty || la == null || ln == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please provide a name, valid latitude and longitude.'),
        ),
      );
      return;
    }
    final data = {
      'name': n,
      'lat': la,
      'lng': ln,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final col = FirebaseFirestore.instance.collection('vehicles');
    try {
      if (id == null) {
        await col.add(data);
        await AuditLog.log('vehicle_create', data);
        if (!context.mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Truck added')));
      } else {
        await col.doc(id).update(data);
        await AuditLog.log('vehicle_update', {'id': id, ...data});
        if (!context.mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Truck updated')));
      }
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save truck: $e')),
      );
    }
  }
}

class _TrackerVehiclesPanel extends StatelessWidget {
  final VoidCallback onChanged;
  const _TrackerVehiclesPanel({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<RolesService>().isAdmin;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fleet vehicles',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage active trucks and their live telemetry.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add vehicle',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: isAdmin
                      ? () => _TrackerActions(
                          onChanged: onChanged,
                        )._showVehicleDialog(context)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 360,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('vehicles')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Failed to load trucks: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.toList();
                  docs.sort((a, b) {
                    DateTime? da;
                    DateTime? db;
                    final ta = a.data()['updatedAt'];
                    final tb = b.data()['updatedAt'];
                    if (ta is Timestamp) da = ta.toDate();
                    if (tb is Timestamp) db = tb.toDate();
                    if (da == null && db == null) return 0;
                    if (da == null) return 1;
                    if (db == null) return -1;
                    return db.compareTo(da);
                  });

                  int recent = 0;
                  bool isRecent(DateTime? dt) =>
                      dt != null &&
                      DateTime.now().difference(dt).inMinutes <= 5;
                  for (final d in docs) {
                    final ts = d.data()['updatedAt'];
                    final dt = ts is Timestamp ? ts.toDate() : null;
                    final active = (d.data()['active'] as bool?) ?? false;
                    if (active && isRecent(dt)) recent++;
                  }
                  final total = docs.length;
                  final stale = total - recent;

                  return Column(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _InfoPill(
                            icon: Icons.speed_rounded,
                            label: 'Active: $recent',
                          ),
                          _InfoPill(
                            icon: Icons.warning_amber_rounded,
                            label: 'Stale: $stale',
                          ),
                          _InfoPill(
                            icon: Icons.directions_car_filled_rounded,
                            label: 'Fleet: $total',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final vehicle = doc.data();
                            final active =
                                (vehicle['active'] as bool?) ?? false;
                            final lat = (vehicle['lat'] as num?)?.toDouble();
                            final lng = (vehicle['lng'] as num?)?.toDouble();
                            final ts = vehicle['updatedAt'];
                            final updatedAt = ts is Timestamp
                                ? ts.toDate()
                                : null;
                            final recentRow = active && isRecent(updatedAt);

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          (recentRow
                                                  ? Colors.green
                                                  : scheme.error)
                                              .withValues(alpha: 0.14),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      recentRow
                                          ? Icons.check_circle
                                          : Icons.timelapse,
                                      color: recentRow
                                          ? Colors.green
                                          : scheme.error,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicle['name']?.toString() ?? doc.id,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Lat: ${lat?.toStringAsFixed(5) ?? '—'}  •  Lng: ${lng?.toStringAsFixed(5) ?? '—'}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Updated ${_relativeTime(updatedAt)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Switch(
                                        value: active,
                                        onChanged: isAdmin
                                            ? (value) async {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    );
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('vehicles')
                                                      .doc(doc.id)
                                                      .update({
                                                        'active': value,
                                                      });
                                                  await AuditLog.log(
                                                    'vehicle_set_active',
                                                    {
                                                      'id': doc.id,
                                                      'active': value,
                                                    },
                                                  );
                                                  onChanged();
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Failed to update active flag: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            : null,
                                      ),
                                      const SizedBox(height: 8),
                                      if (isAdmin)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Edit vehicle',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              onPressed: () =>
                                                  _TrackerActions(
                                                    onChanged: onChanged,
                                                  )._showVehicleDialog(
                                                    context,
                                                    id: doc.id,
                                                    existing: vehicle,
                                                  ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete vehicle',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    );
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('vehicles')
                                                      .doc(doc.id)
                                                      .delete();
                                                  await AuditLog.log(
                                                    'vehicle_delete',
                                                    {'id': doc.id},
                                                  );
                                                  onChanged();
                                                  if (!context.mounted) return;
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Vehicle removed',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!context.mounted) return;
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Failed to delete vehicle: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

// removed _VehiclesList/_BinsList in favor of unified _TrackerVehiclesPanel

class _TrackerMap extends StatelessWidget {
  final MapController controller;
  final List<_AdminMapItem> items;
  final void Function(_AdminMapItem) onTapItem;
  const _TrackerMap({
    required this.controller,
    required this.items,
    required this.onTapItem,
  });

  bool _isRecent(DateTime? dt) {
    if (dt == null) return false;
    return DateTime.now().difference(dt).inMinutes <= 5;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: const MapOptions(
            initialCenter: _AdminTrackerScreenState._center,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'lk.gov.ups.admin',
              tileProvider: NetworkTileProvider(),
            ),
            RichAttributionWidget(
              attributions: const [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final it in items)
                  Marker(
                    width: 46,
                    height: 56,
                    point: it.position,
                    child: GestureDetector(
                      onTap: () => onTapItem(it),
                      child: _AdminMarkerIcon(
                        label: it.name,
                        color: (it.active && _isRecent(it.updatedAt))
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final z = controller.camera.zoom;
                    final c = controller.camera.center;
                    controller.move(c, z + 1);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final z = controller.camera.zoom;
                    final c = controller.camera.center;
                    controller.move(c, z - 1);
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Simple legend chips
              _TrackerLegend(items: items),
            ],
          ),
        ),
      ],
    );
  }
}

class BookingsAdminScreen extends StatelessWidget {
  const BookingsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: 'Bookings console',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createManualBooking(context),
        icon: const Icon(Icons.add),
        label: const Text('Add booking'),
      ),
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .orderBy('bookingDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load bookings: ${snapshot.error}'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              const listPadding = EdgeInsets.fromLTRB(24, 120, 24, 32);
              if (docs.isEmpty) {
                return ListView(
                  padding: listPadding,
                  children: const [
                    _BookingReportPanel(),
                    SizedBox(height: 24),
                    _BookingsEmptyState(),
                  ],
                );
              }
              return ListView.separated(
                padding: listPadding,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 18),
                itemCount: docs.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return const _BookingReportPanel();
                  }
                  final doc = docs[i - 1];
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  return _BookingAdminTile(
                    data: data,
                    onView: () => _viewBooking(context, id, data),
                    onApprove: () => _setStatus(id, 'approved'),
                    onReject: () => _setStatus(id, 'rejected'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _setStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('bookings').doc(id).update({
      'status': status,
    });
    await AuditLog.log('booking_status_update', {
      'bookingId': id,
      'status': status,
    });
  }

  Future<void> _createManualBooking(BuildContext context) async {
    final type = ValueNotifier<String>('ground');
    final assignToMember = ValueNotifier<bool>(false);
    final memberEmailCtrl = TextEditingController();
    DateTime? date;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String? groundTime; // free text
    String? cemeterySlot; // 12:00 PM, 2:00 PM, 4:00 PM
    String? deathCertUrl;
    String? deathCertName;
    Set<String> bookedSlots = {};
    bool dateBooked = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Add Booking (Admin)'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('Type:'),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<String>(
                      valueListenable: type,
                      builder: (context, v, _) {
                        return DropdownButton<String>(
                          value: v,
                          items: const [
                            DropdownMenuItem(
                              value: 'ground',
                              child: Text('Ground'),
                            ),
                            DropdownMenuItem(
                              value: 'cemetery',
                              child: Text('Cemetery'),
                            ),
                          ],
                          onChanged: (nv) {
                            type.value = nv ?? 'ground';
                            (c as Element).markNeedsBuild();
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: assignToMember,
                      builder: (context, v, _) => Checkbox(
                        value: v,
                        onChanged: (nv) {
                          assignToMember.value = nv ?? false;
                          (c as Element).markNeedsBuild();
                        },
                      ),
                    ),
                    const Text('Assign to existing member'),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: assignToMember,
                  builder: (context, v, _) => v
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TextField(
                            controller: memberEmailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Member email',
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        date == null
                            ? 'Date: not set'
                            : 'Date: ${date!.toLocal()}'.split(' ')[0],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: c,
                          initialDate: now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 2),
                        );
                        if (picked != null) {
                          date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                          );
                          // fetch approved bookings for this date to calculate slot availability
                          final qs = await FirebaseFirestore.instance
                              .collection('bookings')
                              .where(
                                'bookingDate',
                                isEqualTo: Timestamp.fromDate(date!),
                              )
                              .get();
                          final approved = qs.docs.where(
                            (d) =>
                                (d.data()['status'] as String?) == 'approved',
                          );
                          dateBooked = approved.isNotEmpty;
                          final Set<String> slots = {};
                          final regex = RegExp(
                            r'Time:\s*([0-9: ]+(AM|PM))',
                            caseSensitive: false,
                          );
                          for (final d in approved) {
                            final reason =
                                (d.data()['bookingReason'] as String?) ?? '';
                            final m = regex.firstMatch(reason);
                            if (m != null) {
                              slots.add(m.group(1)!.toUpperCase().trim());
                            }
                          }
                          bookedSlots = slots;
                          (c as Element).markNeedsBuild();
                        }
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
                if (type.value == 'cemetery') ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Time Slot',
                      style: Theme.of(c).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in const ['12:00 PM', '2:00 PM', '4:00 PM'])
                        ChoiceChip(
                          label: Text(
                            (dateBooked || bookedSlots.contains(s))
                                ? '$s (Booked)'
                                : s,
                          ),
                          selected: cemeterySlot == s,
                          onSelected: (sel) {
                            if (dateBooked || bookedSlots.contains(s)) return;
                            cemeterySlot = sel ? s : null;
                            (c as Element).markNeedsBuild();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          deathCertName == null
                              ? 'Death Certificate: none'
                              : 'Attached: $deathCertName',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: const [
                              'pdf',
                              'png',
                              'jpg',
                              'jpeg',
                            ],
                          );
                          if (res == null || res.files.isEmpty) return;
                          final f = res.files.single;
                          if (f.bytes == null) return;
                          try {
                            final storageRef = FirebaseStorage.instance.ref().child(
                              'death_certificates/${DateTime.now().millisecondsSinceEpoch}_${f.name}',
                            );
                            final meta = SettableMetadata(
                              contentType: (f.extension == 'pdf')
                                  ? 'application/pdf'
                                  : 'image/${f.extension}',
                            );
                            await storageRef.putData(f.bytes!, meta);
                            deathCertUrl = await storageRef.getDownloadURL();
                            deathCertName = f.name;
                            (c as Element).markNeedsBuild();
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          deathCertUrl == null ? 'Attach file' : 'Re-attach',
                        ),
                      ),
                    ],
                  ),
                ],
                if (type.value == 'ground') ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Preferred Time (e.g., 3:30 PM)',
                    ),
                    onChanged: (v) => groundTime = v,
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Visitor name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Visitor phone'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (date == null) return;
                if (type.value == 'cemetery' && cemeterySlot == null) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('Please select a time slot')),
                  );
                  return;
                }
                final user = FirebaseAuth.instance.currentUser;
                final data = <String, dynamic>{
                  'bookingType': type.value,
                  'bookingDate': Timestamp.fromDate(
                    DateTime(date!.year, date!.month, date!.day),
                  ),
                  'status': 'approved',
                  'createdAt': FieldValue.serverTimestamp(),
                  'createdBy': user?.uid,
                  'source': 'admin_manual',
                  'visitorName': nameCtrl.text.trim(),
                  'visitorPhone': phoneCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                };
                // Compose booking reason and include time info
                var r = reasonCtrl.text.trim();
                final timeText = type.value == 'cemetery'
                    ? cemeterySlot
                    : groundTime;
                if (timeText != null && timeText.trim().isNotEmpty) {
                  r = r.isEmpty
                      ? 'Time: ${timeText.trim()}'
                      : '$r | Time: ${timeText.trim()}';
                }
                if (r.isNotEmpty) data['bookingReason'] = r;

                if (deathCertUrl != null) {
                  data['deathCertificateUrl'] = deathCertUrl;
                }
                if (deathCertName != null) {
                  data['deathCertificateName'] = deathCertName;
                }

                // Optionally assign to an existing user by email
                final email = memberEmailCtrl.text.trim();
                if (email.isNotEmpty) {
                  final q = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
                  if (q.docs.isNotEmpty) {
                    data['userId'] = q.docs.first.id;
                  }
                }
                final doc = await FirebaseFirestore.instance
                    .collection('bookings')
                    .add(data);
                await AuditLog.log('booking_created_manual', {
                  'id': doc.id,
                  ...data,
                });
                if (c.mounted) Navigator.of(c).pop(true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      // no-op
    }
  }

  Future<void> _viewBooking(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    String fmtDate(dynamic ts) {
      if (ts is Timestamp) {
        return ts.toDate().toLocal().toString().split(' ')[0];
      }
      if (ts is DateTime) return ts.toLocal().toString().split(' ')[0];
      return ts?.toString() ?? '';
    }

    Future<void> copy(String label, String? value) async {
      if (value == null || value.isEmpty) return;
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label copied')));
    }

    final rows = <Widget>[];
    void addRow(
      String label,
      String? value, {
      bool multiline = false,
      bool copyable = true,
    }) {
      rows.add(
        ListTile(
          title: Text(label),
          subtitle: multiline ? SelectableText(value ?? '') : Text(value ?? ''),
          trailing: copyable && (value != null && value.isNotEmpty)
              ? IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy),
                  onPressed: () => copy(label, value),
                )
              : null,
        ),
      );
    }

    addRow('Booking ID', id);
    addRow('Type', data['bookingType'] as String?);
    addRow('Date', fmtDate(data['bookingDate']));
    addRow('Status', data['status'] as String?);
    addRow('User ID', data['userId'] as String?);
    addRow('Visitor Name', data['visitorName'] as String?);
    addRow('Visitor Phone', data['visitorPhone'] as String?);
    addRow('Reason', data['bookingReason'] as String?, multiline: true);
    addRow('Notes', data['notes'] as String?, multiline: true);
    final dcName = data['deathCertificateName'] as String?;
    final dcUrl = data['deathCertificateUrl'] as String?;
    addRow('Death Certificate Name', dcName);
    addRow('Death Certificate URL', dcUrl, multiline: true);

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Booking Details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final json = {'id': id, ...data}.toString();
              await Clipboard.setData(ClipboardData(text: json));
              if (c.mounted) Navigator.of(c).pop();
            },
            child: const Text('Copy All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _BookingsEmptyState extends StatelessWidget {
  const _BookingsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy, size: 48, color: muted),
          const SizedBox(height: 16),
          Text(
            'No bookings have been submitted yet.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'As residents submit requests, they will appear here for review.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _BookingReportPanel extends StatefulWidget {
  const _BookingReportPanel();

  @override
  State<_BookingReportPanel> createState() => _BookingReportPanelState();
}

class _BookingReportPanelState extends State<_BookingReportPanel> {
  _ReportPeriod _period = _ReportPeriod.monthly;
  _ReportType _type = _ReportType.ground;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedYear = DateTime.now().year;
  bool _busy = false;
  String? _error;
  _ReportSummary? _summary;
  List<_ReportBooking> _cachedBookings = const [];
  String? _cachedKey;
  bool _hasCache = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    final periodSegments = <ButtonSegment<_ReportPeriod>>[
      const ButtonSegment(
        value: _ReportPeriod.monthly,
        label: Text('Monthly'),
        icon: Icon(Icons.calendar_view_month),
      ),
      const ButtonSegment(
        value: _ReportPeriod.yearly,
        label: Text('Yearly'),
        icon: Icon(Icons.calendar_today),
      ),
      const ButtonSegment(
        value: _ReportPeriod.full,
        label: Text('All time'),
        icon: Icon(Icons.all_inbox_outlined),
      ),
    ];
    final typeSegments = <ButtonSegment<_ReportType>>[
      const ButtonSegment(
        value: _ReportType.ground,
        label: Text('Ground'),
        icon: Icon(Icons.park_outlined),
      ),
      const ButtonSegment(
        value: _ReportType.cemetery,
        label: Text('Cemetery'),
        icon: Icon(Icons.church_outlined),
      ),
      const ButtonSegment(
        value: _ReportType.all,
        label: Text('All'),
        icon: Icon(Icons.layers_outlined),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.assessment_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookings reports',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Export monthly, yearly, or full-history reports with separate filters for ground and cemetery services.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_ReportPeriod>(
                  segments: periodSegments,
                  selected: <_ReportPeriod>{_period},
                  onSelectionChanged: _busy
                      ? null
                      : (selection) {
                          final next = selection.first;
                          if (next == _period) return;
                          setState(() {
                            _period = next;
                            _clearCachedData();
                          });
                        },
                ),
                if (_period == _ReportPeriod.monthly)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: Text(monthLabel),
                  ),
                if (_period == _ReportPeriod.yearly)
                  InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      labelText: 'Select year',
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        onChanged: _busy
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedYear = value;
                                  _clearCachedData();
                                });
                              },
                        items: _yearOptions()
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<_ReportType>(
              segments: typeSegments,
              selected: <_ReportType>{_type},
              onSelectionChanged: _busy
                  ? null
                  : (selection) {
                      final next = selection.first;
                      if (next == _type) return;
                      setState(() {
                        _type = next;
                        _clearCachedData();
                      });
                    },
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _previewReport,
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: const Text('Preview report'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download PDF'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
            if (_summary != null) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryChip(
                    icon: Icons.calendar_month,
                    label: _summary!.rangeLabel,
                    color: colorScheme.primary,
                  ),
                  _SummaryChip(
                    icon: Icons.category_outlined,
                    label: _summary!.typeLabel,
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryStatCard(
                    label: 'Total bookings',
                    value: _summary!.total.toString(),
                    color: colorScheme.primary,
                    icon: Icons.event_note_outlined,
                  ),
                  _SummaryStatCard(
                    label: 'Approved',
                    value: _summary!.approved.toString(),
                    color: colorScheme.tertiary,
                    icon: Icons.check_circle_outline,
                  ),
                  _SummaryStatCard(
                    label: 'Pending',
                    value: _summary!.pending.toString(),
                    color: colorScheme.secondary,
                    icon: Icons.hourglass_bottom_outlined,
                  ),
                  _SummaryStatCard(
                    label: 'Rejected',
                    value: _summary!.rejected.toString(),
                    color: colorScheme.error,
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _previewReport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bookings = await _getBookings();
      if (!mounted) return;
      final summary = _buildSummary(bookings);
      setState(() {
        _summary = summary;
      });
      if (bookings.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bookings found for the selected filters.'),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Failed to load booking report: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Failed to load report. Please try again.';
          _summary = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bookings = await _getBookings();
      if (!mounted) return;
      final summary = _buildSummary(bookings);
      setState(() {
        _summary = summary;
      });
      if (bookings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No bookings found for the selected filters.'),
          ),
        );
        return;
      }
      final fileName = _buildFileName();
      await Printing.layoutPdf(
        name: fileName,
        format: PdfPageFormat.a4,
        onLayout: (format) async => _buildPdf(bookings, summary),
      );
    } catch (e, stack) {
      debugPrint('Failed to export booking PDF: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Failed to generate PDF. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 5, 1),
      lastDate: DateTime(now.year + 5, 12),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _clearCachedData();
      });
    }
  }

  Future<List<_ReportBooking>> _getBookings() async {
    final cacheKey = _currentCacheKey();
    if (_hasCache && _cachedKey == cacheKey) {
      return _cachedBookings;
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'bookings',
    );
    final (start, end) = _rangeBounds();

    if (_type != _ReportType.all) {
      final typeValue = _type == _ReportType.ground ? 'ground' : 'cemetery';
      query = query.where('bookingType', isEqualTo: typeValue);
    }
    if (start != null) {
      query = query.where(
        'bookingDate',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }
    if (end != null) {
      query = query.where('bookingDate', isLessThan: Timestamp.fromDate(end));
    }
    query = query.orderBy('bookingDate');

    final snapshot = await query.get();
    final bookings = snapshot.docs
        .map((doc) => _ReportBooking.fromFirestore(doc.id, doc.data()))
        .toList();
    _cachedBookings = bookings;
    _cachedKey = cacheKey;
    _hasCache = true;
    return bookings;
  }

  _ReportSummary _buildSummary(List<_ReportBooking> bookings) {
    final rangeLabel = _rangeLabel();
    final typeLabel = _typeLabel();
    var approved = 0;
    var pending = 0;
    var rejected = 0;
    for (final booking in bookings) {
      final status = booking.status.toLowerCase();
      if (status == 'approved') {
        approved++;
      } else if (status == 'rejected') {
        rejected++;
      } else {
        pending++;
      }
    }
    return _ReportSummary(
      total: bookings.length,
      approved: approved,
      pending: pending,
      rejected: rejected,
      rangeLabel: rangeLabel,
      typeLabel: typeLabel,
      generatedAt: DateTime.now(),
    );
  }

  (DateTime? start, DateTime? end) _rangeBounds() {
    switch (_period) {
      case _ReportPeriod.monthly:
        final start = DateTime(_selectedMonth.year, _selectedMonth.month);
        final end = DateTime(start.year, start.month + 1);
        return (start, end);
      case _ReportPeriod.yearly:
        final start = DateTime(_selectedYear, 1);
        final end = DateTime(_selectedYear + 1, 1);
        return (start, end);
      case _ReportPeriod.full:
        return (null, null);
    }
  }

  String _rangeLabel() {
    switch (_period) {
      case _ReportPeriod.monthly:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
      case _ReportPeriod.yearly:
        return 'Year $_selectedYear';
      case _ReportPeriod.full:
        return 'Full history';
    }
  }

  String _typeLabel() {
    switch (_type) {
      case _ReportType.ground:
        return 'Ground bookings';
      case _ReportType.cemetery:
        return 'Cemetery bookings';
      case _ReportType.all:
        return 'All booking types';
    }
  }

  String _buildFileName() {
    final typeSlug = switch (_type) {
      _ReportType.ground => 'ground',
      _ReportType.cemetery => 'cemetery',
      _ReportType.all => 'all',
    };
    final rangeSlug = switch (_period) {
      _ReportPeriod.monthly =>
        '${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}',
      _ReportPeriod.yearly => _selectedYear.toString(),
      _ReportPeriod.full => 'full-history',
    };
    return 'ups_bookings_${typeSlug}_$rangeSlug.pdf';
  }

  Future<Uint8List> _buildPdf(
    List<_ReportBooking> bookings,
    _ReportSummary summary,
  ) async {
    final pdf = pw.Document();
    final detailsTableData = bookings.map((booking) {
      return [
        _formatDate(booking.bookingDate),
        _titleCase(booking.type),
        booking.status.toUpperCase(),
        booking.visitorName.isNotEmpty ? booking.visitorName : '--',
        _truncate(booking.reason.isNotEmpty ? booking.reason : booking.notes),
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'UPS Bookings Report',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(summary.rangeLabel),
                pw.Text(summary.typeLabel),
                pw.Text(
                  'Generated ${DateFormat('d MMM y, h:mm a').format(summary.generatedAt)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 18),
              ],
            ),
            pw.Table.fromTextArray(
              headers: const ['Metric', 'Count'],
              data: [
                ['Total bookings', summary.total.toString()],
                ['Approved', summary.approved.toString()],
                ['Pending', summary.pending.toString()],
                ['Rejected', summary.rejected.toString()],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF444444),
              ),
              cellStyle: const pw.TextStyle(fontSize: 11),
              border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCCCCCC)),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFECEFF1),
              ),
            ),
            pw.SizedBox(height: 20),
            if (detailsTableData.isEmpty)
              pw.Text(
                'No bookings matched the selected filters.',
                style: const pw.TextStyle(fontSize: 12),
              )
            else ...[
              pw.Text(
                'Booking details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: const ['Date', 'Type', 'Status', 'Visitor', 'Notes'],
                data: detailsTableData,
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF444444),
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE0E0E0),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.1),
                  1: pw.FlexColumnWidth(1.1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(2.6),
                },
                border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCCCCCC)),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  void _clearCachedData() {
    _summary = null;
    _error = null;
    _cachedBookings = const [];
    _cachedKey = null;
    _hasCache = false;
  }

  String _currentCacheKey() {
    final buffer = StringBuffer()
      ..write(_period.name)
      ..write('|')
      ..write(_type.name);
    switch (_period) {
      case _ReportPeriod.monthly:
        buffer
          ..write('|')
          ..write(_selectedMonth.year)
          ..write('-')
          ..write(_selectedMonth.month);
        break;
      case _ReportPeriod.yearly:
        buffer
          ..write('|')
          ..write(_selectedYear);
        break;
      case _ReportPeriod.full:
        buffer.write('|all');
        break;
    }
    return buffer.toString();
  }

  List<int> _yearOptions() {
    final current = DateTime.now().year;
    return List<int>.generate(9, (index) => current + 4 - index);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _truncate(String value, [int max = 120]) {
    if (value.isEmpty) return '--';
    if (value.length <= max) return value;
    return '${value.substring(0, max - 3)}...';
  }
}

enum _ReportPeriod { monthly, yearly, full }

enum _ReportType { ground, cemetery, all }

class _ReportSummary {
  const _ReportSummary({
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.rangeLabel,
    required this.typeLabel,
    required this.generatedAt,
  });

  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final String rangeLabel;
  final String typeLabel;
  final DateTime generatedAt;
}

class _ReportBooking {
  _ReportBooking({
    required this.id,
    required this.type,
    required this.status,
    required this.bookingDate,
    required this.createdAt,
    required this.visitorName,
    required this.reason,
    required this.notes,
  });

  final String id;
  final String type;
  final String status;
  final DateTime? bookingDate;
  final DateTime? createdAt;
  final String visitorName;
  final String reason;
  final String notes;

  factory _ReportBooking.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    String sanitize(dynamic value) {
      if (value == null) return '';
      return value.toString().trim();
    }

    return _ReportBooking(
      id: id,
      type: sanitize(data['bookingType']).toLowerCase(),
      status: sanitize(data['status']).isEmpty
          ? 'pending'
          : sanitize(data['status']).toLowerCase(),
      bookingDate: toDate(data['bookingDate']),
      createdAt: toDate(data['createdAt']),
      visitorName: sanitize(data['visitorName']),
      reason: sanitize(data['bookingReason']),
      notes: sanitize(data['notes']),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  const _SummaryStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.16),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _BookingAdminTile extends StatelessWidget {
  const _BookingAdminTile({
    required this.data,
    required this.onView,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> data;
  final VoidCallback onView;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = (data['status'] ?? 'pending').toString();
    final type = (data['bookingType'] ?? 'Booking').toString();
    final bookingDate = (data['bookingDate'] as Timestamp?)?.toDate();
    final formattedDate = _formatDate(bookingDate);
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final assignedUser = (data['userId'] ?? data['memberEmail'] ?? 'Unassigned')
        .toString();
    final contact = (data['visitorPhone'] ?? data['phone'] ?? '').toString();
    final reason = (data['bookingReason'] ?? data['notes'] ?? '')
        .toString()
        .trim();
    final slot =
        (data['timeSlot'] ?? data['slot'] ?? data['preferredTime'] ?? '')
            .toString();
    final location = (data['location'] ?? data['address'] ?? '').toString();

    final isApproved = status.toLowerCase() == 'approved';
    final isRejected = status.toLowerCase() == 'rejected';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled for $formattedDate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  label: status.toUpperCase(),
                  color: _bookingStatusColor(context, status),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoPill(icon: Icons.person_outline, label: assignedUser),
                if (slot.isNotEmpty)
                  _InfoPill(icon: Icons.access_time, label: slot),
                if (location.isNotEmpty)
                  _InfoPill(icon: Icons.place_outlined, label: location),
                _InfoPill(
                  icon: Icons.schedule,
                  label: 'Logged ${_relativeTime(createdAt)}',
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                reason,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Contact: $contact',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: isRejected ? null : onReject,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: isApproved ? null : onApprove,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'date pending';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class ComplaintsAdminScreen extends StatefulWidget {
  const ComplaintsAdminScreen({super.key});

  @override
  State<ComplaintsAdminScreen> createState() => _ComplaintsAdminScreenState();
}

class _ComplaintsAdminScreenState extends State<ComplaintsAdminScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesStatus(String status) {
    final value = status.toLowerCase();
    switch (_statusFilter) {
      case 'open':
        return value == 'open' || value == 'pending' || value == 'new';
      case 'progress':
        return value.contains('progress') || value == 'assigned';
      case 'resolved':
        return value == 'fixed' || value == 'resolved' || value == 'closed';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _AdminScaffold(
      title: 'Complaints queue',
      extendBodyBehindAppBar: false,
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.support_agent_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage community issues',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Track reports as they move from open to resolved, and keep residents informed.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Live complaints queue',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Filter by status or search by subject, location, or reporter.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                _buildFilterChip('all', 'All'),
                                const SizedBox(width: 8),
                                _buildFilterChip('open', 'Open'),
                                const SizedBox(width: 8),
                                _buildFilterChip('progress', 'In progress'),
                                const SizedBox(width: 8),
                                _buildFilterChip('resolved', 'Resolved'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Search by keyword or reporter',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('complaints')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Unable to load complaints.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: colorScheme.error),
                                    ),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No complaints registered yet.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }
                                final docs = snapshot.data!.docs;
                                final openCount = docs.where((doc) {
                                  final status = (doc['status'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return status == 'open' ||
                                      status == 'pending' ||
                                      status == 'new';
                                }).length;
                                final resolvedCount = docs.where((doc) {
                                  final status = (doc['status'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return status == 'fixed' ||
                                      status == 'resolved' ||
                                      status == 'closed';
                                }).length;
                                final query = _query;
                                final filteredDocs = docs.where((doc) {
                                  final data =
                                      (doc.data() ?? {})
                                          as Map<String, dynamic>;
                                  final status = (data['status'] ?? '')
                                      .toString();
                                  if (!_matchesStatus(status)) return false;
                                  if (query.isEmpty) return true;
                                  final subject =
                                      (data['subject'] ?? data['title'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                  final reporter =
                                      (data['name'] ??
                                              data['reporterName'] ??
                                              '')
                                          .toString()
                                          .toLowerCase();
                                  final location =
                                      (data['location'] ??
                                              data['address'] ??
                                              '')
                                          .toString()
                                          .toLowerCase();
                                  final details = (data['details'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return subject.contains(query) ||
                                      reporter.contains(query) ||
                                      location.contains(query) ||
                                      details.contains(query);
                                }).toList();
                                if (filteredDocs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No complaints match your filters.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _InfoPill(
                                          icon: Icons.warning_amber_rounded,
                                          label: '$openCount open',
                                        ),
                                        _InfoPill(
                                          icon: Icons.verified_rounded,
                                          label: '$resolvedCount resolved',
                                        ),
                                        _InfoPill(
                                          icon: Icons.list_alt_rounded,
                                          label: '${filteredDocs.length} shown',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: filteredDocs.length,
                                        separatorBuilder: (context, _) =>
                                            const SizedBox(height: 16),
                                        itemBuilder: (context, index) {
                                          final doc = filteredDocs[index];
                                          final data =
                                              (doc.data() ?? {})
                                                  as Map<String, dynamic>;
                                          final id = doc.id;
                                          return _ComplaintAdminTile(
                                            data: data,
                                            onView: () => _viewComplaint(
                                              context,
                                              id,
                                              data,
                                            ),
                                            onMarkFixed: () =>
                                                _setComplaintStatus(
                                                  id,
                                                  'fixed',
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final theme = Theme.of(context);
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        if (!v) return;
        setState(() => _statusFilter = value);
      },
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<void> _setComplaintStatus(String id, String status) async {
    await FirebaseFirestore.instance.collection('complaints').doc(id).update({
      'status': status,
    });
    await AuditLog.log('complaint_status_update', {
      'complaintId': id,
      'status': status,
    });
  }

  Future<void> _viewComplaint(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    String fmtDate(dynamic ts) {
      if (ts is Timestamp) {
        return ts.toDate().toLocal().toString().split(' ')[0];
      }
      if (ts is DateTime) return ts.toLocal().toString().split(' ')[0];
      return ts?.toString() ?? '';
    }

    final type = (data['type'] as String?) ?? 'other';
    final lampNo = data['lampNumber']?.toString();
    final subject = (data['subject'] as String?) ?? '';
    final title = type == 'street_lamp'
        ? 'Street Lamp${lampNo == null || lampNo.isEmpty ? '' : ' #$lampNo'}'
        : subject;
    final details = (data['details'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'open';
    final createdAt = fmtDate(data['createdAt']);
    final photoUrl = data['photoUrl'] as String?;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Type: $type')),
                    Chip(label: Text('Status: $status')),
                    if (createdAt.isNotEmpty)
                      Chip(label: Text('Created: $createdAt')),
                  ],
                ),
                const SizedBox(height: 8),
                if (details.isNotEmpty) ...[
                  Text(
                    'Details',
                    style: Theme.of(c).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(details),
                  const SizedBox(height: 12),
                ],
                if (type == 'street_lamp' && lat != null && lng != null) ...[
                  Text(
                    'Location',
                    style: Theme.of(c).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: ll.LatLng(lat, lng),
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'lk.gov.ups.admin',
                          tileProvider: NetworkTileProvider(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40,
                              height: 40,
                              point: ll.LatLng(lat, lng),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (photoUrl != null) ...[
                  Text(
                    'Photo',
                    style: Theme.of(c).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(photoUrl);
                      await url_launcher.launchUrl(
                        uri,
                        mode: url_launcher.LaunchMode.externalApplication,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        photoUrl,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Close'),
          ),
          if (status != 'fixed')
            FilledButton.icon(
              onPressed: () async {
                await _setComplaintStatus(id, 'fixed');
                if (c.mounted) Navigator.of(c).pop();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark Fixed'),
            ),
        ],
      ),
    );
  }
}

class _ComplaintAdminTile extends StatelessWidget {
  const _ComplaintAdminTile({
    required this.data,
    required this.onView,
    required this.onMarkFixed,
  });

  final Map<String, dynamic> data;
  final VoidCallback onView;
  final VoidCallback onMarkFixed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = (data['status'] ?? 'open').toString();
    final type = (data['type'] ?? 'general').toString();
    final subject = (data['subject'] ?? 'Complaint').toString();
    final lampNo = data['lampNumber']?.toString();
    final title = type == 'street_lamp'
        ? 'Street lamp${lampNo == null || lampNo.isEmpty ? '' : ' #$lampNo'}'
        : subject;
    final details = (data['details'] ?? '').toString().trim();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final reporter = (data['name'] ?? data['reporterName'] ?? 'Resident')
        .toString();
    final contact = (data['phone'] ?? data['contact'] ?? '').toString();
    final location = (data['location'] ?? data['address'] ?? '').toString();
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();

    final statusColor = _complaintStatusColor(context, status);
    final resolved =
        status.toLowerCase() == 'fixed' || status.toLowerCase() == 'resolved';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    resolved
                        ? Icons.verified_user_rounded
                        : Icons.support_agent_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reported by $reporter',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(label: status.toUpperCase(), color: statusColor),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoPill(icon: Icons.category_outlined, label: type),
                if (createdAt != null)
                  _InfoPill(
                    icon: Icons.schedule,
                    label: _relativeTime(createdAt),
                  ),
                if (location.isNotEmpty)
                  _InfoPill(icon: Icons.place_outlined, label: location),
                if (lat != null && lng != null)
                  _InfoPill(
                    icon: Icons.map_outlined,
                    label:
                        'Lat ${lat.toStringAsFixed(3)}, Lng ${lng.toStringAsFixed(3)}',
                  ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            if (contact.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Contact: $contact',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: resolved ? null : onMarkFixed,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Mark fixed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}

class NewsAdminScreen extends StatefulWidget {
  const NewsAdminScreen({super.key});

  @override
  State<NewsAdminScreen> createState() => _NewsAdminScreenState();
}

class _NewsAdminScreenState extends State<NewsAdminScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  bool _posting = false;
  List<PlatformFile> _images = [];
  PlatformFile? _pdf;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    super.dispose();
  }

  String _guessContentType(String? ext) {
    final e = (ext ?? '').toLowerCase();
    switch (e) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _post() async {
    setState(() => _posting = true);
    try {
      final db = FirebaseFirestore.instance;
      final base = {
        'title': _title.text.trim(),
        'summary': _summary.text.trim(),
        'publishedAt': FieldValue.serverTimestamp(),
      };
      final docRef = db.collection('news').doc();
      await docRef.set(base);
      final storage = FirebaseStorage.instance;
      final List<String> imageUrls = [];
      for (final f in _images) {
        if (f.bytes == null) continue;
        final path =
            'news/${docRef.id}/images/${DateTime.now().millisecondsSinceEpoch}_${f.name}';
        final ref = storage.ref(path);
        final meta = SettableMetadata(
          contentType: _guessContentType(f.extension),
        );
        await ref.putData(f.bytes!, meta);
        imageUrls.add(await ref.getDownloadURL());
      }
      String? pdfUrl;
      if (_pdf?.bytes != null) {
        final p = _pdf!;
        final path =
            'news/${docRef.id}/files/${DateTime.now().millisecondsSinceEpoch}_${p.name}';
        final ref = storage.ref(path);
        final meta = SettableMetadata(contentType: 'application/pdf');
        await ref.putData(p.bytes!, meta);
        pdfUrl = await ref.getDownloadURL();
      }
      await docRef.update({
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (pdfUrl != null) 'pdfUrl': pdfUrl,
      });
      await AuditLog.log('news_posted', {'title': _title.text.trim()});
      _title.clear();
      _summary.clear();
      _images = [];
      _pdf = null;
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminScaffold(
      title: 'News & announcements',
      extendBodyBehindAppBar: false,
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildComposer(context),
                const SizedBox(height: 24),
                Expanded(child: _buildNewsList(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.campaign_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publish a new update',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share municipal news, tenders, or emergency alerts with residents.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Headline',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summary,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Summary',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _posting
                      ? null
                      : () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: ['png', 'jpg', 'jpeg'],
                          );
                          if (res != null) {
                            setState(() => _images = res.files);
                          }
                        },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    _images.isEmpty
                        ? 'Attach images'
                        : 'Images (${_images.length})',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _posting
                      ? null
                      : () async {
                          final res = await FilePicker.platform.pickFiles(
                            allowMultiple: false,
                            withData: true,
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (res != null && res.files.isNotEmpty) {
                            setState(() => _pdf = res.files.first);
                          }
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(_pdf?.name ?? 'Attach PDF'),
                ),
              ],
            ),
            if (_images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in _images)
                      Chip(
                        label: Text(file.name),
                        onDeleted: _posting
                            ? null
                            : () => setState(() => _images.remove(file)),
                      ),
                  ],
                ),
              ),
            if (_pdf != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Chip(
                  label: Text(_pdf!.name),
                  onDeleted: _posting
                      ? null
                      : () => setState(() => _pdf = null),
                ),
              ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _posting ? null : _post,
                icon: _posting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_posting ? 'Posting...' : 'Post update'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsList(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Published posts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('news')
                    .orderBy('publishedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No news posts yet. Publish the first update above.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final id = docs[index].id;
                      return _NewsListItem(id: id, data: data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  final String id;
  const NewsDetailScreen({super.key, required this.id});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [_Logo(), const SizedBox(width: 8), const Text('News')],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('news')
            .doc(id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = (data['title'] as String?) ?? 'Untitled';
          final summary = (data['summary'] as String?) ?? '';
          final date = (data['publishedAt'] as Timestamp?)?.toDate();
          final List imageUrls = (data['imageUrls'] as List?) ?? const [];
          final String? pdfUrl = data['pdfUrl'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${date.toLocal()}'.split(' ')[0],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(summary, style: theme.textTheme.bodyMedium),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final u in imageUrls)
                        GestureDetector(
                          onTap: () => _openUrl(u.toString()),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              u.toString(),
                              height: 140,
                              width: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (pdfUrl != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(pdfUrl),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Open PDF'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isAdmin(Map<String, dynamic> data) {
    final adminFlag = data['admin'] == true;
    final roles = data['roles'];
    final roleAdmin = roles is Map && roles['admin'] == true;
    return adminFlag || roleAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _AdminScaffold(
      title: 'Resident registry',
      extendBodyBehindAppBar: false,
      body: _AdminGradientBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.groups_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manage resident access',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Review contact details, update phone numbers, and manage admin permissions.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'All residents',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Search and edit resident profiles. Updates sync across the mobile experience immediately.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchCtrl,
                            onChanged: (value) => setState(
                              () => _query = value.trim().toLowerCase(),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Search by name, email, or phone',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Something went wrong loading users.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: colorScheme.error),
                                    ),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No residents found yet. New sign-ups will appear here automatically.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                final docs = snapshot.data!.docs;
                                final query = _query;
                                final filtered = query.isEmpty
                                    ? docs
                                    : docs.where((doc) {
                                        final data =
                                            (doc.data() ?? {})
                                                as Map<String, dynamic>;
                                        final name =
                                            (data['displayName'] ??
                                                    data['name'] ??
                                                    '')
                                                .toString()
                                                .toLowerCase();
                                        final email = (data['email'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                        final phone =
                                            (data['phone'] ??
                                                    data['phoneNumber'] ??
                                                    '')
                                                .toString()
                                                .toLowerCase();
                                        return name.contains(query) ||
                                            email.contains(query) ||
                                            phone.contains(query);
                                      }).toList();
                                if (filtered.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No residents match your search.',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (context, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final doc = filtered[index];
                                    final data =
                                        (doc.data() ?? {})
                                            as Map<String, dynamic>;
                                    final id = doc.id;
                                    return _UserAdminTile(
                                      data: data,
                                      isAdmin: _isAdmin(data),
                                      onEdit: () =>
                                          _editUser(context, id, data),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editUser(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameCtrl = TextEditingController(
      text: (data['displayName'] ?? data['name'] ?? '') as String,
    );
    final phoneCtrl = TextEditingController(
      text: (data['phone'] ?? data['phoneNumber'] ?? '') as String,
    );
    await showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.edit_note_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Edit resident details')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .update({
                      'displayName': name,
                      'name': name,
                      'phone': phone,
                      'phoneNumber': phone,
                    });
                await AuditLog.log('user_updated', {
                  'userId': id,
                  'name': name,
                  'phone': phone,
                });
                if (c.mounted) Navigator.of(c).pop();
              },
              child: const Text('Save changes'),
            ),
          ],
        );
      },
    );
  }
}

class _UserAdminTile extends StatelessWidget {
  const _UserAdminTile({
    required this.data,
    required this.isAdmin,
    required this.onEdit,
  });

  final Map<String, dynamic> data;
  final bool isAdmin;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = (data['displayName'] ?? data['name'] ?? 'Resident').toString();
    final email = (data['email'] ?? 'No email').toString();
    final phone = (data['phone'] ?? data['phoneNumber'] ?? 'No phone')
        .toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final lastActive = (data['lastActivityAt'] as Timestamp?)?.toDate();
    final initials = name.isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final createdLabel = createdAt != null
        ? DateFormat('d MMM y').format(createdAt)
        : 'Joined date unknown';
    final lastActiveLabel = lastActive != null
        ? 'Active ${DateFormat('d MMM y').format(lastActive)}'
        : 'No recent activity';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? email : name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isAdmin)
                      const _InfoPill(
                        icon: Icons.verified_user_rounded,
                        label: 'Admin',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _InfoPill(icon: Icons.mail_outline_rounded, label: email),
                    _InfoPill(icon: Icons.phone_rounded, label: phone),
                    _InfoPill(
                      icon: Icons.schedule_rounded,
                      label: createdLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lastActiveLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: 'Edit resident',
            child: IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

/// Writes admin action audit logs to Firestore.
class AuditLog {
  static Future<void> log(String action, Map<String, dynamic> details) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'action': action,
        'details': details,
        'uid': user?.uid,
        'email': user?.email,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Intentionally ignore log failures to not block UX
    }
  }
}

/// Wraps the app and locks the UI after a period of inactivity.
class SecurityOverlay extends StatefulWidget {
  final Widget child;
  final Duration idleTimeout;

  const SecurityOverlay({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 15),
  });

  @override
  State<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends State<SecurityOverlay> {
  Timer? _timer;
  bool _locked = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.idleTimeout, () {
      if (mounted) setState(() => _locked = true);
    });
  }

  void _onUserActivity() {
    if (_locked) return; // don't reset if already locked
    _startTimer();
  }

  Future<void> _unlock() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      // No user, just navigate to login by signing out
      await FirebaseAuth.instance.signOut();
      if (mounted) GoRouter.of(context).go('/login');
      return;
    }
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        return AlertDialog(
          title: const Text('Session Locked'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Re-enter password for ${user.email}'),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // allow sign out instead
                await AuditLog.log('sign_out', {'reason': 'locked_sign_out'});
                await FirebaseAuth.instance.signOut();
                if (c.mounted) Navigator.of(c).pop(false);
              },
              child: const Text('Sign out'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(c);
                try {
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passCtrl.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  if (c.mounted) Navigator.of(c).pop(true);
                } on FirebaseAuthException catch (e) {
                  if (!c.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Re-auth failed')),
                  );
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        );
      },
    );
    if (ok == true && mounted) {
      setState(() => _locked = false);
      _startTimer();
      await AuditLog.log('session_unlocked', {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _onUserActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _onUserActivity(),
        behavior: HitTestBehavior.deferToChild,
        child: widget.child,
      ),
    );
    if (!_locked) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.5),
          dismissible: false,
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 40),
                  const SizedBox(height: 8),
                  const Text('Session locked due to inactivity'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _unlock,
                    child: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
