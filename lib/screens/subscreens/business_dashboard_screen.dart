import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/colors.dart';
import '../../widgets/text_widget.dart';

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

        // If no shops, show Get Started screen
        return _buildGetStartedScreen(context);
      },
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
                title: 'Claim Existing Shop (Upcoming Soon)',
                description:
                    'Find and claim your shop if it\'s already listed in CoFi',
                color: Colors.grey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('This feature is coming soon!'),
                    ),
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

// Claim Shop Screen
class ClaimShopScreen extends StatefulWidget {
  const ClaimShopScreen({super.key});

  @override
  State<ClaimShopScreen> createState() => _ClaimShopScreenState();
}

class _ClaimShopScreenState extends State<ClaimShopScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchShops(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Search for verified shops without a posterId (unclaimed)
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .get();

      final results = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            final address = (data['address'] as String?)?.toLowerCase() ?? '';
            final searchLower = query.toLowerCase();

            return (name.contains(searchLower) ||
                address.contains(searchLower));
          })
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      print(results.length);

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  Future<void> _claimShop(String shopId, String shopName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Claim Shop',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Do you want to claim "$shopName"? You will need to verify ownership.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Claim'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update shop with posterId
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'posterId': user.uid,
        'postedBy': {
          'uid': user.uid,
          'displayName': user.displayName,
          'email': user.email,
        },
        'claimedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop claimed successfully! You can now manage it.'),
          ),
        );
        Navigator.pop(context); // Go back to business dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to claim shop: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          text: 'Claim Shop',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search for your shop...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onChanged: _searchShops,
                ),
              ),
            ),

            // Search Results
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: TextWidget(
                              text: _searchController.text.trim().isEmpty
                                  ? 'Search for your shop by name or address'
                                  : 'No unclaimed shops found',
                              fontSize: 16,
                              color: Colors.white70,
                              align: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final shop = _searchResults[index];
                            final name = shop['name'] as String? ?? 'Unknown';
                            final address = shop['address'] as String? ?? '';
                            final shopId = shop['id'] as String;

                            return GestureDetector(
                              onTap: () => _claimShop(shopId, name),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.local_cafe,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextWidget(
                                            text: name,
                                            fontSize: 16,
                                            color: Colors.white,
                                            isBold: true,
                                          ),
                                          if (address.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            TextWidget(
                                              text: address,
                                              fontSize: 14,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white54,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
