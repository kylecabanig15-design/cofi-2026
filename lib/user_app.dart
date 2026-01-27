import 'package:cofi/features/auth/auth_gate.dart';
import 'package:cofi/features/business/business_dashboard_screen.dart';
import 'package:cofi/features/business/business_profile_screen.dart';
import 'package:cofi/features/business/business_screen.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cofi/features/cafe/submit_shop_screen.dart';
import 'package:cofi/features/map/map_view_screen.dart';
import 'package:cofi/features/networking/shared_collection_screen.dart';
import 'package:cofi/features/profile/visited_cafes_screen.dart';
import 'package:cofi/features/profile/your_reviews_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';

class UserApp extends StatelessWidget {
  final String? initializationError;
  const UserApp({super.key, this.initializationError});

  @override
  Widget build(BuildContext context) {
    if (initializationError != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The app failed to start correctly.\n\nError: $initializationError',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
