import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthResult {
  const AuthResult._(this.success, this.message);

  const AuthResult.success([String? message]) : this._(true, message);
  const AuthResult.failure(String message) : this._(false, message);

  final bool success;
  final String? message;
}

abstract class AuthService extends ChangeNotifier {
  User? get user;
  bool get isReady;

  Future<AuthResult> signInWithEmailAndPassword(String email, String password);
  Future<AuthResult> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
  );

  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthService extends AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance {
    _init();
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  User? _user;
  bool _isReady = false;

  @override
  User? get user => _user;

  @override
  bool get isReady => _isReady;

  @override
  Future<AuthResult> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      notifyListeners();
      return const AuthResult.success('Signed in successfully.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapException(e));
    } catch (e, stack) {
      developer.log('signInWithEmailAndPassword', error: e, stackTrace: stack);
      return const AuthResult.failure('Unable to sign in. Please try again.');
    }
  }

  @override
  Future<AuthResult> signUpWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;

      if (_user != null) {
        await _user!.updateDisplayName(name);
        await _createUserInFirestore(_user!, name, phone);
      }
      notifyListeners();
      return const AuthResult.success('Account created successfully.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapException(e));
    } catch (e, stack) {
      developer.log('signUpWithEmailAndPassword', error: e, stackTrace: stack);
      return const AuthResult.failure('Registration failed. Please try again.');
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      if (!_googleSignIn.supportsAuthenticate()) {
        return const AuthResult.failure('Google sign-in is not supported on this platform.');
      }

      final account = await _googleSignIn.authenticate();
      final googleAuth = account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final firebaseResult = await _auth.signInWithCredential(credential);
      final signedInUser = firebaseResult.user;
      if (signedInUser == null) {
        return const AuthResult.failure('Unable to complete Google sign-in.');
      }

      final userDoc = await _firestore.collection('users').doc(signedInUser.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return const AuthResult.failure(
          'Google account not linked. Register with email first or contact support.',
        );
      }

      _user = signedInUser;
      notifyListeners();
      return const AuthResult.success('Signed in with Google.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapException(e));
    } on GoogleSignInException catch (e, stack) {
      developer.log('google_sign_in', error: e, stackTrace: stack);
      return AuthResult.failure(e.code == GoogleSignInExceptionCode.canceled
          ? 'Google sign-in cancelled.'
          : 'Google sign-in failed. Please try again.');
    } catch (e, stack) {
      developer.log('signInWithGoogle', error: e, stackTrace: stack);
      return const AuthResult.failure('Google sign-in failed. Please try again.');
    }
  }

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthResult.success('Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapException(e));
    } catch (e, stack) {
      developer.log('sendPasswordReset', error: e, stackTrace: stack);
      return const AuthResult.failure('Unable to send reset email. Try again later.');
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> _createUserInFirestore(
    User user,
    String name,
    String phone,
  ) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    await userDoc.set({
      'displayName': name,
      'email': user.email,
      'phone': phone,
      'photoURL': user.photoURL,
      'address': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _mapException(FirebaseAuthException e) {
    developer.log('AuthService error', name: 'FirebaseAuthService', error: e);
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return 'An unknown error occurred. Please try again.';
    }
  }

  void _init() {
    _user = _auth.currentUser;

    _auth.idTokenChanges().listen((user) async {
      _user = user;
      if (user != null && !_isReady) {
        _isReady = true;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('wasLoggedIn', user != null);
      } catch (_) {}
      notifyListeners();
    });

    if (_user != null) {
      _isReady = true;
    } else {
      () async {
        try {
          Duration timeout = const Duration(seconds: 8);
          try {
            final prefs = await SharedPreferences.getInstance();
            final was = prefs.getBool('wasLoggedIn') ?? false;
            if (was) timeout = const Duration(seconds: 12);
          } catch (_) {}
          final restoredUser = await _auth
              .idTokenChanges()
              .where((u) => u != null)
              .first
              .timeout(timeout);
          _user = restoredUser;
        } catch (_) {
        } finally {
          if (!_isReady) {
            _isReady = true;
            notifyListeners();
          }
        }
      }();
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    } catch (e, stack) {
      developer.log('google_sign_in_init', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
