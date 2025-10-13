import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  // Other complaints form
  final _formKeyOther = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  bool _submittingOther = false;

  // Street lamp form
  final _formKeyLamp = GlobalKey<FormState>();
  final _lampNoCtrl = TextEditingController();
  ll.LatLng _lampLocation = const ll.LatLng(7.45, 80.03); // Udubaddawa default
  final MapController _mapController = MapController();
  XFile? _lampPhoto;
  bool _submittingLamp = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _detailsCtrl.dispose();
    _lampNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitOther() async {
    if (!_formKeyOther.currentState!.validate()) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a complaint.')),
      );
      return;
    }
    setState(() => _submittingOther = true);
    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'uid': user.uid,
        'type': 'other',
        'subject': _subjectCtrl.text.trim(),
        'details': _detailsCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _subjectCtrl.clear();
      _detailsCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to submit complaint: $e')));
    } finally {
      if (mounted) setState(() => _submittingOther = false);
    }
  }

  Future<void> _useMyLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _lampLocation = ll.LatLng(pos.latitude, pos.longitude);
    });
    _mapController.move(_lampLocation, _mapController.camera.zoom);
  }

  Future<void> _pickLampPhoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img != null) {
      setState(() => _lampPhoto = img);
    }
  }

  Future<void> _submitLamp() async {
    if (!_formKeyLamp.currentState!.validate()) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a complaint.')),
      );
      return;
    }
    if (_lampPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo of the street lamp.')),
      );
      return;
    }
    setState(() => _submittingLamp = true);
    try {
      // Upload photo first
      final bytes = await _lampPhoto!.readAsBytes();
      final path = 'complaints/uploads/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('complaints').add({
        'uid': user.uid,
        'type': 'street_lamp',
        'subject': 'Street Lamp',
        'lampNumber': _lampNoCtrl.text.trim(),
        'lat': _lampLocation.latitude,
        'lng': _lampLocation.longitude,
        'photoUrl': url,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _lampNoCtrl.clear();
      _lampPhoto = null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Street lamp complaint submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
    } finally {
      if (mounted) setState(() => _submittingLamp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthService>(context).user;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complaints'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Street Lamp'),
              Tab(text: 'Other'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Street Lamp complaint form
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKeyLamp,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Report a broken street lamp', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 220,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _lampLocation,
                                initialZoom: 14,
                                onTap: (tapPos, latLng) {
                                  setState(() => _lampLocation = latLng);
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  subdomains: const ['a', 'b', 'c'],
                                  userAgentPackageName: 'lk.gov.ups.user',
                                  tileProvider: NetworkTileProvider(),
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      width: 40,
                                      height: 40,
                                      point: _lampLocation,
                                      child: const Icon(Icons.location_on, color: Colors.red, size: 36),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(onPressed: _useMyLocation, icon: const Icon(Icons.my_location), label: const Text('Use my location')),
                              OutlinedButton.icon(onPressed: () => _mapController.move(const ll.LatLng(7.45, 80.03), 14), icon: const Icon(Icons.refresh), label: const Text('Reset to Udubaddawa')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _lampNoCtrl,
                            decoration: const InputDecoration(labelText: 'Street Lamp Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.confirmation_number)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter the street lamp number' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(onPressed: _pickLampPhoto, icon: const Icon(Icons.photo_camera), label: const Text('Add Photo')),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_lampPhoto?.name ?? 'No photo selected')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _submittingLamp || user == null ? null : _submitLamp,
                            icon: const Icon(Icons.send),
                            label: Text(_submittingLamp ? 'Submitting...' : 'Submit'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _MyComplaintsList(userId: user?.uid),
              ],
            ),
            // Other complaint form
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKeyOther,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Submit a Complaint', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _subjectCtrl,
                            decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder(), prefixIcon: Icon(Icons.subject)),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a subject' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _detailsCtrl,
                            decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description)),
                            minLines: 3,
                            maxLines: 5,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Enter details' : null,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _submittingOther || user == null ? null : _submitOther,
                            icon: const FaIcon(FontAwesomeIcons.paperPlane, color: Colors.white),
                            label: _submittingOther ? const Text('Submitting...') : const Text('Submit'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _MyComplaintsList(userId: user?.uid),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyComplaintsList extends StatelessWidget {
  final String? userId;
  const _MyComplaintsList({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const Text('Sign in to view your complaints.');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('uid', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final am = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? -1;
          final bm = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? -1;
          return bm.compareTo(am);
        });
        if (docs.isEmpty) return const Text('No complaints yet.');
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final type = (d['type'] as String?) ?? 'other';
            final status = (d['status'] as String?) ?? 'open';
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
            final title = type == 'street_lamp'
                ? 'Street Lamp #${d['lampNumber'] ?? ''}'.trim()
                : (d['subject'] as String? ?? '');
            return Card(
              child: ListTile(
                leading: Icon(
                  status == 'open' ? Icons.mark_unread_chat_alt : Icons.check_circle,
                  color: status == 'open' ? Colors.orange : Colors.green,
                ),
                title: Text(title),
                subtitle: Text(createdAt != null ? '${createdAt.toLocal()}'.split(' ')[0] : ''),
                trailing: Chip(label: Text(status)),
              ),
            );
          },
        );
      },
    );
  }
}
