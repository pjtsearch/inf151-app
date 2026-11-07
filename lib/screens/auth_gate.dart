import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.signedIn,
    required this.signedOut,
    this.anonymous,
  });

  final Widget signedIn;
  final Widget signedOut;
  final Widget? anonymous;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final user = snapshot.data;
      if (user == null) return signedOut;
      if (user.isAnonymous) return anonymous ?? signedOut;
      return signedIn;
    },
  );
}
