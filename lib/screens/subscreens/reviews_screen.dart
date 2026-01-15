import 'package:cofi/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/text_widget.dart';
import 'response_review_bottom_sheet.dart';

class ReviewsScreen extends StatelessWidget {
  final String? shopId;
  final List? fallbackReviews;

  const ReviewsScreen({super.key, this.shopId, this.fallbackReviews});

  @override
  Widget build(BuildContext context) {
    final hasShopId = shopId != null && shopId!.isNotEmpty;
    final query = hasShopId
        ? FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('reviews')
            .orderBy('createdAt', descending: true)
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextWidget(
            text: 'Reviews', fontSize: 18, color: Colors.white, isBold: true),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: hasShopId
                ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query!.snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return TextWidget(
                        text: '$count Reviews',
                        fontSize: 14,
                        color: Colors.white,
                      );
                    },
                  )
                : TextWidget(
                    text: '${(fallbackReviews ?? const []).length} Reviews',
                    fontSize: 14,
                    color: Colors.white,
                  ),
          ),
        ],
      ),
      body: hasShopId
          ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query!.snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      TextWidget(
                        text: 'No reviews yet',
                        fontSize: 14,
                        color: Colors.white70,
                      )
                    else
                      ...docs.map((d) {
                        final m = d.data();
                        final name =
                            (m['authorName'] ?? m['name'] ?? 'Anonymous')
                                .toString();
                        final review =
                            (m['text'] ?? m['comment'] ?? '').toString();
                        final tags = (m['tags'] is List)
                            ? (m['tags'] as List).cast<String>()
                            : <String>[];
                        final imageUrl = m['imageUrl'] as String?;
                        final responses = (m['responses'] as List?)
                                ?.cast<Map<String, dynamic>>() ??
                            [];

                        return _buildReviewCard(
                          context: context,
                          rating: m['rating'],
                          name: name,
                          review: review.isNotEmpty ? review : '—',
                          tags: tags,
                          imagePath: 'assets/images/review_placeholder.jpg',
                          imageUrl: imageUrl,
                          responses: responses,
                          shopId: shopId,
                          reviewId: d.id,
                        );
                      }),
                  ],
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 16),
                if ((fallbackReviews ?? const []).isEmpty)
                  TextWidget(
                    text: 'No reviews yet',
                    fontSize: 14,
                    color: Colors.white70,
                  )
                else
                  ...fallbackReviews!.map((r) {
                    final m = (r is Map)
                        ? r.cast<String, dynamic>()
                        : <String, dynamic>{};
                    final name = (m['authorName'] ?? m['name'] ?? 'Anonymous')
                        .toString();
                    final review = (m['text'] ?? m['comment'] ?? '').toString();
                    final tags = (m['tags'] is List)
                        ? (m['tags'] as List).cast<String>()
                        : <String>[];
                    final imageUrl = m['imageUrl'] as String?;
                    final createdAt = m['createdAt'] as Timestamp?;
                    final responses = (m['responses'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        [];

                    return _buildReviewCard(
                      context: context,
                      rating: m['rating'],
                      name: name,
                      review: review.isNotEmpty ? review : '—',
                      tags: tags,
                      imagePath: 'assets/images/review_placeholder.jpg',
                      imageUrl: imageUrl,
                      createdAt: createdAt,
                      responses: responses,
                    );
                  }),
              ],
            ),
    );
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required String name,
    required String review,
    required List<String> tags,
    required String imagePath,
    String? imageUrl,
    required int rating,
    Timestamp? createdAt,
    List<Map<String, dynamic>>? responses,
    String? shopId,
    String? reviewId,
  }) {
    // Calculate time difference
    String timeAgo = '1 week ago'; // Default fallback
    if (createdAt != null) {
      final now = DateTime.now();
      final reviewDate = createdAt.toDate();
      final difference = now.difference(reviewDate);

      if (difference.inDays > 7) {
        timeAgo =
            '${difference.inDays ~/ 7} week${(difference.inDays ~/ 7) > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        timeAgo =
            '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        timeAgo =
            '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        timeAgo = 'Just now';
      }
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                      ),
                    ),
                  ),
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
                          Row(
                            children: List.generate(
                              rating,
                              (index) => const Icon(Icons.star,
                                  color: Colors.amber, size: 16),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextWidget(
                            text: timeAgo,
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: tags
                  .map((tag) => Chip(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        label: TextWidget(
                          text: tag,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        backgroundColor: Colors.grey[800],
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextWidget(
              text: review,
              fontSize: 14,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.image, color: Colors.white38, size: 60),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.white38, size: 60),
                ),
              ),
            const SizedBox(height: 16),

            // Owner's Response Section
            if (responses != null && responses.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextWidget(
                text: "Owner's Response",
                fontSize: 14,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              ...responses.map((response) {
                final responseText =
                    (response['responseText'] as String?) ?? '';
                final responseCreatedAt =
                    (response['createdAt'] as Timestamp?)?.toDate();

                String responseTimeAgo = 'Just now';
                if (responseCreatedAt != null) {
                  final diff = DateTime.now().difference(responseCreatedAt);
                  if (diff.inDays > 7) {
                    responseTimeAgo = '${diff.inDays ~/ 7}w ago';
                  } else if (diff.inDays > 0) {
                    responseTimeAgo = '${diff.inDays}d ago';
                  } else if (diff.inHours > 0) {
                    responseTimeAgo = '${diff.inHours}h ago';
                  }
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .get(),
                  builder: (context, shopSnap) {
                    final shopData =
                        shopSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final shopName = (shopData['name'] as String?) ?? 'Café';
                    final shopLogoUrl = (shopData['logoUrl'] as String?);

                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (shopLogoUrl != null && shopLogoUrl.isNotEmpty)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: shopLogoUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: primary,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(color: primary),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.store,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: shopName,
                                      fontSize: 13,
                                      color: Colors.white,
                                      isBold: true,
                                    ),
                                    TextWidget(
                                      text: responseTimeAgo,
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ],
                                ),
                              ),
                              if (isOwner)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) =>
                                            ResponseReviewBottomSheet(
                                          shopId: shopId ?? '',
                                          reviewId: reviewId ?? '',
                                          reviewText: review,
                                          reviewAuthor: name,
                                          ownerName: shopName,
                                          ownerAvatarUrl: shopLogoUrl,
                                          isEdit: true,
                                          existingResponse: responseText,
                                          responseId: response['id'] as String?,
                                        ),
                                      );
                                    } else if (value == 'delete') {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: Colors.grey[900],
                                          title: TextWidget(
                                            text: 'Delete Response',
                                            fontSize: 18,
                                            color: Colors.white,
                                            isBold: true,
                                          ),
                                          content: TextWidget(
                                            text:
                                                'Are you sure you want to delete this response?',
                                            fontSize: 14,
                                            color: Colors.white70,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: TextWidget(
                                                text: 'Cancel',
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                try {
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('shops')
                                                      .doc(shopId)
                                                      .collection('reviews')
                                                      .doc(reviewId)
                                                      .update({
                                                    'responses':
                                                        FieldValue.arrayRemove(
                                                      [response],
                                                    ),
                                                  });

                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'Response deleted successfully')),
                                                  );
                                                } catch (e) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text(
                                                            'Error deleting response: $e')),
                                                  );
                                                }
                                              },
                                              child: TextWidget(
                                                text: 'Delete',
                                                fontSize: 14,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit,
                                              size: 16, color: Colors.white),
                                          SizedBox(width: 8),
                                          Text('Edit',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  color: Colors.grey[800],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextWidget(
                            text: responseText,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],

            // Reply Button
            if (isOwner && shopId != null && reviewId != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ResponseReviewBottomSheet(
                        shopId: shopId,
                        reviewId: reviewId,
                        reviewText: review,
                        reviewAuthor: name,
                        ownerName: 'Café Owner',
                        ownerAvatarUrl: null,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: TextWidget(
                    text: 'Reply to Review',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
