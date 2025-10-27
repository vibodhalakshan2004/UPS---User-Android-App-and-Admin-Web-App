import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart' as geo;

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
  ll.LatLng? _userLoc;

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
              final map = AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        key: const ValueKey('map'),
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: 12,
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
                          // Trucks layer
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
                                          DateTime.now()
                                                  .difference(it.updatedAt!)
                                                  .inMinutes <=
                                              2,
                                      child: _MarkerIcon(label: it.name),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // User location layer (if available)
                          if (_userLoc != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 24,
                                  height: 24,
                                  point: _userLoc!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      boxShadow: const [
                                        BoxShadow(
                                            blurRadius: 6,
                                            color: Colors.black26),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
              );
              // Overlay the live trucks bar inside same stack so we have access to items
              return Stack(
                children: [
                  map,
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _LiveTrucksBar(
                      items: items,
                      onTapTruck: _centerOn,
                    ),
                  ),
                ],
              );
            },
          ),
          // Zoom controls
          Positioned(
            right: 12,
            top: 80,
            child: Column(
              children: [
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
          // Current location button
          Positioned(
            right: 12,
            bottom: 100,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                tooltip: 'My location',
                icon: const Icon(Icons.my_location),
                onPressed: _locateMe,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _locateMe() async {
    try {
      final service = await geo.Geolocator.isLocationServiceEnabled();
      if (!service) {
        _showSnack('Location services are disabled');
        return;
      }
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied) {
        _showSnack('Location permission denied');
        return;
      }
      if (permission == geo.LocationPermission.deniedForever) {
        _showSnack('Location permission permanently denied. Enable in Settings.');
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final here = ll.LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _userLoc = here);
      _mapController.move(here, 15);
    } catch (e) {
      _showSnack('Failed to get location');
    }
  }

  void _centerOn(_MapItem it) {
    _mapController.move(it.position, 15);
  }

  void _showSnack(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  }

}

class _LiveTrucksBar extends StatelessWidget {
  final List<_MapItem> items;
  final void Function(_MapItem) onTapTruck;
  const _LiveTrucksBar({required this.items, required this.onTapTruck});

  @override
  Widget build(BuildContext context) {
    final live = items;
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, size: 20),
                const SizedBox(width: 8),
                Text('Trucks (live: ${live.length})',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: live.isEmpty
                  ? const Center(child: Text('No live trucks'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (c, i) {
                        final it = live[i];
                        final recent = it.updatedAt != null &&
                            DateTime.now()
                                    .difference(it.updatedAt!)
                                    .inMinutes <=
                                2;
                        return ActionChip(
                          avatar: Icon(
                            Icons.local_shipping,
                            size: 18,
                            color: recent ? Colors.green : Colors.grey,
                          ),
                          label: Text(it.name, overflow: TextOverflow.ellipsis),
                          onPressed: () => onTapTruck(it),
                        );
                      },
                      separatorBuilder: (_, i2) => const SizedBox(width: 8),
                      itemCount: live.length,
                    ),
            ),
          ],
        ),
      ),
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
                      color: Colors.green.withValues(alpha: 0.3),
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
