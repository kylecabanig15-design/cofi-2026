import 'package:cofi/firebase_options.dart';
import 'package:cofi/screens/auth/account_type_selection_screen.dart';
import 'package:cofi/screens/auth/interest_selection_screen.dart';
import 'package:cofi/screens/auth/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofi/screens/auth/splash_screen.dart';
import 'package:cofi/screens/auth/onboarding_screen.dart';
import 'package:cofi/screens/home_screen.dart';
import 'package:cofi/screens/subscreens/cafe_details_screen.dart';
import 'package:cofi/screens/subscreens/your_reviews_screen.dart';
import 'package:cofi/screens/subscreens/visited_cafes_screen.dart';
import 'package:cofi/screens/subscreens/submit_shop_screen.dart';
import 'package:cofi/screens/subscreens/business_screen.dart';
import 'package:cofi/screens/subscreens/business_profile_screen.dart';
import 'package:cofi/screens/subscreens/business_dashboard_screen.dart';
import 'package:cofi/screens/subscreens/map_view_screen.dart';
import 'package:cofi/screens/shared_collection_screen.dart';
import 'package:cofi/utils/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');

    // Configure Firestore for better performance and offline support
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, // Enable offline cache
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB cache
    );

    await GetStorage.init();
    print('GetStorage initialized');
  } catch (e, stack) {
    print('Error during initialization: $e');
    print('Stack: $stack');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cofi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/cafeDetails':
            final args = settings.arguments as Map<String, dynamic>?;
            final shopId = args?['shopId'] as String?;
            return MaterialPageRoute(
              builder: (context) => CafeDetailsScreen(shopId: shopId),
            );
          case '/yourReviews':
            return MaterialPageRoute(
              builder: (context) => const YourReviewsScreen(),
            );
          case '/visitedCafes':
            return MaterialPageRoute(
              builder: (context) => const VisitedCafesScreen(),
            );
          case '/submitShop':
            return MaterialPageRoute(
              builder: (context) => const SubmitShopScreen(),
              settings: settings,
            );
          case '/business':
            return MaterialPageRoute(
              builder: (context) => const BusinessScreen(),
            );
          case '/businessProfile':
            return MaterialPageRoute(
              builder: (context) => const BusinessProfileScreen(),
              settings: settings,
            );
          case '/businessDashboard':
            return MaterialPageRoute(
              builder: (context) => const BusinessDashboardScreen(),
            );
          case '/mapView':
            return MaterialPageRoute(
              builder: (context) => const MapViewScreen(),
            );
          case '/sharedCollection':
            return MaterialPageRoute(
              builder: (context) => const SharedCollectionScreen(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(
                  child: Text('Page not found'),
                ),
              ),
            );
        }
      },
    );
  }
}

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
            print('Auth state: ${snapshot.connectionState}, user: ${snapshot.data?.email}');
            
            if (snapshot.hasError) {
              print('Auth error: ${snapshot.error}');
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Text('Auth Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
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
                print('User profile snapshot state: ${userSnapshot.connectionState}');
                
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

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                
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

                print('Has account type: $hasAccountType');
                print('Has interests: $hasInterests');

                // If missing accountType, go through account type selection
                if (!hasAccountType) {
                  print('Showing account type selection');
                  return const AccountTypeSelectionScreen();
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
