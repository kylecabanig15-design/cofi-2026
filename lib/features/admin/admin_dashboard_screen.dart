import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/cafe/submit_shop_screen.dart';

/// ============================================================================
/// ADMIN DASHBOARD SCREEN (Panel Requirement: RBAC)
/// ============================================================================
/// 
/// This screen is only accessible to users with `isAdmin: true` in their
/// Firestore document. It provides functionality to:
/// 
/// 1. View pending shop submissions (both community and business)
/// 2. Approve or reject shop submissions
/// 3. Distinguish between "Community Added" and "Business Verified" shops
/// 
/// Access Control:
/// - Hidden from regular users
/// - Route guarded in auth_gate.dart
/// - isAdmin flag can only be set via Firebase Console
/// ============================================================================

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isAdminVal = userDoc.data()?['isAdmin'];
      final isAdmin = (isAdminVal == true) || (isAdminVal?.toString().toLowerCase() == 'true');

      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: TextWidget(
            text: 'Access Denied',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              TextWidget(
                text: 'Admin access required',
                fontSize: 18,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 90,
        title: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: 'Admin Center',
                fontSize: 26,
                color: Colors.white,
                isBold: true,
              ),
              TextWidget(
                text: 'Manage & verify coffee community',
                fontSize: 13,
                color: Colors.white54,
              ),
            ],
          ),
        ),
        actions: [
          // Migration Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.construction_rounded, color: Colors.blue, size: 20),
              tooltip: 'Migrate Legacy Shops',
              onPressed: _runLegacyShopMigration,
            ),
          ),
          // Cleanup Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.cleaning_services_rounded, color: Colors.orange, size: 20),
              tooltip: 'Cleanup Firestore',
              onPressed: _showCleanupDialog,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(170),
          child: Column(
            children: [
              // Stats at a Glance
              const SizedBox(height: 8),
              _buildStatsAtAGlance(),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                indicatorWeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                padding: const EdgeInsets.only(left: 10, right: 20),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: primary,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                tabs: [
                  _buildTab('Pending', Icons.pending_actions_rounded),
                  _buildTab('Claims', Icons.assignment_ind_rounded),
                  _buildTab('Verified', Icons.verified_user_rounded),
                  _buildTab('Rejected', Icons.block_flipped),
                  _buildTab('Archive', Icons.history_edu_rounded),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShopList('pending_approval'), // Pending Tab
              _buildClaimsList(status: 'pending'), // Claims Tab
              _buildShopList('approved'),         // Verified Tab
              _buildRejectedCombinedTab(),        // Rejected Tab (Merged)
              _buildArchiveCombinedTab(),         // Archive Tab (Merged)
            ],
          ),
        ),
      ),
    );
  }

  Tab _buildTab(String text, IconData icon) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsAtAGlance() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          _buildStatSummary('Shops', 'pending_approval', Colors.orange, Icons.storefront),
          const SizedBox(width: 16),
          _buildStatSummary('Claims', 'pending', Colors.purpleAccent, Icons.assignment_ind),
        ],
      ),
    );
  }

  Widget _buildStatSummary(String label, String status, Color color, IconData icon) {
    final collection = label == 'Shops' ? 'shops' : 'shop_claims';
    final field = label == 'Shops' ? 'approvalStatus' : 'status';

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collection)
            .where(field, isEqualTo: status)
            .snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: count.toString(),
                      fontSize: 18,
                      color: Colors.white,
                      isBold: true,
                    ),
                    TextWidget(
                      text: 'Pending $label',
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShopList(String approvalStatus) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('approvalStatus', isEqualTo: approvalStatus)
          // Removed orderBy to avoid index requirement for now
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                'Firestore Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            approvalStatus == 'pending_approval'
                ? 'All Caught Up!'
                : approvalStatus == 'approved'
                    ? 'No Verified Shops'
                    : 'No Denied Requests',
            approvalStatus == 'pending_approval'
                ? 'There are no pending submissions to review right now.'
                : 'Your filtered list is currently empty.',
            approvalStatus == 'pending_approval'
                ? Icons.auto_awesome_rounded
                : approvalStatus == 'approved'
                    ? Icons.verified_user_rounded
                    : Icons.history_rounded,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            return _buildShopCard(doc.id, data, approvalStatus);
          },
        );
      },
    );
  }

  Widget _buildShopCard(
      String shopId, Map<String, dynamic> data, String approvalStatus) {
    final name = data['name'] as String? ?? 'Unknown Shop';
    final address = data['address'] as String? ?? 'No address';
    final submissionType = data['submissionType'] as String? ?? 'community';
    final gallery = (data['gallery'] as List?)?.cast<String>() ?? [];
    final imageUrl = gallery.isNotEmpty ? gallery[0] : null;
    final postedAt = data['postedAt'] as Timestamp?;
    final isHidden = data['isHidden'] as bool? ?? false;
    final isVerified = data['isVerified'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const SubmitShopScreen(),
                settings: RouteSettings(
                  arguments: {'editShopId': shopId},
                )),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Image & Basic Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(
                              color: Colors.grey[850],
                              child: Icon(Icons.storefront_rounded,
                                  color: primary.withOpacity(0.5), size: 28),
                            ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextWidget(
                                text: name,
                                fontSize: 17,
                                color: Colors.white,
                                isBold: true,
                              ),
                            ),
                            _buildSubmissionBadge(submissionType),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                color: primary, size: 12),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextWidget(
                                text: address,
                                fontSize: 12,
                                color: Colors.grey[400]!,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (postedAt != null)
                          TextWidget(
                            text: 'Posted ${_formatDate(postedAt.toDate())}',
                            fontSize: 10,
                            color: Colors.white24,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
            ),

            // Bottom Section: Actions or Status
            Padding(
              padding: const EdgeInsets.all(16),
              child: approvalStatus == 'pending_approval'
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _rejectShop(shopId),
                          child: TextWidget(
                            text: 'Reject',
                            fontSize: 14,
                            color: Colors.redAccent.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _approveShop(shopId, submissionType),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : approvalStatus == 'approved'
                      ? Row(
                          children: [
                            _buildStatusIndicator(approvalStatus, isVerified),
                            const Spacer(),
                            // Publish/Unpublish Toggle
                            TextButton.icon(
                              onPressed: () => _togglePublishShop(shopId, isHidden),
                              icon: Icon(
                                isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 14,
                                color: Colors.blueAccent,
                              ),
                              label: Text(
                                isHidden ? 'PUBLISH' : 'UNPUBLISH',
                                style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Archive Button
                            TextButton.icon(
                              onPressed: () => _archiveShop(shopId),
                              icon: const Icon(Icons.archive_rounded, size: 14, color: Colors.orange),
                              label: const Text(
                                'ARCHIVE',
                                style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusIndicator(approvalStatus, isVerified),
                            Row(
                              children: [
                                if (approvalStatus == 'archived')
                                  TextButton.icon(
                                    onPressed: () => _deleteShopPermanently(shopId, name),
                                    icon: const Icon(Icons.delete_forever_rounded, size: 14, color: Colors.redAccent),
                                    label: const Text(
                                      'DELETE',
                                      style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _revertToPending(shopId),
                                  child: const Text('Revert to Pending',
                                      style: TextStyle(fontSize: 12, color: Colors.blue)),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionBadge(String type) {
    final isBusiness = type == 'business';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isBusiness ? Colors.blue.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isBusiness ? Colors.blue.withOpacity(0.3) : Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Text(
        isBusiness ? 'BUSINESS' : 'COMMUNITY',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: isBusiness ? Colors.blue : Colors.amber,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, bool isVerified) {
    Color color = status == 'approved' ? Colors.green : Colors.redAccent;
    IconData icon = status == 'approved' 
        ? (isVerified ? Icons.verified_rounded : Icons.check_circle_outline_rounded)
        : Icons.block_flipped;
        
    return Row(
      children: [
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Text(
          status == 'approved' 
              ? (isVerified ? 'VERIFIED' : 'APPROVED') 
              : status.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _approveShop(String shopId, String submissionType) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'approvalStatus': 'approved',
        'isVerified': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(submissionType == 'business'
                ? 'Shop approved and verified!'
                : 'Community shop approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving shop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectShop(String shopId) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'approvalStatus': 'rejected',
        'isVerified': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop submission rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting shop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revertToPending(String shopId) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'approvalStatus': 'pending_approval',
        'isVerified': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop reverted to pending'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reverting shop: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePublishShop(String shopId, bool currentHiddenStatus) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'isHidden': !currentHiddenStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentHiddenStatus ? 'Shop unpublished (hidden)' : 'Shop published (visible)'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _archiveShop(String shopId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Archive Shop?', style: TextStyle(color: Colors.white)),
        content: const Text('This will hide the shop from public view and move it to the archive.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'approvalStatus': 'archived',
        'isHidden': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shop archived successfully'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteShopPermanently(String shopId, String shopName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('Delete $shopName?', style: const TextStyle(color: Colors.redAccent)),
        content: const Text(
          'CRITICAL ACTION: This will permanently delete this shop and all its data (reviews, products, etc.) from Firestore. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final shopRef = firestore.collection('shops').doc(shopId);

      // Deep Deletion of subcollections
      final subcollections = ['reviews', 'jobs', 'products', 'gallery'];
      for (var sub in subcollections) {
        final docs = await shopRef.collection(sub).get();
        if (docs.docs.isNotEmpty) {
          final batch = firestore.batch();
          for (var doc in docs.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // Finally delete the shop document
      await shopRef.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Shop deleted permanently'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting shop: $e')));
      }
    }
  }

  Widget _buildRejectedCombinedTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('DENIED SHOPS', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .where('approvalStatus', isEqualTo: 'rejected')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No denied shops', style: TextStyle(color: Colors.white10, fontSize: 13)),
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  return _buildShopCard(doc.id, doc.data(), 'rejected');
                },
              );
            },
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('REJECTED CLAIMS', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Expanded(
          child: _buildClaimsList(status: 'rejected', isEmbedded: true),
        ),
      ],
    );
  }

  Widget _buildArchiveCombinedTab() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('ARCHIVED SHOPS', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .where('approvalStatus', isEqualTo: 'archived')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No archived shops', style: TextStyle(color: Colors.white10, fontSize: 13)),
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  return _buildShopCard(doc.id, doc.data(), 'archived');
                },
              );
            },
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('CLAIM HISTORY', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Expanded(
          child: _buildClaimsList(status: 'approved', isEmbedded: true),
        ),
      ],
    );
  }

  Widget _buildClaimsList({String status = 'pending', bool isEmbedded = false}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shop_claims')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText(
                'Firestore Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          if (isEmbedded) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No processed claims', style: TextStyle(color: Colors.white10, fontSize: 13)),
            ));
          }
          return _buildEmptyState(
            status == 'pending' ? 'No Pending Claims' : 'History is Empty',
            status == 'pending' 
                ? 'Great job! You have handled all ownership claims.'
                : 'No processed claims found in this category.',
            status == 'pending' ? Icons.verified_rounded : Icons.folder_off_rounded,
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _buildClaimCard(doc.id, doc.data());
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
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

  Widget _buildClaimCard(String claimId, Map<String, dynamic> data) {
    final shopName = data['shopName'] as String? ?? 'Unknown Shop';
    final claimantEmail = data['claimantEmail'] as String? ?? 'No email';
    final createdAt = data['createdAt'] as Timestamp?;
    final status = data['status'] as String? ?? 'pending';
    final String? idUrl = data['idImageUrl'];
    final String? permitUrl = data['permitImageUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: InkWell(
        onTap: () => _showClaimDetails(claimId, data),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: Colors.purpleAccent, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: shopName,
                          fontSize: 18,
                          color: Colors.white,
                          isBold: true,
                        ),
                        TextWidget(
                          text: 'Requested by $claimantEmail',
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildClaimStatusBadge(status),
                      if (status == 'approved')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () => _deleteArchiveItem(claimId),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_rounded, color: Colors.redAccent, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'REMOVE',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (idUrl != null || permitUrl != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attachment_rounded, size: 14, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text('DOCS ATTACHED',
                              style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  const Spacer(),
                  if (createdAt != null)
                    TextWidget(
                      text: _formatDate(createdAt.toDate()),
                      fontSize: 11,
                      color: Colors.white24,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.redAccent;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showClaimDetails(String claimId, Map<String, dynamic> data) {
    final shopName = data['shopName'] as String? ?? 'Unknown Shop';
    final claimantEmail = data['claimantEmail'] as String? ?? 'No email';
    final legalName = data['businessLegalName'] as String? ?? 'Not provided';
    final role = data['applicantRole'] as String? ?? 'Not provided';
    final docRef = data['verificationDocReference'] as String? ?? 'Not provided';
    final permitUrl = data['permitImageUrl'] as String?;
    final idUrl = data['idImageUrl'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    
    final attestation = data['legalAttestation'] as bool? ?? false;
    final termsAccepted = data['legalTermsAccepted'] as bool? ?? false;
    final dataConsent = data['dataProcessingConsent'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextWidget(
                                    text: 'OWNERSHIP REVIEW',
                                    fontSize: 10,
                                    color: primary,
                                    isBold: true,
                                  ),
                                  const SizedBox(height: 4),
                                  TextWidget(
                                    text: shopName,
                                    fontSize: 26,
                                    color: Colors.white,
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusIndicator(data['status'] ?? 'pending', data['status'] == 'approved'),
                          ],
                        ),
                        const SizedBox(height: 40),
                        
                        _buildReviewSection('Claimant Identity', [
                          _buildDetailRow('Professional Email', claimantEmail),
                          _buildDetailRow('Legal Entity Name', legalName),
                          _buildDetailRow('Applicant Position', role),
                        ]),
                        
                        const SizedBox(height: 32),
                        _buildReviewSection('Evidence & Docs', [
                          _buildDetailRow('Document Reference', docRef),
                          if (permitUrl != null) ...[
                            const SizedBox(height: 12),
                            TextWidget(text: 'Business Permit / BIR COR', fontSize: 12, color: Colors.grey),
                            const SizedBox(height: 8),
                            _buildImagePreview(permitUrl, 'Business Permit'),
                          ],
                          if (idUrl != null) ...[
                            const SizedBox(height: 20),
                            TextWidget(text: 'Representative ID', fontSize: 12, color: Colors.grey),
                            const SizedBox(height: 8),
                            _buildImagePreview(idUrl, 'ID Card'),
                          ],
                          if (permitUrl == null && idUrl == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text('No visual documents provided.', style: TextStyle(color: Colors.amber, fontSize: 13)),
                            ),
                        ]),
                        
                        const SizedBox(height: 32),
                        _buildReviewSection('Legal Compliance', [
                          _buildLegalTag('Authorized Representative', attestation),
                          _buildLegalTag('Terms of Service Accepted', termsAccepted),
                          _buildLegalTag('Data Processing Consent', dataConsent),
                        ]),
                        
                        const SizedBox(height: 120), // Space for buttons
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Actions
            if (data['status'] == 'pending')
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0), const Color(0xFF1A1A1A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.2],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectClaim(claimId);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Reject Claim', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveClaim(claimId, data['shopId'], data['claimantId']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Confirm Approval', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextWidget(
              text: title.toUpperCase(),
              fontSize: 10,
              color: Colors.white24,
              isBold: true,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Divider(color: Colors.white10)),
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(text: label, fontSize: 11, color: Colors.white38),
          const SizedBox(height: 4),
          TextWidget(text: value, fontSize: 15, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildLegalTag(String label, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (value ? Colors.green : Colors.redAccent).withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (value ? Colors.green : Colors.redAccent).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: value ? Colors.green : Colors.redAccent,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(child: TextWidget(text: label, fontSize: 13, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String url, String title) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      url,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          height: 200,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.black54,
                  child: const Center(
                    child: Text('Tap to zoom', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveClaim(String claimId, String? shopId, String? claimantId) async {
    if (shopId == null || claimantId == null) return;
    
    try {
      // ✅ ATOMIC TRANSACTION: Prevents race conditions and ownership hijacking
      final result = await FirebaseFirestore.instance.runTransaction<Map<String, dynamic>>((txn) async {
        // 1. Read shop document
        final shopRef = FirebaseFirestore.instance.collection('shops').doc(shopId);
        final shopSnap = await txn.get(shopRef);
        
        if (!shopSnap.exists) {
          throw Exception('Shop no longer exists');
        }
        
        final shopData = shopSnap.data()!;
        final currentOwnerId = shopData['ownerId'];
        
        // 2. Check if shop already claimed
        if (currentOwnerId != null && currentOwnerId.toString().trim().isNotEmpty) {
          throw Exception('This shop is already claimed by another user');
        }
        
        // 3. Read all pending claims for this shop
        final claimsQuery = await FirebaseFirestore.instance
            .collection('shop_claims')
            .where('shopId', isEqualTo: shopId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        // 4. Approve the selected claim
        final claimRef = FirebaseFirestore.instance.collection('shop_claims').doc(claimId);
        txn.update(claimRef, {
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        });
        
        // 5. Update shop with ownerId
        txn.update(shopRef, {
          'ownerId': claimantId,
          'posterId': claimantId,
          'submissionType': 'business',
          'isVerified': true,
          'approvalStatus': 'approved',
          'transferredAt': FieldValue.serverTimestamp(),
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
        });
        
        // 6. Auto-reject all other pending claims
        for (final claimDoc in claimsQuery.docs) {
          if (claimDoc.id != claimId) {
            txn.update(claimDoc.reference, {
              'status': 'auto_rejected',
              'rejectedReason': 'Another claim was approved for this shop',
              'rejectedAt': FieldValue.serverTimestamp(),
              'rejectedBy': 'system',
            });
          }
        }
        
        return {
          'success': true,
          'rejectedCount': claimsQuery.docs.length - 1,
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim approved! ${result['rejectedCount']} competing claim(s) automatically rejected.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectClaim(String claimId) async {
    try {
      await FirebaseFirestore.instance.collection('shop_claims').doc(claimId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runLegacyShopMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Migrate Legacy Shops', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will add approvalStatus and submissionType fields to all shops missing them.\n\n'
          'Shops with ownerId will be marked as approved business shops.\n'
          'Shops without ownerId will be marked as pending community shops.\n\n'
          'This action is safe and can be run multiple times.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            child: const Text('Run Migration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final allShops = await firestore.collection('shops').get();
      
      int migratedCount = 0;
      int skippedCount = 0;
      final batch = firestore.batch();
      
      for (final doc in allShops.docs) {
        final data = doc.data();
        final hasApprovalStatus = data.containsKey('approvalStatus');
        final hasSubmissionType = data.containsKey('submissionType');
        
        if (!hasApprovalStatus || !hasSubmissionType) {
          final ownerId = data['ownerId'];
          final hasOwner = ownerId != null && ownerId.toString().trim().isNotEmpty;
          
          final migrationData = <String, dynamic>{};
          
          if (!hasApprovalStatus) {
            migrationData['approvalStatus'] = hasOwner ? 'approved' : 'pending_approval';
          }
          
          if (!hasSubmissionType) {
            migrationData['submissionType'] = hasOwner ? 'business' : 'community';
          }
          
          if (hasOwner && !data.containsKey('isVerified')) {
            migrationData['isVerified'] = true;
          }
          
          batch.update(doc.reference, migrationData);
          migratedCount++;
        } else {
          skippedCount++;
        }
      }
      
      await batch.commit();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Migration Complete', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'Total shops: ${allShops.docs.length}\n'
              'Migrated: $migratedCount\n'
              'Already up-to-date: $skippedCount',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteArchiveItem(String claimId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Remove from Archive?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete this claim record from the history.\n'
          'The actual shop ownership will NOT be affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('shop_claims').doc(claimId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record removed from archive'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Firestore Cleanup', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This tool will perform the following actions:\n\n'
          '• Remove "junk" shops (missing name/address)\n'
          '• Remove orphaned reviews/comments from deleted accounts\n\n'
          'This operation is irreversible and may take some time. Proceed with caution.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runCleanup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Run Cleanup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _runCleanup() async {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Scanning Firestore...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final List<CleanupCandidate> candidates = [];
      
      // Cache valid user IDs
      final Map<String, bool> userExistenceCache = {};
      
      // 1. Fetch all shops
      final shopsSnapshot = await firestore.collection('shops').get();
      
      for (final shopDoc in shopsSnapshot.docs) {
        final data = shopDoc.data();
        final name = (data['name'] as String? ?? '').trim();
        final address = (data['address'] as String? ?? '').trim();
        
        // --- JUNK SHOP CHECK ---
        if (name.isEmpty || address.isEmpty || name.length < 3) {
          candidates.add(CleanupCandidate(
            id: shopDoc.id,
            type: 'shop',
            reason: 'Incomplete/Invalid Shop',
            description: name.isEmpty ? 'No Name' : name,
            reference: shopDoc.reference,
          ));
          continue; 
        }
        
        // --- REVIEW CHECK ---
        final reviewsSnapshot = await shopDoc.reference.collection('reviews').get();
        for (final reviewDoc in reviewsSnapshot.docs) {
          final userId = reviewDoc.data()['userId'] as String?;
          final reviewText = reviewDoc.data()['text'] as String? ?? 'No text';
          if (userId != null) {
            if (!userExistenceCache.containsKey(userId)) {
              await _checkUserExists(userId, userExistenceCache);
            }
            if (userExistenceCache[userId] == false) {
              candidates.add(CleanupCandidate(
                id: reviewDoc.id,
                type: 'review',
                reason: 'Deleted Account (Review)',
                description: '"$reviewText"',
                reference: reviewDoc.reference,
              ));
            }
          }
        }
        
        // --- EVENT COMMENT CHECK ---
        final eventsSnapshot = await shopDoc.reference.collection('events').get();
        for (final eventDoc in eventsSnapshot.docs) {
          final commentsSnapshot = await eventDoc.reference.collection('comments').get();
          for (final commentDoc in commentsSnapshot.docs) {
            final userId = commentDoc.data()['userId'] as String?;
            final commentText = commentDoc.data()['text'] as String? ?? 'No text';
            if (userId != null) {
              if (!userExistenceCache.containsKey(userId)) {
                await _checkUserExists(userId, userExistenceCache);
              }
              if (userExistenceCache[userId] == false) {
                candidates.add(CleanupCandidate(
                  id: commentDoc.id,
                  type: 'comment',
                  reason: 'Deleted Account (Comment)',
                  description: '"$commentText"',
                  reference: commentDoc.reference,
                ));
              }
            }
          }
        }
      }
      
      Navigator.pop(context); // Close loading dialog

      if (candidates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Firestore is clean! No junk documents found.')),
          );
        }
      } else {
        _showReviewSheet(candidates);
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReviewSheet(List<CleanupCandidate> candidates) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CLEANUP REVIEW', style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text('${candidates.length} ITEMS FOUND', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final item = candidates[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getTypeColor(item.type).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type), size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(item.description, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0), const Color(0xFF1A1A1A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _executeBatchDelete(candidates);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Confirm Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'shop': return Icons.storefront;
      case 'review': return Icons.star_rate_rounded;
      case 'comment': return Icons.comment_rounded;
      default: return Icons.help;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'shop': return Colors.orange;
      case 'review': return Colors.amber;
      case 'comment': return Colors.blueAccent;
      default: return Colors.grey;
    }
  }

  Future<void> _executeBatchDelete(List<CleanupCandidate> candidates) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.redAccent),
            SizedBox(height: 16),
            Text('Deleting Data...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    try {
      int deleted = 0;
      for (final item in candidates) {
        await item.reference.delete();
        deleted++;
      }
      
      Navigator.pop(context); // Close loading dialog
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully deleted $deleted items.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Deletion failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkUserExists(String userId, Map<String, bool> cache) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      cache[userId] = doc.exists;
    } catch (_) {
      cache[userId] = false; 
    }
  }
}

class CleanupCandidate {
  final String id;
  final String type;
  final String reason;
  final String description;
  final DocumentReference reference;

  CleanupCandidate({
    required this.id,
    required this.type,
    required this.reason,
    required this.description,
    required this.reference,
  });
}
