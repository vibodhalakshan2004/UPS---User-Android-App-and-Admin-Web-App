import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String userId;
  final String bookingType;
  final DateTime bookingDate;
  final String bookingReason;
  final String status;
  final String? deathCertificateUrl;
  final String? deathCertificateName;

  Booking({
    required this.id,
    required this.userId,
    required this.bookingType,
    required this.bookingDate,
    required this.bookingReason,
    required this.status,
    this.deathCertificateUrl,
    this.deathCertificateName,
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
      deathCertificateUrl: data['deathCertificateUrl'] as String?,
      deathCertificateName: data['deathCertificateName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bookingType': bookingType,
      'bookingDate': bookingDate,
      'bookingReason': bookingReason,
      'status': status,
      if (deathCertificateUrl != null) 'deathCertificateUrl': deathCertificateUrl,
      if (deathCertificateName != null) 'deathCertificateName': deathCertificateName,
    };
  }
}
