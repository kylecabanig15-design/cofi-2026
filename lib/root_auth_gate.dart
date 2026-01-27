import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/features/admin/admin_app.dart';
import 'package:cofi/features/business/business_app.dart';
import 'package:cofi/user_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RootAuthGate extends StatelessWidget {
  final String? initializationError;
  const RootAuthGate({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    if (initializationError != null) {
      return UserApp(initializationError: initializationError);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final user = authSnapshot.data;

        // If not logged in, go to UserApp (which handles Onboarding/Login via AuthGate)
        if (user == null) {
          return const UserApp();
        }

        // If logged in, check Firestore for role data
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const MaterialApp(
                home: Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final data = userSnapshot.data?.data();
            final bool isAdmin = data?['isAdmin'] == true;
            final String accountType = data?['accountType'] ?? 'user';

            // 1. Priority: Admin
            if (isAdmin) {
              return const AdminApp();
            }

            // 2. Default: User (includes business accounts, who access dashboard from profile)
            return const UserApp();
          },
        );
      },
    );
  }
}
