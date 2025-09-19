import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  static const LatLng _center = LatLng(5.6037, -0.1870); // Accra, Ghana

  final Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('waste_truck_1'),
      position: LatLng(5.6237, -0.1970),
      infoWindow: InfoWindow(title: 'Waste Truck 1'),
      icon: BitmapDescriptor.defaultMarker,
    ),
    Marker(
      markerId: const MarkerId('waste_bin_1'),
      position: const LatLng(5.6037, -0.1870),
      infoWindow: const InfoWindow(title: 'Community Bin'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Tracker')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 12,
            ),
            markers: _markers,
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
                      label: '1 Active Truck',
                    ),
                    _buildTrackerInfo(
                      context,
                      icon: FontAwesomeIcons.recycle,
                      label: '5 Bins Nearby',
                    ),
                  ],
                ),
              ),
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
