import 'package:cofi/widgets/my_events_bottom_sheet.dart';
import 'package:cofi/widgets/my_jobs_bottom_sheet.dart';
import 'package:cofi/widgets/post_job_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/post_event_bottom_sheet.dart';
import 'package:cofi/widgets/post_promotion_bottom_sheet.dart';
import 'package:cofi/widgets/my_promotions_bottom_sheet.dart';
import 'package:cofi/features/events/event_archives_screen.dart';
import 'package:cofi/features/jobs/job_archives_screen.dart';
import 'package:cofi/features/cafe/reviews_screen.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/business/shop_verification_sheet.dart';

import 'package:cofi/features/business/widgets/job_applications_sheet.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/widgets/custom_toast.dart';

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
        backgroundColor: BusinessWorkspaceColors.canvas,
        appBar: AppBar(
          backgroundColor: BusinessWorkspaceColors.canvas,
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
      backgroundColor: BusinessWorkspaceColors.canvas,
      appBar: AppBar(
        backgroundColor: BusinessWorkspaceColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Owner workspace',
          fontSize: 18,
          color: BusinessWorkspaceColors.paper,
          isBold: true,
        ),
        actions: const [],
      ),
      body: BusinessWorkspaceTheme(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .snapshots(),
            builder: (context, snapshot) {
              final shopData = snapshot.data?.data();
              final logoUrl = shopData?['logoUrl'] as String?;
              final isVerified = (shopData?['isVerified'] as bool?) ?? false;
              final approvalStatus =
                  shopData?['approvalStatus'] as String? ?? '';
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
                        shopData,
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
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: Colors.orange, size: 24),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextWidget(
                                        text: approvalStatus ==
                                                'awaiting_verification'
                                            ? 'Requirements Missing (Tap to Upload)'
                                            : 'Pending Verification',
                                        fontSize: 16,
                                        color: Colors.orange,
                                        isBold: true,
                                      ),
                                      const SizedBox(height: 4),
                                      TextWidget(
                                        text: approvalStatus ==
                                                'awaiting_verification'
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
                        text: 'Run your café',
                        fontSize: 24,
                        color: BusinessWorkspaceColors.paper,
                        isBold: true,
                      ),
                      const SizedBox(height: 4),
                      TextWidget(
                        text:
                            'Your customer touchpoints, organized by workflow.',
                        fontSize: 14,
                        color: BusinessWorkspaceColors.muted,
                      ),
                      const SizedBox(height: 22),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: _buildGroupHeader(
                              'Overview',
                              'Customer activity and feedback',
                              Icons.insights_rounded,
                            ),
                          ),
                          // Row 1: Reviews - Post an Event
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 32,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        final fallback =
                                            (shopData?['reviews'] as List?) ??
                                                const [];
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
                                child: StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId)
                                      .collection('reviews')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    final count =
                                        snapshot.data?.docs.length ?? 0;
                                    final subtitle = count == 0
                                        ? 'No reviews yet'
                                        : '$count Reviews';
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
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/submitShop',
                                  arguments: {'editShopId': shopId},
                                ),
                                child: _buildSectionCard(
                                  title: 'Shop Profile',
                                  subtitle: 'Update details and photos',
                                  icon: Icons.storefront_rounded,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: _buildGroupHeader(
                              'Events',
                              'Create, manage, and review event history',
                              Icons.event_rounded,
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 32,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        PostEventBottomSheet.show(context,
                                            shopId: shopId);
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
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        MyEventsBottomSheet.show(context,
                                            shopId: shopId);
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
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EventArchivesScreen(
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
                          // Promotions are paired: creation and lifecycle management.
                          SizedBox(
                            width: double.infinity,
                            child: _buildGroupHeader(
                              'Special offers',
                              'Publish timely reasons for customers to visit',
                              Icons.local_offer_rounded,
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 32,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () => PostPromotionBottomSheet.show(
                                          context,
                                          shopId: shopId,
                                          shopName: shopName,
                                        ),
                                child: _buildSectionCard(
                                  title: 'Create Offer',
                                  subtitle: 'Publish a special offer',
                                  icon: Icons.add_card_rounded,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 32,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () => MyPromotionsBottomSheet.show(
                                          context,
                                          shopId: shopId,
                                          shopName: shopName,
                                        ),
                                child: _buildSectionCard(
                                  title: 'My Offers',
                                  subtitle: 'Edit, pause, or publish',
                                  icon: Icons.local_offer_rounded,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                            ),
                          ),
                          // Jobs
                          SizedBox(
                            width: double.infinity,
                            child: _buildGroupHeader(
                              'Hiring',
                              'Post roles and manage incoming applicants',
                              Icons.work_rounded,
                            ),
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2 - 32,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        PostJobBottomSheet.show(context,
                                            shopId: shopId);
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
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        MyJobsBottomSheet.show(context,
                                            shopId: shopId);
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
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        _showJobApplicationsBottomSheet(
                                            context, shopId);
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
                                        final applications =
                                            doc['applications'] as List? ?? [];
                                        totalApplications +=
                                            applications.length;
                                      }
                                    }
                                    final subtitle = totalApplications == 0
                                        ? 'No applications yet'
                                        : '$totalApplications Applications';
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
                                onTap: !isVerified
                                    ? () => _showLockedSnakbar(context)
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                JobArchivesScreen(
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
      ),
    );
  }

  Widget _buildBusinessProfileCard(
    BuildContext context,
    Map<String, dynamic>? shopData,
    String shopName,
    String? shopId,
    String? logoUrl,
    bool? isVerified,
  ) {
    return GestureDetector(
      onTap: () {
        if (shopId != null && shopId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CafeDetailsScreen(
                shopId: shopId,
                shop: shopData,
              ),
            ),
          );
        } else {
          Navigator.pushNamed(context, '/submitShop');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A211A), Color(0xFF15120F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: BusinessWorkspaceColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: BusinessWorkspaceColors.surfaceRaised,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
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
            const SizedBox(width: 15),

            // Business Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: TextWidget(
                          text: shopName,
                          fontSize: 20,
                          color: Colors.white,
                          isBold: true,
                          maxLines: 2,
                        ),
                      ),
                      if (isVerified != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          isVerified ? Icons.verified : Icons.pending,
                          color: isVerified ? Colors.green : Colors.orange,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [

                      TextWidget(
                        text: 'View public profile',
                        fontSize: 12,
                        color: Colors.white60,
                        isBold: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BusinessWorkspaceColors.copper.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: BusinessWorkspaceColors.copper, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 18,
                  color: BusinessWorkspaceColors.paper,
                  isBold: true,
                ),
                TextWidget(
                  text: subtitle,
                  fontSize: 12,
                  color: BusinessWorkspaceColors.muted,
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
      height: 92,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 11),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 17,
                  color: BusinessWorkspaceColors.paper,
                  isBold: true,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                TextWidget(
                  text: subtitle,
                  fontSize: 13,
                  color: BusinessWorkspaceColors.muted,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: BusinessWorkspaceColors.surfaceRaised,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: BusinessWorkspaceColors.paper, size: 17),
          ),
        ],
      ),
    );
  }

  void _showLockedSnakbar(BuildContext context) {
    CustomToast.showWarning(
      context,
      'This tool unlocks after an admin verifies your café.',
      title: 'Verification required',
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
