import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!_formKeyOther.currentState!.validate()) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      messenger?.showSnackBar(
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
      messenger?.showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to submit complaint: $e')),
      );
    } finally {
      if (mounted) setState(() => _submittingOther = false);
    }
  }

  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!_formKeyLamp.currentState!.validate()) return;
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a complaint.')),
      );
      return;
    }
    if (_lampPhoto == null) {
      messenger?.showSnackBar(
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
      messenger?.showSnackBar(
        const SnackBar(content: Text('Street lamp complaint submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Street Lamp'),
                    Tab(text: 'Other'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Street Lamp complaint form
            _StreetLampTab(
              formKey: _formKeyLamp,
              mapController: _mapController,
              lampLocation: _lampLocation,
              lampNoCtrl: _lampNoCtrl,
              submitting: _submittingLamp,
              onLocationChanged: (latLng) => setState(() => _lampLocation = latLng),
              onUseMyLocation: _useMyLocation,
              onResetLocation: () => _mapController.move(const ll.LatLng(7.45, 80.03), 14),
              onPickPhoto: _pickLampPhoto,
              onSubmit: user == null ? null : _submitLamp,
              photoName: _lampPhoto?.name,
              userId: user?.uid,
            ),
            // Other complaint form
            _OtherComplaintTab(
              formKey: _formKeyOther,
              subjectCtrl: _subjectCtrl,
              detailsCtrl: _detailsCtrl,
              submitting: _submittingOther,
              onSubmit: user == null ? null : _submitOther,
              userId: user?.uid,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreetLampTab extends StatelessWidget {
  const _StreetLampTab({
    required this.formKey,
    required this.mapController,
    required this.lampLocation,
    required this.lampNoCtrl,
    required this.submitting,
    required this.onLocationChanged,
    required this.onUseMyLocation,
    required this.onResetLocation,
    required this.onPickPhoto,
    required this.onSubmit,
    required this.photoName,
    required this.userId,
  });

  final GlobalKey<FormState> formKey;
  final MapController mapController;
  final ll.LatLng lampLocation;
  final TextEditingController lampNoCtrl;
  final bool submitting;
  final ValueChanged<ll.LatLng> onLocationChanged;
  final Future<void> Function()? onUseMyLocation;
  final VoidCallback onResetLocation;
  final Future<void> Function() onPickPhoto;
  final Future<void> Function()? onSubmit;
  final String? photoName;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const _ComplaintsHero(
          icon: FontAwesomeIcons.lightbulb,
          title: 'Report a broken street lamp',
          subtitle:
              'Pin the exact pole, attach a quick photo, and we\'ll dispatch maintenance right away.',
          gradient: [
            Color(0xFF5A5EFF),
            Color(0xFF4FB7FF),
          ],
        ),
        const SizedBox(height: 20),
        _FrostedCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lamp details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: lampLocation,
                        initialZoom: 14,
                        onTap: (tapPosition, latLng) => onLocationChanged(latLng),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'lk.gov.ups.user',
                          tileProvider: NetworkTileProvider(),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 40,
                              height: 40,
                              point: lampLocation,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: submitting || onUseMyLocation == null
                          ? null
                          : () => onUseMyLocation!(),
                      icon: const Icon(Icons.my_location_outlined),
                      label: const Text('Use my location'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: submitting ? null : onResetLocation,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Reset to Udubaddawa'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: lampNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Street lamp number',
                    hintText: 'e.g., SL-102',
                    prefixIcon: Icon(Icons.confirmation_number_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter the street lamp number'
                          : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: submitting ? null : () => onPickPhoto(),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Add photo'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        photoName ?? 'No photo selected yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitting || onSubmit == null
                      ? null
                      : () => onSubmit!(),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(submitting ? 'Submitting...' : 'Submit complaint'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _MyComplaintsList(userId: userId),
      ],
    );
  }
}

class _OtherComplaintTab extends StatelessWidget {
  const _OtherComplaintTab({
    required this.formKey,
    required this.subjectCtrl,
    required this.detailsCtrl,
    required this.submitting,
    required this.onSubmit,
    required this.userId,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController subjectCtrl;
  final TextEditingController detailsCtrl;
  final bool submitting;
  final Future<void> Function()? onSubmit;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        const _ComplaintsHero(
          icon: FontAwesomeIcons.building,
          title: 'Share any other concern',
          subtitle:
              'Let us know what needs attention and we\'ll route it to the right department.',
          gradient: [
            Color(0xFF6A8DFF),
            Color(0xFF8FD6FF),
          ],
        ),
        const SizedBox(height: 20),
        _FrostedCard(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complaint details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: subjectCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    prefixIcon: Icon(Icons.subject_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter a subject'
                          : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: detailsCtrl,
                  minLines: 4,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Enter details'
                          : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitting || onSubmit == null
                      ? null
                      : () => onSubmit!(),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const FaIcon(FontAwesomeIcons.paperPlane),
                  label: Text(submitting ? 'Submitting...' : 'Submit complaint'),
                ),
                const SizedBox(height: 16),
                Text(
                  'We\'ll update your profile timeline as municipal staff review your case.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _MyComplaintsList(userId: userId),
      ],
    );
  }
}

class _ComplaintsHero extends StatelessWidget {
  const _ComplaintsHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: FaIcon(
              icon,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedCard extends StatelessWidget {
  const _FrostedCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.78,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _MyComplaintsList extends StatelessWidget {
  const _MyComplaintsList({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const _ComplaintsEmptyState(
        icon: FontAwesomeIcons.lock,
        title: 'Sign in to track complaints',
        message:
            'Create an account or sign in to submit issues and follow their progress.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('uid', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ComplaintsSkeletonList();
        }
        if (snapshot.hasError) {
          return const _ComplaintsEmptyState(
            icon: FontAwesomeIcons.triangleExclamation,
            title: 'Could not load complaints',
            message: 'Please try again shortly. Your submissions are still safe.',
          );
        }

        final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aMillis =
              ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  -1;
          final bMillis =
              ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  -1;
          return bMillis.compareTo(aMillis);
        });

        if (docs.isEmpty) {
          return const _ComplaintsEmptyState(
            icon: FontAwesomeIcons.faceSmile,
            title: 'No complaints yet',
            message:
                'Once you submit a complaint, you will see live status updates here.',
          );
        }

        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest complaints',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < docs.length; i++) ...[
              _ComplaintCard(
                complaint: docs[i].data() as Map<String, dynamic>,
              ),
              if (i != docs.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final Map<String, dynamic> complaint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = (complaint['type'] as String?) ?? 'other';
    final status = (complaint['status'] as String?) ?? 'open';
    final timestamp = complaint['createdAt'] as Timestamp?;
  final DateTime? createdAt = timestamp?.toDate().toLocal();
    final photoUrl = complaint['photoUrl'] as String?;
    final subject = (complaint['subject'] as String?) ?? 'Complaint';
    final lampNumber = complaint['lampNumber'];
    final lat = (complaint['lat'] as num?)?.toDouble();
    final lng = (complaint['lng'] as num?)?.toDouble();
    final rawDetails = (complaint['details'] as String?)?.trim();

    final title = type == 'street_lamp'
        ? 'Street lamp ${lampNumber ?? ''}'.trim()
        : subject.trim().isEmpty
            ? 'Complaint'
            : subject;

  final description = (rawDetails?.isNotEmpty ?? false)
    ? rawDetails!
    : type == 'street_lamp'
      ? 'Maintenance team will review the provided location and photo.'
      : 'No additional details provided.';

    return _FrostedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FaIcon(
                  type == 'street_lamp'
                      ? FontAwesomeIcons.lightbulb
                      : FontAwesomeIcons.clipboard,
                  size: 18,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt != null
                          ? DateFormat('d MMM y • h:mm a').format(createdAt)
                          : 'Awaiting timestamp',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _ComplaintStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium,
          ),
          if (type == 'street_lamp' && (lampNumber != null || lat != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (lampNumber != null)
                  Chip(
                    avatar: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 16,
                    ),
                    label: Text('Lamp #$lampNumber'),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                if (lat != null && lng != null)
                  Chip(
                    avatar: const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                    ),
                    label: Text(
                      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (photoUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse(photoUrl);
                await url_launcher.launchUrl(
                  uri,
                  mode: url_launcher.LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('View full image'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComplaintsEmptyState extends StatelessWidget {
  const _ComplaintsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _FrostedCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              icon,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintsSkeletonList extends StatelessWidget {
  const _ComplaintsSkeletonList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32);

    Widget block({double height = 12, double width = double.infinity}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block(height: 16, width: 160),
        const SizedBox(height: 16),
        for (var i = 0; i < 2; i++) ...[
          _FrostedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(height: 18, width: 180),
                const SizedBox(height: 12),
                block(),
                const SizedBox(height: 8),
                block(width: 200),
                const SizedBox(height: 16),
                block(height: 140),
              ],
            ),
          ),
          if (i != 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ComplaintStatusChip extends StatelessWidget {
  const _ComplaintStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final Color background;
    late final Color foreground;

    switch (status) {
      case 'closed':
        background = theme.colorScheme.primaryContainer;
        foreground = theme.colorScheme.onPrimaryContainer;
        break;
      case 'in_progress':
        background = theme.colorScheme.tertiaryContainer;
        foreground = theme.colorScheme.onTertiaryContainer;
        break;
      case 'open':
      default:
        background = theme.colorScheme.secondaryContainer;
        foreground = theme.colorScheme.onSecondaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'closed':
        return 'Closed';
      case 'in_progress':
        return 'In Progress';
      case 'open':
      default:
        return 'Open';
    }
  }
}
