import 'package:cofi/features/business/business_dashboard_screen.dart';
import 'package:cofi/features/business/claim_shop_screen.dart';
import 'package:cofi/features/cafe/submit_shop_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';

class BusinessApp extends StatelessWidget {
  const BusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoFi Business',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        useMaterial3: true,
      ),
      home: const BusinessDashboardScreen(),
      onGenerateRoute: (settings) {
        if (settings.name == '/submitShop') {
          return MaterialPageRoute(
            builder: (context) => const SubmitShopScreen(),
            settings: settings,
          );
        }
        if (settings.name == '/claimShop') {
          return MaterialPageRoute(
            builder: (context) => const ClaimShopScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
