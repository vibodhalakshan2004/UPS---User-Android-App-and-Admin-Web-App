import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'firebase_options.dart';
import 'core/theme.dart';

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Logo(),
            const SizedBox(width: 8),
            const Text('Admin Login'),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Logo(),
                        const SizedBox(width: 10),
                        Text(
                          'UPS Admin',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    if (_err != null)
                      Text(_err!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
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

class NotAuthorizedScreen extends StatelessWidget {
  const NotAuthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Logo(),
            const SizedBox(width: 8),
            const Text('Not authorized'),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your account is not authorized for admin access.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                final router = GoRouter.of(context);
                await AuditLog.log('sign_out', {'reason': 'not_authorized'});
                await FirebaseAuth.instance.signOut();
                router.go('/login');
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Logo(),
            const SizedBox(width: 8),
            const Text('UPS Admin'),
          ],
        ),
      ),
      drawer: const _Nav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.extent(
              maxCrossAxisExtent: 260,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: const [
                _StatCard(
                  title: 'Members',
                  icon: Icons.people,
                  queryType: _StatQuery.users,
                  route: '/users',
                ),
                _StatCard(
                  title: 'Open Complaints',
                  icon: Icons.report,
                  queryType: _StatQuery.complaintsOpen,
                  route: '/complaints',
                ),
                _StatCard(
                  title: 'Pending Bookings',
                  icon: Icons.pending_actions,
                  queryType: _StatQuery.bookingsPending,
                  route: '/bookings',
                ),
                _StatCard(
                  title: 'News Posts',
                  icon: Icons.newspaper,
                  queryType: _StatQuery.news,
                  route: '/news',
                ),
                _Tile('Bookings', '/bookings', Icons.calendar_month),
                _Tile('Complaints', '/complaints', Icons.report),
                _Tile('News', '/news', Icons.newspaper),
                _Tile('Users', '/users', Icons.people),
                _Tile('Tracker', '/tracker', Icons.map),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Expanded(child: _RecentBookings()),
                SizedBox(width: 12),
                Expanded(child: _RecentComplaints()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  const _RecentBookings();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Bookings',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .orderBy('bookingDate', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No recent bookings');
                return Column(
                  children: [
                    for (final d in docs)
                      ListTile(
                        dense: true,
                        title: Text(
                          ((d.data() as Map<String, dynamic>)['bookingType'] ??
                                  '')
                              .toString(),
                        ),
                        subtitle: Text(
                          ((d.data() as Map<String, dynamic>)['bookingDate']
                                  as Timestamp)
                              .toDate()
                              .toLocal()
                              .toString()
                              .split(' ')[0],
                        ),
                        trailing: Chip(
                          label: Text(
                            ((d.data() as Map<String, dynamic>)['status'] ?? '')
                                .toString(),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentComplaints extends StatelessWidget {
  const _RecentComplaints();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Complaints',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('No recent complaints');
                return Column(
                  children: [
                    for (final d in docs)
                      ListTile(
                        dense: true,
                        title: Text(
                          ((d.data() as Map<String, dynamic>)['subject'] ?? '')
                              .toString(),
                        ),
                        subtitle: Text(
                          ((d.data() as Map<String, dynamic>)['status'] ?? '')
                              .toString(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
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
    final color = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 26, color: color.secondary),
          const SizedBox(height: 6),
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FutureBuilder<int>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return Text(
                snapshot.data!.toString(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          if (widget.route != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(widget.route!),
              child: const Text('View details'),
            ),
          ],
        ],
      ),
    );
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: widget.route == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(widget.route!),
              child: content,
            ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Row(
              children: [
                _Logo(),
                const SizedBox(width: 12),
                const Text('UPS Admin'),
              ],
            ),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Dashboard'),
            onTap: () => context.go('/dashboard'),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Bookings'),
            onTap: () => context.go('/bookings'),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Complaints'),
            onTap: () => context.go('/complaints'),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('News'),
            onTap: () => context.go('/news'),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Users'),
            onTap: () => context.go('/users'),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Tracker'),
            onTap: () => context.go('/tracker'),
          ),
          const Divider(),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            title: const Text('Sign out'),
            onTap: () async {
              // Capture router before awaiting to avoid using context after await
              final router = GoRouter.of(context);
              await AuditLog.log('sign_out', {'reason': 'user_initiated'});
              await FirebaseAuth.instance.signOut();
              router.go('/login');
            },
          ),
        ],
      ),
    );
  }
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

class _Tile extends StatelessWidget {
  final String title;
  final String route;
  final IconData icon;

  const _Tile(this.title, this.route, this.icon);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color.secondary),
              const SizedBox(height: 6),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
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
    final vehicles = FirebaseFirestore.instance
        .collection('vehicles')
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => _AdminMapItem.fromDoc(d, isVehicle: true))
              .toList(),
        )
        .handleError((_) => <_AdminMapItem>[]);
    final bins = FirebaseFirestore.instance
        .collection('bins')
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => _AdminMapItem.fromDoc(d, isVehicle: false))
              .toList(),
        )
        .handleError((_) => <_AdminMapItem>[]);
    return vehicles
        .asyncMap((v) async {
          final b = await bins.first;
          final list = <_AdminMapItem>[]
            ..addAll(v)
            ..addAll(b);
          if (list.isEmpty) {
            return [
              _AdminMapItem(
                id: 'truck_demo',
                name: 'Waste Truck 1',
                position: const ll.LatLng(5.6237, -0.1970),
                isVehicle: true,
              ),
              _AdminMapItem(
                id: 'bin_demo',
                name: 'Community Bin',
                position: const ll.LatLng(5.6037, -0.1870),
                isVehicle: false,
              ),
            ];
          }
          return list;
        })
        .handleError(
          (_) => <_AdminMapItem>[
            _AdminMapItem(
              id: 'truck_demo',
              name: 'Waste Truck 1',
              position: const ll.LatLng(5.6237, -0.1970),
              isVehicle: true,
            ),
            _AdminMapItem(
              id: 'bin_demo',
              name: 'Community Bin',
              position: const ll.LatLng(5.6037, -0.1870),
              isVehicle: false,
            ),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [_Logo(), const SizedBox(width: 8), const Text('Tracker')],
        ),
      ),
      drawer: const _Nav(),
      floatingActionButton: _TrackerActions(onChanged: () => setState(() {})),
      body: StreamBuilder<List<_AdminMapItem>>(
        stream: _itemsStream(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <_AdminMapItem>[];
          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: _center,
                    initialZoom: 12,
                    // interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                            width: 44,
                            height: 44,
                            point: it.position,
                            child: _AdminMarkerIcon(
                              isVehicle: it.isVehicle,
                              label: it.name,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _TrackerLegend(items: items),
              const SizedBox(height: 8),
              // Zoom buttons overlay
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            final z = _mapController.camera.zoom;
                            final c = _mapController.camera.center;
                            _mapController.move(c, z + 1);
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
                            final z = _mapController.camera.zoom;
                            final c = _mapController.camera.center;
                            _mapController.move(c, z - 1);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _TrackerCrudPanel(onChanged: () => setState(() {})),
            ],
          );
        },
      ),
    );
  }
}

class _AdminMarkerIcon extends StatelessWidget {
  final bool isVehicle;
  final String label;
  const _AdminMarkerIcon({required this.isVehicle, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = isVehicle ? Colors.green : Colors.blue;
    final icon = isVehicle ? Icons.local_shipping : Icons.delete_outline;
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
          child: Icon(icon, color: Colors.white, size: 16),
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
  final bool isVehicle;

  const _AdminMapItem({
    required this.id,
    required this.name,
    required this.position,
    required this.isVehicle,
  });

  factory _AdminMapItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isVehicle,
  }) {
    final data = doc.data() ?? {};
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final name = (data['name'] as String?) ?? (isVehicle ? 'Vehicle' : 'Bin');
    return _AdminMapItem(
      id: doc.id,
      name: name,
      position: (lat != null && lng != null)
          ? ll.LatLng(lat, lng)
          : _AdminTrackerScreenState._center,
      isVehicle: isVehicle,
    );
  }
}

class _TrackerLegend extends StatelessWidget {
  final List<_AdminMapItem> items;
  const _TrackerLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    final trucks = items.where((e) => e.isVehicle).length;
    final bins = items.where((e) => !e.isVehicle).length;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _chip(Icons.local_shipping, Colors.green, '$trucks Active Trucks'),
          _chip(Icons.delete_outline, Colors.blue, '$bins Bins'),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'addVehicle',
          onPressed: () => _showVehicleDialog(context),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Add Truck'),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'addBin',
          onPressed: () => _showBinDialog(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Add Bin'),
        ),
      ],
    );
  }

  Future<void> _showVehicleDialog(BuildContext context, {String? id, Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name'] as String? ?? '');
    final lat = TextEditingController(text: (existing?['lat']?.toString()) ?? '');
    final lng = TextEditingController(text: (existing?['lng']?.toString()) ?? '');
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
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
              TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
              Row(children: [
                Checkbox(value: active, onChanged: (v){ active = v ?? true; (c as Element).markNeedsBuild(); }),
                const Text('Active')
              ])
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final data = {
      'name': name.text.trim(),
      'lat': double.tryParse(lat.text.trim()) ?? 0.0,
      'lng': double.tryParse(lng.text.trim()) ?? 0.0,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final col = FirebaseFirestore.instance.collection('vehicles');
    if (id == null) {
      await col.add(data);
      await AuditLog.log('vehicle_create', data);
    } else {
      await col.doc(id).update(data);
      await AuditLog.log('vehicle_update', {'id': id, ...data});
    }
    onChanged();
  }

  Future<void> _showBinDialog(BuildContext context, {String? id, Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: existing?['name'] as String? ?? '');
    final lat = TextEditingController(text: (existing?['lat']?.toString()) ?? '');
    final lng = TextEditingController(text: (existing?['lng']?.toString()) ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(id == null ? 'Add Bin' : 'Edit Bin'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: lat, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
              TextField(controller: lng, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      final data = {
        'name': name.text.trim(),
        'lat': double.tryParse(lat.text.trim()) ?? 0.0,
        'lng': double.tryParse(lng.text.trim()) ?? 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final col = FirebaseFirestore.instance.collection('bins');
      if (id == null) {
        await col.add(data);
        await AuditLog.log('bin_create', data);
      } else {
        await col.doc(id).update(data);
        await AuditLog.log('bin_update', {'id': id, ...data});
      }
      onChanged();
    }
  }
}

class _TrackerCrudPanel extends StatelessWidget {
  final VoidCallback onChanged;
  const _TrackerCrudPanel({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _VehiclesList(onChanged: onChanged)),
          const SizedBox(width: 12),
          Expanded(child: _BinsList(onChanged: onChanged)),
        ],
      ),
    );
  }
}

class _VehiclesList extends StatelessWidget {
  final VoidCallback onChanged;
  const _VehiclesList({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Trucks'),
            trailing: IconButton(
              tooltip: 'Add Truck',
              icon: const Icon(Icons.add),
              onPressed: () => _TrackerActions(onChanged: onChanged)._showVehicleDialog(context),
            ),
          ),
          SizedBox(
            height: 220,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No trucks added yet'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final active = (d['active'] as bool?) ?? false;
                    return ListTile(
                      dense: true,
                      title: Text(d['name']?.toString() ?? doc.id),
                      subtitle: Text('(${d['lat']}, ${d['lng']})'),
                      leading: Icon(active ? Icons.check_circle : Icons.radio_button_unchecked, color: active ? Colors.green : null),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _TrackerActions(onChanged: onChanged)._showVehicleDialog(context, id: doc.id, existing: d),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('vehicles').doc(doc.id).delete();
                              await AuditLog.log('vehicle_delete', {'id': doc.id});
                              onChanged();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BinsList extends StatelessWidget {
  final VoidCallback onChanged;
  const _BinsList({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Bins'),
            trailing: IconButton(
              tooltip: 'Add Bin',
              icon: const Icon(Icons.add),
              onPressed: () => _TrackerActions(onChanged: onChanged)._showBinDialog(context),
            ),
          ),
          SizedBox(
            height: 220,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('bins').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No bins added yet'));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    return ListTile(
                      dense: true,
                      title: Text(d['name']?.toString() ?? doc.id),
                      subtitle: Text('(${d['lat']}, ${d['lng']})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _TrackerActions(onChanged: onChanged)._showBinDialog(context, id: doc.id, existing: d),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('bins').doc(doc.id).delete();
                              await AuditLog.log('bin_delete', {'id': doc.id});
                              onChanged();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookingsAdminScreen extends StatelessWidget {
  const BookingsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [_Logo(), const SizedBox(width: 8), const Text('Bookings')],
        ),
      ),
      drawer: const _Nav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createManualBooking(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Booking'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .orderBy('bookingDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final status = (d['status'] as String?) ?? 'pending';
              final u = (d['userId'] as String?) ?? '';
              final type = (d['bookingType'] as String?) ?? '';
              final date = (d['bookingDate'] as Timestamp?)?.toDate();
              return Card(
                child: ListTile(
                  title: Text(
                    '$type • ${date != null ? '${date.toLocal()}'.split(' ')[0] : ''}',
                  ),
                  subtitle: Text('User: $u'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View details',
                        onPressed: () => _viewBooking(context, id, d),
                        icon: const Icon(Icons.visibility),
                      ),
                      Chip(label: Text(status)),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: status == 'approved'
                            ? null
                            : () => _setStatus(id, 'approved'),
                        icon: const Icon(Icons.check, color: Colors.green),
                      ),
                      IconButton(
                        onPressed: status == 'rejected'
                            ? null
                            : () => _setStatus(id, 'rejected'),
                        icon: const Icon(Icons.close, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
                            if (m != null)
                              slots.add(m.group(1)!.toUpperCase().trim());
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

                if (deathCertUrl != null)
                  data['deathCertificateUrl'] = deathCertUrl;
                if (deathCertName != null)
                  data['deathCertificateName'] = deathCertName;

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
      if (ts is Timestamp)
        return ts.toDate().toLocal().toString().split(' ')[0];
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

class ComplaintsAdminScreen extends StatelessWidget {
  const ComplaintsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _Logo(),
            const SizedBox(width: 8),
            const Text('Complaints'),
          ],
        ),
      ),
      drawer: const _Nav(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final subject = (d['subject'] as String?) ?? '';
              final details = (d['details'] as String?) ?? '';
              final status = (d['status'] as String?) ?? 'open';
              final type = (d['type'] as String?) ?? 'other';
              final lampNo = (d['lampNumber']?.toString());
              final title = type == 'street_lamp'
                  ? 'Street Lamp${lampNo == null || lampNo.isEmpty ? '' : ' #$lampNo'}'
                  : subject;
              // createdAt is available but not currently displayed
              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: details.isEmpty
                      ? (type == 'street_lamp' && d['lat'] != null && d['lng'] != null
                          ? Text('Location: (${d['lat']}, ${d['lng']})')
                          : const SizedBox.shrink())
                      : Text(details),
                  leading: Icon(
                    status == 'open' ? Icons.report : Icons.check_circle,
                    color: status == 'open' ? Colors.orange : Colors.green,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'View details',
                        onPressed: () => _viewComplaint(context, id, d),
                        icon: const Icon(Icons.visibility),
                      ),
                      Chip(label: Text(status)),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: status == 'fixed'
                            ? null
                            : () => _setComplaintStatus(id, 'fixed'),
                        child: const Text('Mark Fixed'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
      if (ts is Timestamp) return ts.toDate().toLocal().toString().split(' ')[0];
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
                    if (createdAt.isNotEmpty) Chip(label: Text('Created: $createdAt')),
                  ],
                ),
                const SizedBox(height: 8),
                if (details.isNotEmpty) ...[
                  Text('Details', style: Theme.of(c).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  SelectableText(details),
                  const SizedBox(height: 12),
                ],
                if (type == 'street_lamp' && lat != null && lng != null) ...[
                  Text('Location', style: Theme.of(c).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (photoUrl != null) ...[
                  Text('Photo', style: Theme.of(c).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(photoUrl);
                      await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(photoUrl, height: 160, fit: BoxFit.cover),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [_Logo(), const SizedBox(width: 8), const Text('News')],
        ),
      ),
      drawer: const _Nav(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summary,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Summary'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.image),
                  label: Text('Images (${_images.length})'),
                ),
                ElevatedButton.icon(
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
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(_pdf?.name ?? 'Attach PDF'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _posting ? null : _post,
              child: Text(_posting ? 'Posting...' : 'Post News'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('news')
                    .orderBy('publishedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;
                      return ListTile(
                        title: Text(d['title'] ?? ''),
                        subtitle: Text(d['summary'] ?? ''),
                        trailing: TextButton(
                          onPressed: () => context.go('/news/$id'),
                          child: const Text('Read'),
                        ),
                        onTap: () => context.go('/news/$id'),
                      );
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

class UsersAdminScreen extends StatelessWidget {
  const UsersAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [_Logo(), const SizedBox(width: 8), const Text('Users')],
        ),
      ),
      drawer: const _Nav(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final name = (d['displayName'] ?? d['name'] ?? '') as String;
              final email = (d['email'] ?? '') as String;
              final phone = (d['phone'] ?? d['phoneNumber'] ?? '') as String;
              return Card(
                child: ListTile(
                  title: Text(name.isEmpty ? email : name),
                  subtitle: Text('Email: $email\nPhone: $phone'),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _editUser(context, id, d),
                    icon: const Icon(Icons.edit),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editUser(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) async {
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
          title: const Text('Edit User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final phone = phoneCtrl.text.trim();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .update({
                      // write both sets of fields to keep both apps in sync
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
              child: const Text('Save'),
            ),
          ],
        );
      },
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
                try {
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passCtrl.text,
                  );
                  await user.reauthenticateWithCredential(cred);
                  if (c.mounted) Navigator.of(c).pop(true);
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(c).showSnackBar(
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
      onKeyEvent: (_, __) {
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
        ModalBarrier(color: Colors.black.withOpacity(0.5), dismissible: false),
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
