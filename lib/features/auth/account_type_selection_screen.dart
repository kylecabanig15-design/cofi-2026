import 'package:cofi/services/google_sign_in_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'signup_screen.dart';

class AccountTypeSelectionScreen extends StatelessWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // Sign out and go back to login
            await GoogleSignInService.signOut();
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              TextWidget(
                text: 'Choose Account Type',
                fontSize: 28,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              TextWidget(
                text: 'Select the type of account you want to create',
                fontSize: 16,
                color: Colors.white70,
              ),
              const SizedBox(height: 48),

              // Normal User Account Card
              _buildAccountTypeCard(
                context: context,
                icon: Icons.person,
                title: 'Normal User',
                description:
                    'Explore cafes, submit shops, write reviews, and discover coffee communities.',
                accountType: 'user',
                color: primary,
              ),

              const SizedBox(height: 24),

              // Business Account Card
              _buildAccountTypeCard(
                context: context,
                icon: Icons.business,
                title: 'Business Account',
                description:
                    'Manage your cafe, post events, list jobs, and engage with customers.',
                accountType: 'business',
                color: const Color(0xFF2563EB), // Blue color for business
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String accountType,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        // Detect if user is Google Sign-In user
        final user = FirebaseAuth.instance.currentUser;
        final isGoogleSignUp =
            user?.providerData.any((p) => p.providerId == 'google.com') ??
                false;

        // Show loading overlay briefly to prevent flash
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (context) => Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SignupScreen(
              accountType: accountType,
              isGoogleSignUp: isGoogleSignUp,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: title,
                    fontSize: 20,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  TextWidget(
                    text: description,
                    fontSize: 14,
                    color: Colors.white70,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[600],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
