import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum HomeActivityType { booking, complaint }

class HomeActivityEvent {
  const HomeActivityEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });

  final String id;
  final HomeActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
}

class HomeActivityService {
  HomeActivityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<HomeActivityEvent>> streamForUser(String userId) {
    final controller = StreamController<List<HomeActivityEvent>>.broadcast();
    final buckets = <HomeActivityType, List<HomeActivityEvent>>{};
    var isClosed = false;

    void emit() {
      if (isClosed) return;
      final merged = buckets.values.expand((events) => events).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(merged.take(12).toList());
    }

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? bookingsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? complaintsSub;

    bookingsSub = _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      buckets[HomeActivityType.booking] = snapshot.docs
          .map(_bookingEventFromDoc)
          .whereType<HomeActivityEvent>()
          .toList();
      emit();
    }, onError: controller.addError);

    complaintsSub = _firestore
        .collection('complaints')
        .where('uid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      buckets[HomeActivityType.complaint] = snapshot.docs
          .map(_complaintEventFromDoc)
          .whereType<HomeActivityEvent>()
          .toList();
      emit();
    }, onError: controller.addError);

    controller
      ..onListen = () {
        controller.add(const []);
      }
      ..onCancel = () async {
        isClosed = true;
        await bookingsSub?.cancel();
        await complaintsSub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      };

    return controller.stream;
  }

  HomeActivityEvent? _bookingEventFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = (data['bookingDate'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final status = (data['status'] as String?)?.toLowerCase().trim() ??
        'pending';
    final rawType = (data['bookingType'] as String?)?.toLowerCase().trim() ??
        'ground';
    final reason = (data['bookingReason'] as String?)?.trim() ?? '';

    final title = switch (status) {
      'approved' => 'Booking confirmed',
      'rejected' => 'Booking declined',
      'cancelled' => 'Booking cancelled',
      _ => 'Booking submitted',
    };

    final subtitleParts = <String>[];
    final typeLabel = _bookingTypeLabel(rawType);
    if (typeLabel != null) subtitleParts.add(typeLabel);

    final dateLabel = DateFormat('MMM d, yyyy').format(timestamp);
    subtitleParts.add(dateLabel);

    final trimmedReason = reason.isEmpty
        ? null
        : (reason.length > 60 ? '${reason.substring(0, 57)}…' : reason);
    if (trimmedReason != null) {
      subtitleParts.add(trimmedReason);
    }

    final statusLabel = _bookingStatusLabel(status);
    if (statusLabel != null) subtitleParts.add(statusLabel);

    return HomeActivityEvent(
      id: doc.id,
      type: HomeActivityType.booking,
      title: title,
      subtitle: subtitleParts.join(' • '),
      timestamp: timestamp,
    );
  }

  HomeActivityEvent? _complaintEventFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    final status = (data['status'] as String?)?.toLowerCase().trim() ?? 'open';
    final type = (data['type'] as String?)?.toLowerCase().trim() ?? 'other';
    final subject = (data['subject'] as String?)?.trim();
    final lampNumber = (data['lampNumber'] as String?)?.trim();

    final title = switch (status) {
      'resolved' || 'closed' || 'completed' => 'Complaint resolved',
      'in_progress' || 'in-progress' => 'Complaint in progress',
      'review' => 'Complaint under review',
      _ => 'Complaint submitted',
    };

    final subtitleParts = <String>[];
    if (type == 'street_lamp') {
      subtitleParts.add(
        lampNumber != null && lampNumber.isNotEmpty
            ? 'Street lamp #$lampNumber'
            : 'Street lamp issue',
      );
    } else if (subject != null && subject.isNotEmpty) {
      subtitleParts.add(subject);
    } else {
      subtitleParts.add('General complaint');
    }

    subtitleParts.add(DateFormat('MMM d, yyyy').format(createdAt));

    final statusLabel = _complaintStatusLabel(status);
    if (statusLabel != null) subtitleParts.add(statusLabel);

    return HomeActivityEvent(
      id: doc.id,
      type: HomeActivityType.complaint,
      title: title,
      subtitle: subtitleParts.join(' • '),
      timestamp: createdAt,
    );
  }

  String? _bookingTypeLabel(String? raw) {
    return switch (raw) {
      'cemetery' => 'Cemetery booking',
      'ground' => 'Ground booking',
      null => null,
  _ => raw.isEmpty ? null : raw[0].toUpperCase() + raw.substring(1),
    };
  }

  String? _bookingStatusLabel(String status) {
    return switch (status) {
      'approved' => 'Approved',
      'pending' => 'Pending approval',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => null,
    };
  }

  String? _complaintStatusLabel(String status) {
    return switch (status) {
      'open' => 'Open',
      'in_progress' || 'in-progress' => 'In progress',
      'review' => 'Under review',
      'resolved' || 'closed' || 'completed' => 'Resolved',
      _ => null,
    };
  }
}
