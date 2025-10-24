import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// Default map center (Udubaddawa, Sri Lanka - approximate)
const ll.LatLng _kDefaultCenter = ll.LatLng(7.45, 80.03);

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  static const ll.LatLng _center = _kDefaultCenter;
  final MapController _mapController = MapController();

  Stream<List<_MapItem>> _itemsStream() {
    return FirebaseFirestore.instance
        .collection('vehicles')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => _MapItem.fromDoc(d))
            .toList())
        .handleError((_) => <_MapItem>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Tracker')),
      body: Stack(
        children: [
          StreamBuilder<List<_MapItem>>(
            stream: _itemsStream(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <_MapItem>[];
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: 12,
                  // Enable all interactions; on web this includes mouse wheel zoom
                  // If your flutter_map version supports InteractionOptions, this will work.
                  // Otherwise, defaults already enable wheel zoom.
                  // interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.ups',
                    tileProvider: NetworkTileProvider(),
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap contributors',
                        onTap: () => debugPrint(
                          'https://www.openstreetmap.org/copyright',
                        ),
                      ),
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
                            onTap: () => _showTruckPopup(context, it),
                            child: _PulseMarker(
                              recent: it.updatedAt != null &&
                                  DateTime.now().difference(it.updatedAt!).inMinutes <= 2,
                              child: _MarkerIcon(label: it.name),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              );
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    _buildTrackerInfo(
                      context,
                      icon: Icons.local_shipping,
                      label: 'Trucks (live)',
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Zoom controls
          Positioned(
            right: 12,
            top: 80,
            child: Column(
              children: [
                // Fit to markers
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Fit all',
                    icon: const Icon(Icons.center_focus_strong),
                    onPressed: () {
                      // We can't read stream synchronously; so use current camera if empty.
                      // Instead, fetch last snapshot via a one-shot get of vehicles.
                      FirebaseFirestore.instance
                          .collection('vehicles')
                          .where('active', isEqualTo: true)
                          .get()
                          .then((qs) {
                        final pts = <ll.LatLng>[];
                        for (final d in qs.docs) {
                          final data = d.data();
                          final lat = (data['lat'] as num?)?.toDouble();
                          final lng = (data['lng'] as num?)?.toDouble();
                          if (lat != null && lng != null) {
                            pts.add(ll.LatLng(lat, lng));
                          }
                        }
                        if (pts.isEmpty) return;
                        final bounds = LatLngBounds.fromPoints(pts);
                        _mapController.fitCamera(
                          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(36)),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      final center = _mapController.camera.center;
                      _mapController.move(center, currentZoom + 1);
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
                      final currentZoom = _mapController.camera.zoom;
                      final center = _mapController.camera.center;
                      _mapController.move(center, currentZoom - 1);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerInfo(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final String label;
  const _MarkerIcon({required this.label});

  @override
  Widget build(BuildContext context) {
    const color = Colors.green;
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
          child: const Icon(Icons.local_shipping, color: Colors.white, size: 16),
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

class _PulseMarker extends StatefulWidget {
  final Widget child;
  final bool recent;
  const _PulseMarker({required this.child, required this.recent});

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.recent) return widget.child;
    return SizedBox(
      width: 46,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value; // 0..1
              final scale = 1 + 0.8 * t;
              final opacity = (1 - t).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _MapItem {
  final String id;
  final String name;
  final ll.LatLng position;
  final DateTime? updatedAt;
  final double? lat;
  final double? lng;
  final double? speedKph;
  final double? heading;

  const _MapItem({
    required this.id,
    required this.name,
    required this.position,
    this.updatedAt,
    this.lat,
    this.lng,
    this.speedKph,
    this.heading,
  });

  factory _MapItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final name = (data['name'] as String?) ?? 'Vehicle';
    final ts = data['updatedAt'];
    DateTime? updatedAt;
    if (ts is Timestamp) updatedAt = ts.toDate();
    final speed = (data['speedKph'] as num?)?.toDouble();
    final head = (data['heading'] as num?)?.toDouble();
    return _MapItem(
      id: doc.id,
      name: name,
      position: (lat != null && lng != null)
          ? ll.LatLng(lat, lng)
          : _kDefaultCenter,
      updatedAt: updatedAt,
      lat: lat,
      lng: lng,
      speedKph: speed,
      heading: head,
    );
  }
}

extension on DateTime {
  String toLocalDateTimeString() {
    final d = toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

extension on num? {
  String asCoord() => this == null ? '—' : (this as num).toStringAsFixed(5);
}

extension on DateTime? {
  String fmtOrDash() => this == null ? '—' : this!.toLocalDateTimeString();
}

extension on _TrackerScreenState {
  Future<void> _showTruckPopup(BuildContext context, _MapItem item) async {
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
                Text('Last updated: ${item.updatedAt.fmtOrDash()}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 16),
                const SizedBox(width: 6),
                Text('Lat: ${item.lat.asCoord()}  •  Lng: ${item.lng.asCoord()}'),
              ],
            ),
            if (item.speedKph != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.speed, size: 16),
                const SizedBox(width: 6),
                Text('Speed: ${item.speedKph!.toStringAsFixed(1)} km/h'),
              ]),
            ],
            if (item.heading != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.navigation, size: 16),
                const SizedBox(width: 6),
                Text('Heading: ${item.heading!.toStringAsFixed(0)}°'),
              ]),
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
