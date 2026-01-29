import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/business/shop_verification_sheet.dart';

class ClaimShopScreen extends StatefulWidget {
  const ClaimShopScreen({super.key});

  @override
  State<ClaimShopScreen> createState() => _ClaimShopScreenState();
}

class _ClaimShopScreenState extends State<ClaimShopScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isDirectClaim = false;
  String? _preselectedShopId;
  String? _preselectedShopName;
  bool _isDirectClaimValidating = false;
  String? _directClaimError;
  bool _isVerificationFlow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['preselectShopId'] != null) {
        setState(() {
          _isDirectClaim = true;
          _preselectedShopId = args['preselectShopId'];
          _preselectedShopName = args['preselectShopName'];
          _isVerificationFlow = args['isVerificationFlow'] == true;
          _searchController.text = _preselectedShopName ?? '';
        });
        _validateDirectClaim(args['preselectShopId']);
      }
    });
    _searchShops('');
  }

  Future<void> _validateDirectClaim(String shopId) async {
    setState(() {
      _isDirectClaimValidating = true;
      _directClaimError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance.collection('shops').doc(shopId).get();
      if (!doc.exists) {
        setState(() => _directClaimError = 'Shop not found.');
        return;
      }

      final data = doc.data()!;
      final isVerified = data['isVerified'] == true;
      final ownerId = data['ownerId'];
      final submissionType = data['submissionType']?.toString().toLowerCase();
      final approvalStatus = data['approvalStatus']?.toString().toLowerCase();

      final currentUser = FirebaseAuth.instance.currentUser;
      final isOwner = currentUser != null && ownerId != null && ownerId.toString().trim() == currentUser.uid;

      if (ownerId != null && ownerId.toString().trim().isNotEmpty && !isOwner) {
        setState(() => _directClaimError = 'This shop is already claimed.');
      } else if (submissionType != 'community' && !isOwner) {
        setState(() => _directClaimError = 'This shop cannot be claimed (business submission).');
      } else if (approvalStatus != 'approved' && approvalStatus != 'pending_approval' && approvalStatus != 'pending' && approvalStatus != 'awaiting_verification') {
        setState(() => _directClaimError = 'This shop is not eligible for claiming (Rejected or Invalid status).');
      }
    } catch (e) {
      setState(() => _directClaimError = 'Failed to validate shop: $e');
    } finally {
      setState(() => _isDirectClaimValidating = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchShops(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shops')
          .get();

      final results = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((data) {
            final name = (data['name'] as String?)?.toLowerCase() ?? '';
            final address = (data['address'] as String?)?.toLowerCase() ?? '';
            final searchLower = query.toLowerCase().trim();
            
            final ownerId = data['ownerId'];
            final submissionType = data['submissionType']?.toString().toLowerCase();
            final isVerified = data['isVerified'] == true;
            final approvalStatus = data['approvalStatus']?.toString().toLowerCase();
            
            // Allow claiming of community-added shops that:
            // 1. Have NO ownerId (unclaimed)
            // 2. Are EXPLICITLY 'community' type (not business)
            // 3. Are EXPLICITLY 'approved' by admin
            final isClaimable = (ownerId == null || ownerId.toString().trim().isEmpty) && 
                               (submissionType == 'community') &&
                               (approvalStatus == 'approved' || approvalStatus == 'pending_approval' || approvalStatus == 'pending');

            if (!isClaimable) return false;

            // If query is empty, allow all (will be sorted/limited below)
            if (searchLower.isEmpty) return true;

            return (name.contains(searchLower) || address.contains(searchLower));
          })
          .toList();

      // Sort: Most recent first, then by name
      results.sort((a, b) {
        final aTime = a['postedAt'] as Timestamp?;
        final bTime = b['postedAt'] as Timestamp?;
        
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        
        // If timestamps are missing, prioritize 'community' type as a secondary sort
        final aComm = (a['submissionType']?.toString().toLowerCase() == 'community');
        final bComm = (b['submissionType']?.toString().toLowerCase() == 'community');
        if (aComm && !bComm) return -1;
        if (!aComm && bComm) return 1;
        
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });

      setState(() {
        // Show up to 50 results
        _searchResults = results.take(50).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _showVerificationForm(String shopId, String shopName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => ShopVerificationSheet(
        shopId: shopId,
        shopName: shopName,
        isVerificationFlow: _isVerificationFlow,
      ),
    );
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
          text: _isVerificationFlow ? 'Verify Business' : 'Claim Shop',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isDirectClaim)
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
            
            // Info banner explaining what shops are shown
            if (!_isDirectClaim)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextWidget(
                          text: 'Showing unverified community-added shops. These shops are pending admin approval.',
                          fontSize: 12,
                          color: Colors.white70,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (_searchResults.isNotEmpty && !_isDirectClaim && !_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    TextWidget(
                      text: 'Found ${_searchResults.length} unclaimed shops',
                      fontSize: 13,
                      color: primary,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            
            Expanded(
              child: _isSearching || _isDirectClaimValidating
                  ? const Center(child: CircularProgressIndicator())
                  : _directClaimError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                TextWidget(
                                  text: _directClaimError!,
                                  fontSize: 16,
                                  color: Colors.white70,
                                  align: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : (_isDirectClaim || _searchResults.isNotEmpty)
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: _isDirectClaim ? 1 : _searchResults.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final shop = _isDirectClaim 
                                    ? {'id': _preselectedShopId, 'name': _preselectedShopName, 'address': 'Currently viewing', 'submissionType': 'community'} 
                                    : _searchResults[index];
                                final name = shop['name'] as String? ?? 'Unknown';
                                final address = shop['address'] as String? ?? '';
                                final shopId = shop['id'] as String;

                                return _buildShopResultCard(shop, shopId, name, address);
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: TextWidget(
                                  text: _searchController.text.trim().isEmpty
                                      ? 'Recent unclaimed shops'
                                      : 'No matches found',
                                  fontSize: 16,
                                  color: Colors.white70,
                                  align: TextAlign.center,
                                ),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopResultCard(Map<String, dynamic> shop, String shopId, String name, String address) {
    return GestureDetector(
      onTap: () => _showVerificationForm(shopId, name),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: _isDirectClaim ? Border.all(color: primary.withOpacity(0.5)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_cafe, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: name,
                    fontSize: 16,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextWidget(
                          text: address,
                          fontSize: 14,
                          color: Colors.white70,
                          maxLines: 1,
                        ),
                      ),
                      if (shop['submissionType'] == 'community') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'COMMUNITY',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Verification status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending, color: Colors.orange, size: 10),
                        const SizedBox(width: 4),
                        const Text(
                          'PENDING VERIFICATION',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_user, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}
