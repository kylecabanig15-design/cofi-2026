import 'package:cofi/features/admin/admin_dashboard_screen.dart';
import 'package:cofi/utils/app_theme.dart';
import 'package:flutter/material.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoFi Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AdminDashboardScreen(),
    );
  }
}
