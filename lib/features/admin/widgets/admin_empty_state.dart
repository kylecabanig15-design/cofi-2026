import 'package:flutter/material.dart';
import 'package:cofi/widgets/text_widget.dart';

class AdminEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const AdminEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            TextWidget(
              text: title,
              fontSize: 20,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 8),
            TextWidget(
              text: message,
              fontSize: 14,
              color: Colors.white38,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
