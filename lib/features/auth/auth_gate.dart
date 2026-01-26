import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofi/features/auth/splash_screen.dart';
import 'package:cofi/features/auth/onboarding_screen.dart';
import 'package:cofi/features/auth/login_screen.dart';
import 'package:cofi/features/auth/account_type_selection_screen.dart';
import 'package:cofi/features/auth/interest_selection_screen.dart';
import 'package:cofi/features/auth/community_commitment_screen.dart';
import 'package:cofi/features/home/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingStatus(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.hasError) {
          print('Onboarding check error: ${onboardingSnapshot.error}');
          return const SplashScreen();
        }

        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final hasSeenOnboarding = onboardingSnapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            print(
                'Auth state: ${snapshot.connectionState}, user: ${snapshot.data?.email}');

            if (snapshot.hasError) {
              print('Auth error: ${snapshot.error}');
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Text('Auth Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white)),
                ),
              );
            }

            // While initializing or waiting for auth state, show splash
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            final user = snapshot.data;
            if (user == null) {
              // Not signed in -> check if onboarding has been seen
              if (!hasSeenOnboarding) {
                return const OnboardingScreen();
              }
              return const LoginScreen();
            }

            // Signed in -> check if onboarding has been seen
            if (!hasSeenOnboarding) {
              return const OnboardingScreen();
            }

            // Check if email is verified
            if (!user.emailVerified) {
              return const LoginScreen(); // Redirect to login to show verification message
            }

            // Check if user has completed profile setup (accountType and interests)
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                print(
                    'User profile snapshot state: ${userSnapshot.connectionState}');

                if (userSnapshot.hasError) {
                  print('User profile error: ${userSnapshot.error}');
                  return const SplashScreen();
                }

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  print('No user profile found');
                  return const SplashScreen();
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  print('User data is null');
                  return const SplashScreen();
                }

                print('User data: $userData');

                // Check if user has accountType
                final hasAccountType = userData.containsKey('accountType') &&
                    userData['accountType'] != null &&
                    (userData['accountType'] as String?)?.isNotEmpty == true;

                // Check if user has interests
                final hasInterests = userData.containsKey('interests') &&
                    userData['interests'] != null &&
                    (userData['interests'] as List?)?.isNotEmpty == true;

                // Check if user has commitment
                final hasCommitment = userData.containsKey('commitment') &&
                    userData['commitment'] == true;

                print('Has account type: $hasAccountType');
                print('Has commitment: $hasCommitment');
                print('Has interests: $hasInterests');

                // If missing accountType, go through account type selection
                if (!hasAccountType) {
                  print('Showing account type selection');
                  return const AccountTypeSelectionScreen();
                }

                // If missing commitment, go through community commitment
                if (!hasCommitment) {
                  print('Showing community commitment');
                  return const CommunityCommitmentScreen();
                }

                // If missing interests, go through interests selection
                if (!hasInterests) {
                  print('Showing interest selection');
                  return const InterestSelectionScreen();
                }

                // All checks passed -> go home
                print('All checks passed, showing home');
                return const HomeScreen();
              },
            );
          },
        );
      },
    );
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasSeenOnboarding') ?? false;
    } catch (e) {
      print('Error checking onboarding status: $e');
      // If there's an error accessing SharedPreferences, default to false
      return false;
    }
  }
}
