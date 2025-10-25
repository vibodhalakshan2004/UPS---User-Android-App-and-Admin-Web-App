import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../auth/auth_service.dart';
import '../../models/booking_model.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  late final TextEditingController _dateCtrl;

  String _bookingType = 'ground';
  DateTime _selectedDate = DateTime.now();
  String? _cemeterySlot;
  String? _deathCertUrl;
  String? _deathCertName;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _reasonCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  DateTime _normalizedDate(DateTime d) => DateTime(d.year, d.month, d.day);

  String _formatDate(DateTime date) => DateFormat('d MMM y').format(date);

  void _applySelectedDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _dateCtrl.text = _formatDate(date);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      _applySelectedDate(picked);
    }
  }

  Future<void> _pickDeathCertificate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }

    final ext = file.extension?.toLowerCase();
    final contentType = ext == 'pdf'
        ? 'application/pdf'
        : ext == null
        ? 'application/octet-stream'
        : 'image/$ext';

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'death_certificates/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
      );
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await storageRef.putData(bytes, metadata);
      final url = await uploadTask.ref.getDownloadURL();

      if (!mounted) return;
      setState(() {
        _deathCertUrl = url;
        _deathCertName = file.name;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('File uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('You must be logged in to book.')),
      );
      return;
    }

    final bookingDate = _normalizedDate(_selectedDate);

    final existingBookingSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('bookingDate', isEqualTo: Timestamp.fromDate(bookingDate))
        .limit(1)
        .get();

    if (existingBookingSnapshot.docs.isNotEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This date is already booked. Please choose another.'),
        ),
      );
      return;
    }

    final details = <String>[];
    final notes = _reasonCtrl.text.trim();
    final preferredTime = _timeCtrl.text.trim();

    if (notes.isNotEmpty) {
      details.add(notes);
    }
    if (_bookingType == 'ground' && preferredTime.isNotEmpty) {
      details.add('Time: $preferredTime');
    }
    if (_bookingType == 'cemetery' && _cemeterySlot != null) {
      details.add('Slot: ${_cemeterySlot!}');
    }

    final booking = Booking(
      id: '',
      userId: user.uid,
      bookingType: _bookingType,
      bookingDate: bookingDate,
      bookingReason: details.join(' | '),
      status: 'pending',
      deathCertificateUrl: _deathCertUrl,
      deathCertificateName: _deathCertName,
    );

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .add(booking.toFirestore());

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking submitted successfully!')),
      );

      _formKey.currentState!.reset();
      setState(() {
        _bookingType = 'ground';
        _cemeterySlot = null;
        _deathCertUrl = null;
        _deathCertName = null;
        _selectedDate = DateTime.now();
      });
      _reasonCtrl.clear();
      _timeCtrl.clear();
      _applySelectedDate(DateTime.now());
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to submit booking: $e')),
      );
    }
  }

  Widget _buildSlotChip(
    BuildContext context,
    FormFieldState<String> fieldState,
    String slot,
    bool isDisabled,
  ) {
    final theme = Theme.of(context);
    final isSelected = _cemeterySlot == slot;

    return ChoiceChip(
      label: Text(slot),
      selected: isSelected,
      onSelected: isDisabled
          ? null
          : (value) {
              if (!value) {
                setState(() => _cemeterySlot = null);
                fieldState.didChange(null);
              } else {
                setState(() => _cemeterySlot = slot);
                fieldState.didChange(slot);
              }
            },
      avatar: isDisabled
          ? Icon(
              Icons.lock_clock,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            )
          : null,
      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
      backgroundColor: isDisabled
          ? theme.colorScheme.error.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerHigh,
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: isDisabled
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      side: BorderSide(
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withValues(alpha: 0.4),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthService>(context).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Community Reservations')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const _BookingHero(),
            const SizedBox(height: 20),
            _buildBookingForm(context),
            const SizedBox(height: 28),
            Text(
              'My bookings',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track approvals, attachments, and updates in real time.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _BookingHistoryList(userId: user?.uid),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm(BuildContext context) {
    final theme = Theme.of(context);

    return _FrostedSectionCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reserve a community ground or cemetery slot. We\'ll confirm once staff review your request.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              key: ValueKey('booking-type-$_bookingType'),
              initialValue: _bookingType,
              decoration: InputDecoration(
                labelText: 'Booking type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ground',
                  child: Text('Ground booking'),
                ),
                DropdownMenuItem(
                  value: 'cemetery',
                  child: Text('Cemetery booking'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _bookingType = value;
                  _cemeterySlot = null;
                  _timeCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where(
                    'bookingDate',
                    isEqualTo: Timestamp.fromDate(
                      _normalizedDate(_selectedDate),
                    ),
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final approvedDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['status'] as String?) == 'approved';
                }).toList();
                final dateBooked = approvedDocs.isNotEmpty;

                final slotPattern = RegExp(
                  r'Time:\s*([0-9: ]+(AM|PM))',
                  caseSensitive: false,
                );
                final bookedSlots = <String>{};
                for (final doc in approvedDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final reason = (data['bookingReason'] as String?) ?? '';
                  final match = slotPattern.firstMatch(reason);
                  if (match != null) {
                    bookedSlots.add(match.group(1)!.toUpperCase().trim());
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dateBooked)
                      _AvailabilityBanner(
                        message:
                            'Another resident already holds this date. Please pick a different day.',
                        icon: Icons.event_busy,
                        color: theme.colorScheme.error,
                      ),
                    if (_bookingType == 'cemetery')
                      FormField<String>(
                        validator: (_) {
                          if (_bookingType == 'cemetery' &&
                              !dateBooked &&
                              (_cemeterySlot == null ||
                                  _cemeterySlot!.isEmpty)) {
                            return 'Select an available time slot';
                          }
                          return null;
                        },
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time slot',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final slot in const [
                                  '12:00 PM',
                                  '2:00 PM',
                                  '4:00 PM',
                                ])
                                  _buildSlotChip(
                                    context,
                                    state,
                                    slot,
                                    dateBooked || bookedSlots.contains(slot),
                                  ),
                              ],
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  state.errorText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    if (_bookingType == 'ground')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _timeCtrl,
                            enabled: !dateBooked,
                            decoration: InputDecoration(
                              labelText: 'Preferred time (e.g., 3:30 PM)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            validator: (value) {
                              if (_bookingType != 'ground' || dateBooked) {
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a preferred time';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    TextFormField(
                      controller: _dateCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Service date',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        suffixIcon: IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.calendarDay,
                            size: 18,
                          ),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reasonCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason for booking',
                        hintText: 'Tell us what the crew should prepare for',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide context for the request';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Attachments',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _deathCertName ??
                                'Upload a death certificate (PDF or image)',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _pickDeathCertificate(context),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _deathCertUrl == null ? 'Upload' : 'Replace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: const [
                        _LegendPill(color: Colors.green, label: 'Available'),
                        _LegendPill(color: Colors.red, label: 'Booked'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed:
                          snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () => _submitBooking(),
                      icon: const FaIcon(FontAwesomeIcons.paperPlane),
                      label: const Text('Submit booking'),
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

class _BookingHero extends StatelessWidget {
  const _BookingHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5B8EFF), Color(0xFF46C0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const FaIcon(
              FontAwesomeIcons.peopleGroup,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan your reservation',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reserve community grounds or cemetery time slots in a few taps. We\'ll keep you updated as staff review each request.',
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

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _FrostedSectionCard extends StatelessWidget {
  const _FrostedSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.4 : 0.78,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _BookingHistoryList extends StatelessWidget {
  const _BookingHistoryList({required this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const _BookingEmptyState(
        icon: FontAwesomeIcons.lock,
        title: 'Sign in to view bookings',
        message:
            'Create an account or sign in to submit and track pickup requests.',
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .orderBy('bookingDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _BookingSkeletonList();
        }
        if (snapshot.hasError) {
          return const _BookingEmptyState(
            icon: FontAwesomeIcons.triangleExclamation,
            title: 'Could not load bookings',
            message:
                'Please try again soon. Your previous submissions are safe.',
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _BookingEmptyState(
            icon: FontAwesomeIcons.calendarCheck,
            title: 'No bookings yet',
            message:
                'Once you submit a request, it will appear here with live status updates.',
          );
        }

        final bookings = docs.map((doc) => Booking.fromFirestore(doc)).toList();

        return Column(
          children: [
            for (var i = 0; i < bookings.length; i++) ...[
              _BookingCard(booking: bookings[i]),
              if (i != bookings.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _BookingEmptyState extends StatelessWidget {
  const _BookingEmptyState({
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
    return _FrostedSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: theme.colorScheme.primary, size: 24),
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

class _BookingSkeletonList extends StatelessWidget {
  const _BookingSkeletonList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.3,
    );

    Widget block({double height = 12, double width = double.infinity}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          _FrostedSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(height: 18, width: 180),
                const SizedBox(height: 12),
                block(),
                const SizedBox(height: 8),
                block(width: 200),
                const SizedBox(height: 16),
                block(height: 48, width: 120),
              ],
            ),
          ),
          if (i != 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = booking.bookingType == 'cemetery'
        ? 'Cemetery booking'
        : 'Ground booking';
    final dateLabel = DateFormat(
      'd MMM y',
    ).format(booking.bookingDate.toLocal());
    final detailParts = booking.bookingReason
        .split('|')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    final mainNote = detailParts.isEmpty
        ? 'No additional notes.'
        : detailParts.first;
    final extras = detailParts.length > 1 ? detailParts.sublist(1) : <String>[];
    final attachmentUrl = booking.deathCertificateUrl;
    final attachmentName = booking.deathCertificateName ?? 'View attachment';
    final messenger = ScaffoldMessenger.of(context);

    Future<void> openAttachment() async {
      if (attachmentUrl == null) return;
      final uri = Uri.tryParse(attachmentUrl);
      if (uri == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Attachment link is invalid.')),
        );
        return;
      }

      try {
        final launched = await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );

        if (!context.mounted) return;
        if (!launched) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not open attachment.')),
          );
        }
      } catch (_) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not open attachment.')),
        );
      }
    }

    return _FrostedSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(
                  booking.bookingType == 'cemetery'
                      ? FontAwesomeIcons.cross
                      : FontAwesomeIcons.truck,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '$typeLabel · $dateLabel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _StatusChip(status: booking.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mainNote,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final detail in extras)
                  Chip(
                    avatar: const Icon(Icons.info_outline, size: 16),
                    label: Text(detail),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEEE').format(booking.bookingDate),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (booking.id.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reference #${booking.id}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (attachmentUrl != null) ...[
            const SizedBox(height: 12),
            Text(
              'Attachment',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: openAttachment,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(attachmentName),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = status.toLowerCase().trim();

    Color background;
    Color foreground;
    IconData icon;

    switch (normalized) {
      case 'approved':
        background = theme.colorScheme.primary.withValues(alpha: 0.16);
        foreground = theme.colorScheme.primary;
        icon = Icons.verified_rounded;
        break;
      case 'completed':
        background = theme.colorScheme.tertiary.withValues(alpha: 0.16);
        foreground = theme.colorScheme.tertiary;
        icon = Icons.task_alt_rounded;
        break;
      case 'rejected':
      case 'declined':
        background = theme.colorScheme.error.withValues(alpha: 0.14);
        foreground = theme.colorScheme.error;
        icon = Icons.cancel_rounded;
        break;
      default:
        background = theme.colorScheme.secondary.withValues(alpha: 0.14);
        foreground = theme.colorScheme.secondary;
        icon = Icons.hourglass_bottom_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            normalized.isEmpty ? 'Pending' : status,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
