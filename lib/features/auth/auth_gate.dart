import 'package:cofi/utils/logger.dart';
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
import 'package:cofi/features/admin/admin_dashboard_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Mutable so onboarding completion can re-evaluate it via setState
  // (a `late final` future would cache the stale result forever).
  Future<bool>? _onboardingFuture;

  // Bumped to force the profile StreamBuilder to re-subscribe (retry).
  int _profileAttempt = 0;

  @override
  void initState() {
    super.initState();
    // Created once so rebuilds don't flip back to the splash screen or
    // re-trigger SharedPreferences reads on every setState.
    _onboardingFuture = _checkOnboardingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingFuture,
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.hasError) {
          debugLog('Onboarding check error: ${onboardingSnapshot.error}');
          return const SplashScreen();
        }

        if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final hasSeenOnboarding = onboardingSnapshot.data ?? false;

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {

            if (snapshot.hasError) {
              debugLog('Auth error: ${snapshot.error}');
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
              debugLog('[AuthGate] authState: signed out');
              // Not signed in -> check if onboarding has been seen
              if (!hasSeenOnboarding) {
                return OnboardingScreen(
                  onOnboardingComplete: _markOnboardingComplete,
                );
              }
              return const LoginScreen();
            }

            debugLog('[AuthGate] authState: signed in uid=${user.uid} '
                'emailVerified=${user.emailVerified}');

            // Signed in -> check if onboarding has been seen
            if (!hasSeenOnboarding) {
              debugLog('[AuthGate] -> onboarding not seen');
              return OnboardingScreen(
                onOnboardingComplete: _markOnboardingComplete,
              );
            }

            // Check if email is verified
            if (!user.emailVerified) {
              debugLog('[AuthGate] -> BLOCKED: emailVerified=false, '
                  'showing LoginScreen even though user is signed in!');
              return const LoginScreen(); // Redirect to login to show verification message
            }

            // Check if user has completed profile setup (accountType and interests)
            return StreamBuilder<DocumentSnapshot>(
              // Key includes the attempt counter so "Retry" re-subscribes
              // with a fresh listener instead of staying stuck on a dead one.
              key: ValueKey('user-doc-${user.uid}-$_profileAttempt'),
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnapshot) {

                debugLog('[AuthGate] profile stream: state='
                    '${userSnapshot.connectionState} '
                    'hasError=${userSnapshot.hasError} '
                    'hasData=${userSnapshot.hasData} '
                    'exists=${userSnapshot.data?.exists}');

                if (userSnapshot.hasError) {
                  debugLog('User profile error: ${userSnapshot.error}');
                  return _buildProfileErrorScreen(
                    context,
                    'Couldn\'t load your profile',
                    '${userSnapshot.error}',
                  );
                }

                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                }

                if (!userSnapshot.hasData || userSnapshot.data == null) {
                  debugLog('User profile doc missing for ${user.uid}, '
                      'fromCache: ${userSnapshot.data?.exists}');
                  return _buildProfileErrorScreen(
                    context,
                    'Profile not found',
                    'Your account profile could not be loaded. '
                        'Please try again.',
                  );
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  debugLog('[AuthGate] profile doc exists but data() is null');
                  return const SplashScreen();
                }

                final bool isAdmin = userData['isAdmin'] == true;

                // 1. Priority: Admin
                if (isAdmin) {
                  debugLog('[AuthGate] -> AdminDashboardScreen');
                  return const AdminDashboardScreen();
                }

                // Check if user has accountType
                final hasAccountType = userData.containsKey('accountType') &&
                    userData['accountType'] != null &&
                    (userData['accountType'] as String?)?.isNotEmpty == true;

                // Check if user has interests (or skipped -> empty list is valid)
                final hasInterests = userData.containsKey('interests') &&
                    userData['interests'] != null;

                // Check if user has commitment
                final hasCommitment = userData.containsKey('commitment') &&
                    userData['commitment'] == true;


                // If missing accountType, go through account type selection
                if (!hasAccountType) {
                  debugLog('[AuthGate] -> AccountTypeSelectionScreen');
                  return const AccountTypeSelectionScreen();
                }

                // If missing commitment, go through community commitment
                if (!hasCommitment) {
                  debugLog('[AuthGate] -> CommunityCommitmentScreen');
                  return const CommunityCommitmentScreen();
                }

                // If missing interests, go through interests selection
                if (!hasInterests) {
                  debugLog('[AuthGate] -> InterestSelectionScreen');
                  return const InterestSelectionScreen();
                }

                // All checks passed -> go home
                debugLog('[AuthGate] -> HomeScreen');
                return const HomeScreen();
              },
            );
          },
        );
      },
    );
  }

  void _markOnboardingComplete() {
    setState(() {
      _onboardingFuture = Future.value(true);
    });
  }

  /// Shown when the profile stream fails or returns nothing, so the user
  /// isn't stuck on a silent splash screen forever. Retry re-subscribes.
  Widget _buildProfileErrorScreen(
      BuildContext context, String title, String detail) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(detail,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => _profileAttempt++),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('hasSeenOnboarding') ?? false;
    } catch (e) {
      debugLog('Error checking onboarding status: $e');
      // If there's an error accessing SharedPreferences, default to false
      return false;
    }
  }
}
