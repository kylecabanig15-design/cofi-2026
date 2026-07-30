import 'package:cofi/widgets/my_events_bottom_sheet.dart';
import 'package:cofi/widgets/my_jobs_bottom_sheet.dart';
import 'package:cofi/widgets/post_job_bottom_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/post_event_bottom_sheet.dart';
import 'package:cofi/features/events/event_archives_screen.dart';
import 'package:cofi/features/jobs/job_archives_screen.dart';
import 'package:cofi/features/cafe/reviews_screen.dart';
import 'package:cofi/features/jobs/job_chat_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cofi/features/business/shop_verification_sheet.dart';

import 'package:cofi/features/business/widgets/job_applications_sheet.dart';

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final Map<String, dynamic>? shop =
        args is Map<String, dynamic> ? args : null;
    final String shopName =
        (shop?['name'] as String?)?.trim().isNotEmpty == true
            ? (shop!['name'] as String)
            : 'My Shop';
    final String? shopId =
        (shop?['id'] is String && (shop?['id'] as String).trim().isNotEmpty)
            ? shop!['id'] as String
            : null;

    if (shopId == null || shopId.isEmpty) {
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
            text: 'My Business',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
        ),
        body: Center(
          child: TextWidget(
            text: 'No shop data available. Please try again.',
            fontSize: 16,
            color: Colors.grey[400],
          ),
        ),
      );
    }

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
          text: 'My Business',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('shops').doc(shopId).snapshots(),
          builder: (context, snapshot) {
            final shopData = snapshot.data?.data();
            final logoUrl = shopData?['logoUrl'] as String?;
             final isVerified = (shopData?['isVerified'] as bool?) ?? false;
             final approvalStatus = shopData?['approvalStatus'] as String? ?? '';
            final opacity = isVerified ? 1.0 : 0.5;
             return Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24),
               child: SingleChildScrollView(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const SizedBox(height: 24),

                     // Business Profile Card
                     _buildBusinessProfileCard(
                       context,
                       shopName,
                       shopId,
                       logoUrl,
                       isVerified,
                     ),

                     // VERIFICATION WARNING BANNER
                     if (!isVerified)
                       GestureDetector(
                         onTap: () {
                           if (approvalStatus == 'awaiting_verification') {
                             showModalBottomSheet(
                               context: context,
                               isScrollControlled: true,
                               backgroundColor: Colors.transparent,
                               enableDrag: true,
                               builder: (context) => ShopVerificationSheet(
                                 shopId: shopId,
                                 shopName: shopName,
                                 isVerificationFlow: true,
                               ),
                             );
                           }
                         },
                         child: Container(
                           margin: const EdgeInsets.only(top: 24),
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.orange.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: Colors.orange.withOpacity(0.5)),
                           ),
                           child: Row(
                             children: [
                               const Icon(Icons.info_outline, color: Colors.orange, size: 24),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     TextWidget(
                                       text: approvalStatus == 'awaiting_verification' 
                                           ? 'Requirements Missing (Tap to Upload)' 
                                           : 'Pending Verification',
                                       fontSize: 16,
                                       color: Colors.orange,
                                       isBold: true,
                                     ),
                                     const SizedBox(height: 4),
                                     TextWidget(
                                       text: approvalStatus == 'awaiting_verification'
                                           ? 'Please finish your setup by uploading the required business documents.'
                                           : 'Your shop is currently being reviewed. Management features will be enabled once verified.',
                                       fontSize: 13,
                                       color: Colors.white70,
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),

                    const SizedBox(height: 24),
                    TextWidget(
                      text: 'Dashboard',
                      fontSize: 20,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        // Row 1: Reviews - Post an Event
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                final fallback = (shopData?['reviews'] as List?) ?? const [];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReviewsScreen(
                                      shopId: shopId,
                                      fallbackReviews: fallback,
                                    ),
                                  ),
                                );
                              },
                              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                stream: FirebaseFirestore.instance
                                    .collection('shops')
                                    .doc(shopId)
                                    .collection('reviews')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  final count = snapshot.data?.docs.length ?? 0;
                                  final subtitle = count == 0 ? 'No reviews yet' : '$count Reviews';
                                  return _buildSectionCard(
                                    title: 'Reviews',
                                    subtitle: subtitle,
                                    icon: Icons.star_rounded,
                                    color: Colors.orangeAccent,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                PostEventBottomSheet.show(context, shopId: shopId);
                              },
                              child: _buildSectionCard(
                                title: 'Post an Event',
                                subtitle: 'List my upcoming events',
                                icon: Icons.event_available_rounded,
                                color: Colors.purpleAccent,
                              ),
                            ),
                          ),
                        ),
                        // Row 2: Events - Event Archives
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                MyEventsBottomSheet.show(context, shopId: shopId);
                              },
                              child: _buildSectionCard(
                                title: 'Events',
                                subtitle: 'Show Events',
                                icon: Icons.event_note_rounded,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EventArchivesScreen(
                                      shopId: shopId,
                                    ),
                                  ),
                                );
                              },
                              child: _buildSectionCard(
                                title: 'Event Archives',
                                subtitle: 'View past events',
                                icon: Icons.archive_rounded,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        // Row 3: Post a Job - My Jobs
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                PostJobBottomSheet.show(context, shopId: shopId);
                              },
                              child: _buildSectionCard(
                                title: 'Post a Job',
                                subtitle: 'List a job - find staff fast',
                                icon: Icons.work_rounded,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                MyJobsBottomSheet.show(context, shopId: shopId);
                              },
                              child: _buildSectionCard(
                                title: 'My Jobs',
                                subtitle: 'View my submitted jobs',
                                icon: Icons.cases_rounded,
                                color: Colors.tealAccent,
                              ),
                            ),
                          ),
                        ),
                        // Row 4: Applications - Job Archives
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                _showJobApplicationsBottomSheet(context, shopId);
                              },
                              child: StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('shops')
                                    .doc(shopId)
                                    .collection('jobs')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  int totalApplications = 0;
                                  if (snapshot.hasData) {
                                    for (var doc in snapshot.data!.docs) {
                                      final applications = doc['applications'] as List? ?? [];
                                      totalApplications += applications.length;
                                    }
                                  }
                                  final subtitle = totalApplications == 0 ? 'No applications yet' : '$totalApplications Applications';
                                  return _buildSectionCard(
                                    title: 'Applications',
                                    subtitle: subtitle,
                                    icon: Icons.people_alt_rounded,
                                    color: Colors.indigoAccent,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 32,
                          child: Opacity(
                            opacity: opacity,
                            child: GestureDetector(
                              onTap: !isVerified ? () => _showLockedSnakbar(context) : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobArchivesScreen(
                                      shopId: shopId,
                                    ),
                                  ),
                                );
                              },
                              child: _buildSectionCard(
                                title: 'Job Archives',
                                subtitle: 'View archived jobs',
                                icon: Icons.inventory_2_rounded,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBusinessProfileCard(
    BuildContext context,
    String shopName,
    String? shopId,
    String? logoUrl,
    bool? isVerified,
  ) {
    return GestureDetector(
      onTap: () {
        if (shopId != null && shopId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/submitShop',
            arguments: {'editShopId': shopId},
          );
        } else {
          Navigator.pushNamed(context, '/submitShop');
        }
      },
      child: Row(
        children: [
          // Business Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_cafe,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_cafe,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_cafe,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Business Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextWidget(
                      text: shopName,
                      fontSize: 18,
                      color: Colors.white,
                      isBold: true,
                    ),
                    if (isVerified != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        isVerified ? Icons.verified : Icons.pending,
                        color: isVerified ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                TextWidget(
                  text: isVerified == false
                      ? 'Shop is under verification'
                      : 'Tap to Manage profile',
                  fontSize: 14,
                  color:
                      isVerified == false ? Colors.orange : Colors.grey[400]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.4),
                      color.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextWidget(
            text: title,
            fontSize: 16,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 4),
          TextWidget(
            text: subtitle,
            fontSize: 13,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  void _showLockedSnakbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification Required: This feature will be enabled once your shop is verified by an admin.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showJobApplicationsBottomSheet(BuildContext context, String shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JobApplicationsBottomSheet(shopId: shopId),
    );
  }


}

// JobApplicationsBottomSheet moved to lib/features/business/widgets/job_applications_sheet.dart

