import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;

  User? get user => _user;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      _errorMessage = null;
      notifyListeners();
    });
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      _user = userCredential.user;

      if (_user != null) {
        await _user!.updateDisplayName(name);
        await _createUserInFirestore(_user!, name, phone);
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthException(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> _createUserInFirestore(
    User user,
    String name,
    String phone,
  ) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': name,
      'phone': phone,
      'photoURL': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No user found for that email.';
        break;
      case 'wrong-password':
        _errorMessage = 'Wrong password provided.';
        break;
      case 'invalid-email':
        _errorMessage = 'The email address is not valid.';
        break;
      case 'email-already-in-use':
        _errorMessage = 'An account already exists for that email.';
        break;
      case 'weak-password':
        _errorMessage = 'The password provided is too weak.';
        break;
      default:
        _errorMessage = 'An unknown error occurred. Please try again.';
    }
    developer.log(_errorMessage!, name: 'AuthService', error: e);
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }
}
