import 'package:cofi/features/admin/admin_dashboard_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoFi Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        useMaterial3: true,
      ),
      home: const AdminDashboardScreen(),
    );
  }
}
