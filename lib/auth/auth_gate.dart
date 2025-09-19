import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // User is signed in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/dashboard/home');
          });
          return const SizedBox.shrink(); // Or a loading indicator
        } else {
          // User is not signed in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/auth');
          });
          return const SizedBox.shrink(); // Or a loading indicator
        }
      },
    );
  }
}
