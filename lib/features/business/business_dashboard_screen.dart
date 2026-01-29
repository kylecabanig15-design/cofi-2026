import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/business/claim_shop_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: TextWidget(
            text: 'Business Dashboard',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
        ),
        body: const Center(
          child: Text('Please sign in', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('posterId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // If user has shops, show first shop management
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final shop = snapshot.data!.docs.first;
          final shopId = shop.id;
          final shopData = shop.data();
          final isVerified = shopData['isVerified'] == true;

          // Only show dashboard if shop is verified.
          // Otherwise, treat as if no shop (to allow claiming/submitting new one).
          if (isVerified) {
            return _buildDashboardContent(context, shopData, shopId);
          } else if (shopData['approvalStatus'] == 'awaiting_verification') {
            return _buildPendingReviewScreen(context, shopData);
          }
        }

        // If loading, show loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
              centerTitle: true,
              title: TextWidget(
                text: 'Business Dashboard',
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          );
        }

        // If no shops (or no verified shops), show Get Started screen
        return _buildGetStartedScreen(context);
      },
    );
  }

  Widget _buildDashboardContent(BuildContext context, Map<String, dynamic> shopData, String shopId) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Business Dashboard',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 32),
              TextWidget(
                text: shopData['name'] ?? 'Your Shop',
                fontSize: 24,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              TextWidget(
                text: 'Shop ID: $shopId',
                fontSize: 12,
                color: Colors.white54,
              ),
              const SizedBox(height: 32),
              TextWidget(
                text: 'Management',
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 16),
              // Add management options here
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingReviewScreen(BuildContext context, Map<String, dynamic> shopData) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Business Dashboard',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.blueAccent, size: 64),
              ),
              const SizedBox(height: 32),
              TextWidget(
                text: 'Verification in Progress',
                fontSize: 24,
                color: Colors.white,
                isBold: true,
                align: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextWidget(
                text: 'Your shop "${shopData['name']}" has been submitted for verification. Features will unlock once an admin approves your request.',
                fontSize: 14,
                color: Colors.white70,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Business Dashboard',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
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
                text: 'Get Started',
                fontSize: 24,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              TextWidget(
                text: 'Choose how you want to add your business to CoFi',
                fontSize: 16,
                color: Colors.white70,
              ),
              const SizedBox(height: 40),

              // Claim Existing Shop
              _buildOptionCard(
                context: context,
                icon: Icons.search,
                title: 'Claim Existing Shop',
                description:
                    'Find and claim your shop if it\'s already listed in CoFi. Requires Admin Approval.',
                color: primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ClaimShopScreen()),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Submit New Shop
              _buildOptionCard(
                context: context,
                icon: Icons.add_business,
                title: 'Submit New Shop',
                description: 'Add your cafe to CoFi and start managing it',
                color: primary,
                onTap: () {
                  Navigator.pushNamed(context, '/submitShop');
                },
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
                    fontSize: 18,
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
