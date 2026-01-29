import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class YourReviewsScreen extends StatelessWidget {
  const YourReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextWidget(
          text: 'Your Reviews',
          fontSize: 20,
          color: Colors.white,
          isBold: true,
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Builder(builder: (context) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              return const Center(
                child: Text(
                  'Sign in to view your reviews',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final reviewsStream = FirebaseFirestore.instance
                .collectionGroup('reviews')
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots();

            return StreamBuilder<QuerySnapshot>(
              stream: reviewsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    TextWidget(
                      text:
                          '${docs.length} Review${docs.length == 1 ? '' : 's'}',
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(
                              child: Text(
                                'No reviews yet',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final d = docs[index];
                                final shopId = d.reference.parent.parent?.id;
                                final data = d.data() as Map<String, dynamic>?;
                                final rating = (data?['rating'] as int?) ?? 0;
                                final text = (data?['text'] as String?) ?? '';
                                final tags = (data?['tags'] as List?)
                                        ?.whereType<String>()
                                        .toList() ??
                                    const <String>[];
                                final ts = data?['createdAt'];
                                DateTime? createdAt;
                                if (ts is Timestamp) createdAt = ts.toDate();
                                 final dateStr = createdAt == null
                                    ? ''
                                    : DateFormat('MMM dd, yyyy').format(createdAt);

                                if (shopId == null) {
                                  return _buildReviewCard(
                                    shopName: 'Cafe',
                                    rating: rating,
                                    timeAgo: dateStr,
                                    reviewText: text,
                                    tags: tags,
                                    imagePath:
                                        data?['imageUrl'] as String? ?? '',
                                    hasImage: data?['imageUrl'] != null,
                                  );
                                }
                                final shopRef = FirebaseFirestore.instance
                                    .collection('shops')
                                    .doc(shopId);
                                return StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: shopRef.snapshots(),
                                  builder: (context, shopSnap) {
                                    final shopName = (shopSnap.data
                                            ?.data()?['name'] as String?) ??
                                        'Cafe';
                                    return _buildReviewCard(
                                      shopName: shopName,
                                      rating: rating,
                                      timeAgo: dateStr,
                                      reviewText: text,
                                      tags: tags,
                                      imagePath:
                                          data?['imageUrl'] as String? ?? '',
                                      hasImage: data?['imageUrl'] != null,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }



  Widget _buildReviewCard({
    required String shopName,
    required int rating,
    required String timeAgo,
    required String reviewText,
    required List<String> tags,
    required String imagePath,
    required bool hasImage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cafe icon and shop name
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_cafe,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              TextWidget(
                text: shopName,
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Star rating
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: index < rating ? Colors.amber : Colors.grey,
                  size: 20,
                );
              }),
              const SizedBox(width: 8),
              TextWidget(
                text: timeAgo,
                fontSize: 14,
                color: Colors.white54,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Review tags
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextWidget(
                    text: t,
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),

          // Review text
          TextWidget(
            text: reviewText,
            fontSize: 14,
            color: Colors.white,
          ),

          if (hasImage) ...[
            const SizedBox(height: 12),
            // Review image
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: CachedNetworkImageProvider(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
