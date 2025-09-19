import 'package:cloud_firestore/cloud_firestore.dart';

class TaxPayment {
  final String id;
  final String userId;
  final String taxType;
  final double amount;
  final DateTime date;
  final String status;

  TaxPayment({
    required this.id,
    required this.userId,
    required this.taxType,
    required this.amount,
    required this.date,
    required this.status,
  });

  factory TaxPayment.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TaxPayment(
      id: doc.id,
      userId: data['userId'] ?? '',
      taxType: data['taxType'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      status: data['status'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'taxType': taxType,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'status': status,
    };
  }
}
