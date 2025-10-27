import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? name;
  final String? phoneNumber;
  final String? photoURL;

  UserModel({
    required this.uid,
    this.email,
    this.name,
    this.phoneNumber,
    this.photoURL,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoURL: data['photoURL'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (name != null) 'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoURL != null) 'photoURL': photoURL,
    };
  }
}
