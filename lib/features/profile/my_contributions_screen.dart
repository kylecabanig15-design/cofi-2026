import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:intl/intl.dart';

class MyContributionsScreen extends StatelessWidget {
  const MyContributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextWidget(
          text: 'My Contributions',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/submitShop'),
            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where(Filter.or(
              Filter('posterId', isEqualTo: user.uid),
              Filter('postedBy.uid', isEqualTo: user.uid),
            ))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: TextWidget(
                  text: 'Error loading contributions: ${snapshot.error}',
                  fontSize: 14,
                  color: Colors.redAccent,
                  align: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _buildContributionCard(context, doc);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          TextWidget(
            text: 'No contributions yet',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          TextWidget(
            text: 'Discover a great café? Add it to CoFi!',
            fontSize: 14,
            color: Colors.white54,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/submitShop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Add My First Cafe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = data['name'] ?? 'Unknown Cafe';
    final approvalStatus = data['approvalStatus'] as String? ?? 'pending_approval';
    final isHidden = data['isHidden'] as bool? ?? false;
    final postedAt = data['postedAt'] as Timestamp?;
    final submissionType = data['submissionType'] as String? ?? 'community';
    
    labelData status = _getStatusData(approvalStatus, isHidden);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (approvalStatus == 'approved') {
            if (submissionType == 'business') {
              Navigator.pushNamed(context, '/businessProfile', arguments: {
                'id': doc.id,
                'name': name,
              });
            } else {
              Navigator.pushNamed(context, '/cafeDetails', arguments: {
                'shopId': doc.id,
              });
            }
          } else {
            // Show status explanation
            _showStatusInfo(context, name, status, approvalStatus, isHidden);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: status.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(status.icon, color: status.color, size: 28),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: status.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status.label.toUpperCase(),
                            style: TextStyle(
                              color: status.color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (postedAt != null)
                          Text(
                            DateFormat('MMM dd, yyyy').format(postedAt.toDate()),
                            style: const TextStyle(color: Colors.white24, fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusInfo(BuildContext context, String name, labelData status, String approvalStatus, bool isHidden) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(status.icon, color: status.color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: TextWidget(
                text: status.label,
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              text: 'Shop: $name',
              fontSize: 14,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            TextWidget(
              text: approvalStatus == 'approved' && isHidden
                  ? 'Your shop is verified but currently set to unpublished. It won\'t appear in the Explore feed.'
                  : approvalStatus == 'rejected'
                      ? 'Unfortunately, this submission didn\'t meet our community criteria. You can try submitting another one if you have more information.'
                      : approvalStatus == 'archived'
                          ? 'This café has been archived by the admin and is no longer discoverable.'
                          : 'Our team is currently verifying this discovery. Submissions are usually processed within 24 hours!',
              fontSize: 14,
              color: Colors.white60,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  labelData _getStatusData(String status, bool isHidden) {
    if (status == 'approved') {
      if (isHidden) {
        return labelData(
          label: 'Unpublished',
          icon: Icons.visibility_off,
          color: Colors.blueAccent,
        );
      }
      return labelData(
        label: 'Published',
        icon: Icons.check_circle,
        color: Colors.green,
      );
    } else if (status == 'rejected') {
      return labelData(
        label: 'Rejected',
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
    } else if (status == 'archived') {
      return labelData(
        label: 'Archived',
        icon: Icons.archive_outlined,
        color: Colors.orange,
      );
    } else {
      return labelData(
        label: 'Pending',
        icon: Icons.hourglass_empty,
        color: Colors.amber,
      );
    }
  }
}

class labelData {
  final String label;
  final IconData icon;
  final Color color;

  labelData({required this.label, required this.icon, required this.color});
}
