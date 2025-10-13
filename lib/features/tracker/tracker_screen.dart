import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:cloud_firestore/cloud_firestore.dart';

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
    // Listen to both vehicles and bins collections. If collections are missing, fall back to sample markers.
    final vehicles = FirebaseFirestore.instance
        .collection('vehicles')
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => _MapItem.fromDoc(d, isVehicle: true)).toList(),
        )
        .handleError((_) => <_MapItem>[]);
    final bins = FirebaseFirestore.instance
        .collection('bins')
        .snapshots()
        .map(
          (s) =>
              s.docs.map((d) => _MapItem.fromDoc(d, isVehicle: false)).toList(),
        )
        .handleError((_) => <_MapItem>[]);

    return vehicles
        .asyncMap((v) async {
          final b = await bins
              .first; // simple combineLatest-one shot per vehicles event
          final list = <_MapItem>[]
            ..addAll(v)
            ..addAll(b);
          if (list.isEmpty) {
            // Fallback demo items
            return [
              _MapItem(
                id: 'truck_demo',
                name: 'Waste Truck 1',
                position: const ll.LatLng(5.6237, -0.1970),
                isVehicle: true,
              ),
              _MapItem(
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
          (_) => <_MapItem>[
            _MapItem(
              id: 'truck_demo',
              name: 'Waste Truck 1',
              position: const ll.LatLng(5.6237, -0.1970),
              isVehicle: true,
            ),
            _MapItem(
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
      appBar: AppBar(title: const Text('Waste Tracker')),
      body: Stack(
        children: [
          StreamBuilder<List<_MapItem>>(
            stream: _itemsStream(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <_MapItem>[];
              return FlutterMap(
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
                          width: 44,
                          height: 44,
                          point: it.position,
                          child: _MarkerIcon(
                            isVehicle: it.isVehicle,
                            label: it.name,
                          ),
                        ),
                    ],
                  ),
                ],
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
                      icon: FontAwesomeIcons.truck,
                      label: 'Trucks (live)',
                    ),
                    _buildTrackerInfo(
                      context,
                      icon: FontAwesomeIcons.recycle,
                      label: 'Bins (live)',
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
        FaIcon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  final bool isVehicle;
  final String label;
  const _MarkerIcon({required this.isVehicle, required this.label});

  @override
  Widget build(BuildContext context) {
  final color = isVehicle ? Colors.green : Colors.blue;
    final icon = isVehicle ? FontAwesomeIcons.truck : FontAwesomeIcons.recycle;
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
          child: FaIcon(icon, color: Colors.white, size: 16),
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

class _MapItem {
  final String id;
  final String name;
  final ll.LatLng position;
  final bool isVehicle;

  const _MapItem({
    required this.id,
    required this.name,
    required this.position,
    required this.isVehicle,
  });

  factory _MapItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isVehicle,
  }) {
    final data = doc.data() ?? {};
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final name = (data['name'] as String?) ?? (isVehicle ? 'Vehicle' : 'Bin');
    return _MapItem(
      id: doc.id,
      name: name,
      position: (lat != null && lng != null)
          ? ll.LatLng(lat, lng)
          : _kDefaultCenter,
      isVehicle: isVehicle,
    );
  }
}
