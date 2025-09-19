import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../models/booking_model.dart';
import '../../auth/auth_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  String _bookingType = 'general';
  DateTime _selectedDate = DateTime.now();
  String _bookingReason = '';

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
          _bookingType = 'general';
          _selectedDate = DateTime.now();
          _bookingReason = '';
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
                    value: 'general',
                    child: Text('General Waste'),
                  ),
                  DropdownMenuItem(
                    value: 'recycling',
                    child: Text('Recycling'),
                  ),
                  DropdownMenuItem(value: 'large', child: Text('Large Items')),
                ],
                onChanged: (value) {
                  setState(() {
                    _bookingType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reason for Booking',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onSaved: (value) => _bookingReason = value!,
                validator: (value) =>
                    value!.isEmpty ? 'Please provide a reason' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const FaIcon(
                  FontAwesomeIcons.paperPlane,
                  color: Colors.white,
                ),
                label: const Text('Submit Booking'),
                onPressed: _submitBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
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
