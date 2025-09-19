import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/booking_model.dart';
import '../../auth/auth_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _bookingType = 'ground';
  DateTime _selectedDate = DateTime.now();
  String _bookingReason = '';
  String? _cemeterySlot; // '12:00 PM', '2:00 PM', '4:00 PM'
  String? _groundTime; // free text entry for ground
  String? _deathCertUrl;
  String? _deathCertName;

  DateTime _normalizedDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitBooking() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    // Ensure the selected/typed time is included in reason if not already
    if (_bookingType == 'ground' && _groundTime != null && _groundTime!.trim().isNotEmpty) {
      if (!_bookingReason.contains('Time:')) {
        _bookingReason = _bookingReason.isEmpty
            ? 'Time: ${_groundTime!.trim()}'
            : '$_bookingReason | Time: ${_groundTime!.trim()}';
      }
    }

    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to book.')),
      );
      return;
    }

    final bookingDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    // Check for existing bookings on the same day
    final querySnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('bookingDate', isEqualTo: Timestamp.fromDate(bookingDate))
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This date is already booked. Please choose another.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final newBooking = Booking(
      id: '', // Firestore will generate ID
      userId: user.uid,
      bookingType: _bookingType,
      bookingDate: bookingDate,
      bookingReason: _bookingReason,
      status: 'pending',
      deathCertificateUrl: _deathCertUrl,
      deathCertificateName: _deathCertName,
    );

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .add(newBooking.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking submitted successfully!')),
        );
        _formKey.currentState!.reset();
        setState(() {
          _bookingType = 'ground';
          _selectedDate = DateTime.now();
          _bookingReason = '';
          _cemeterySlot = null;
          _groundTime = null;
          _deathCertUrl = null;
          _deathCertName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Book a Pickup')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule a Waste Pickup',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBookingForm(context),
            const SizedBox(height: 32),
            Text(
              'My Bookings',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildBookingList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Booking Type',
                  border: OutlineInputBorder(),
                ),
                initialValue: _bookingType,
                items: const [
                  DropdownMenuItem(
                    value: 'ground',
                    child: Text('Ground Booking'),
                  ),
                  DropdownMenuItem(
                    value: 'cemetery',
                    child: Text('Cemetery Booking'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _bookingType = value!;
                    // reset time inputs on switch
                    _cemeterySlot = null;
                    _groundTime = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Availability for the selected date
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('bookingDate', isEqualTo: Timestamp.fromDate(_normalizedDate(_selectedDate)))
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  final bool dateBooked = docs.isNotEmpty;
                  // Attempt to parse booked time slots from bookingReason text, if present
                  final Set<String> bookedSlots = {
                    for (final d in docs)
                      ...() {
                        final data = d.data() as Map<String, dynamic>;
                        final reason = (data['bookingReason'] as String?) ?? '';
                        final regex = RegExp(r'Time:\s*([0-9: ]+(AM|PM))', caseSensitive: false);
                        final m = regex.firstMatch(reason);
                        if (m != null) return {m.group(1)!.toUpperCase().replaceAll(' ', ' ').trim()};
                        return <String>{};
                      }()
                  };

                  Widget cemeteryWidget = const SizedBox.shrink();
                  if (_bookingType == 'cemetery') {
                    final slots = const ['12:00 PM', '2:00 PM', '4:00 PM'];
                    cemeteryWidget = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Time Slot', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in slots)
                              ChoiceChip(
                                label: Text(bookedSlots.contains(s) || dateBooked ? '$s (Booked)' : s),
                                selected: _cemeterySlot == s,
                                onSelected: (selected) {
                                  if (dateBooked || bookedSlots.contains(s)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('This slot is already booked.')),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _cemeterySlot = selected ? s : null;
                                  });
                                },
                disabledColor: theme.colorScheme.error.withValues(alpha: 0.15),
                                backgroundColor: bookedSlots.contains(s) || dateBooked
                  ? theme.colorScheme.error.withValues(alpha: 0.15)
                                    : null,
                                labelStyle: TextStyle(
                                  color: bookedSlots.contains(s) || dateBooked
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                          ],
                        ),
                        // Hidden validator for cemetery selection
                        FormField<String>(
                          validator: (_) {
                            if (_bookingType == 'cemetery' && !dateBooked && _cemeterySlot == null) {
                              return 'Please select a time slot';
                            }
                            return null;
                          },
                          builder: (state) => state.hasError
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(state.errorText!, style: TextStyle(color: theme.colorScheme.error)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }

                  final dateField = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Select Date',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const FaIcon(FontAwesomeIcons.calendarDay),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        controller: TextEditingController(
                          text: '${_selectedDate.toLocal()}'.split(' ')[0],
                        ),
                      ),
                      if (dateBooked) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.event_busy, color: theme.colorScheme.error, size: 18),
                            const SizedBox(width: 6),
                            Text('This date is already booked', style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ]
                    ],
                  );

                  final groundTimeField = _bookingType == 'ground'
                      ? TextFormField(
                          enabled: !dateBooked,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Time (e.g., 3:30 PM)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => _groundTime = v,
                          onSaved: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              _bookingReason =
                                  _bookingReason.isEmpty ? 'Time: ${v.trim()}' : '$_bookingReason | Time: ${v.trim()}';
                            }
                          },
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Please enter a preferred time'
                              : null,
                        )
                      : const SizedBox.shrink();

                  return Column(
                    children: [
                      if (_bookingType == 'cemetery') ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Death Certificate (PDF or Image)', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _deathCertName == null ? 'No file selected' : _deathCertName!,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                                  withData: true,
                                );
                                if (result == null || result.files.isEmpty) return;
                                final file = result.files.single;
                                final bytes = file.bytes;
                                if (bytes == null) return;
                                try {
                                  final storageRef = FirebaseStorage.instance.ref().child(
                                        'death_certificates/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
                                      );
                                  final meta = SettableMetadata(
                                    contentType: file.extension == 'pdf' ? 'application/pdf' : 'image/${file.extension}',
                                  );
                                  final uploadTask = await storageRef.putData(bytes, meta);
                                  final url = await uploadTask.ref.getDownloadURL();
                                  setState(() {
                                    _deathCertUrl = url;
                                    _deathCertName = file.name;
                                  });
                                  if (!mounted) return;
                                  messenger.showSnackBar(const SnackBar(content: Text('File uploaded successfully.')));
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(SnackBar(content: Text('Failed to upload file: $e')));
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: Text(_deathCertUrl == null ? 'Upload' : 'Re-upload'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_bookingType == 'cemetery') cemeteryWidget,
                      if (_bookingType == 'cemetery') const SizedBox(height: 16),
                      if (_bookingType == 'ground') groundTimeField,
                      if (_bookingType == 'ground') const SizedBox(height: 16),
                      dateField,
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Reason for Booking',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        onSaved: (value) => _bookingReason = value!,
                        validator: (value) => value!.isEmpty ? 'Please provide a reason' : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: theme.colorScheme.error, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('Booked'),
                          const SizedBox(width: 16),
                          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          const Text('Available'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const FaIcon(
                          FontAwesomeIcons.paperPlane,
                          color: Colors.white,
                        ),
                        label: const Text('Submit Booking'),
                        onPressed: dateBooked ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList(BuildContext context) {
    final user = Provider.of<AuthService>(context).user;

    if (user == null) {
      return const Center(child: Text('Please sign in to see your bookings.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('bookingDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('You have no bookings.'));
        }

        final bookings = snapshot.data!.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: FaIcon(
                  FontAwesomeIcons.calendarCheck,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text('${booking.bookingType} - ${booking.status}'),
                subtitle: Text(
                  '${booking.bookingDate.toLocal()}'.split(' ')[0],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
