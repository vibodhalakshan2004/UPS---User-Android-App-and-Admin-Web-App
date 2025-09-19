import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String userId;
  final String bookingType;
  final DateTime bookingDate;
  final String bookingReason;
  final String status;

  Booking({
    required this.id,
    required this.userId,
    required this.bookingType,
    required this.bookingDate,
    required this.bookingReason,
    required this.status,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      userId: data['userId'] ?? '',
      bookingType: data['bookingType'] ?? '',
      bookingDate: (data['bookingDate'] as Timestamp).toDate(),
      bookingReason: data['bookingReason'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bookingType': bookingType,
      'bookingDate': bookingDate,
      'bookingReason': bookingReason,
      'status': status,
    };
  }
}
