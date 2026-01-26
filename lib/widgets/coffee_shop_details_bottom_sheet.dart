import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';

class CoffeeShopDetailsBottomSheet extends StatelessWidget {
  final String shopId;
  final String name;
  final String location;
  final String hours;
  final String rating; // fallback display text
  final bool isBookmarked;
  final String? imageUrl;
  final String? logoUrl;
  final VoidCallback? onToggleBookmark;

  const CoffeeShopDetailsBottomSheet({
    super.key,
    required this.shopId,
    required this.name,
    required this.location,
    required this.hours,
    required this.rating,
    this.isBookmarked = false,
    this.imageUrl,
    this.logoUrl,
    this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Location header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: TextWidget(
                text: location,
                fontSize: 16,
                color: Colors.white,
                isBold: true,
                align: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),

          const SizedBox(height: 25),

          // Coffee shop image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () {
                // Close the bottom sheet and navigate to CafeDetailsScreen
                Navigator.pop(context); // Close the bottom sheet
                // Navigate to CafeDetailsScreen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CafeDetailsScreen(shopId: shopId),
                  ),
                );
              },
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Placeholder image
                    if (imageUrl != null)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  imageUrl!,
                                ),
                                fit: BoxFit.cover)),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(Icons.store, color: Colors.white54, size: 50),
                        ),
                      ),

                    // Overlay with coffee shop name
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: name,
                              fontSize: 24,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Rating badge
                    Positioned(
                      top: 16,
                      right: 16,
                      child: IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          // Prevent the tap from propagating to the parent GestureDetector
                          // Call the onToggleBookmark callback if provided
                          onToggleBookmark?.call();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Coffee shop details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: name,
                      fontSize: 20,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        TextWidget(
                          text: hours,
                          fontSize: 14,
                          color: Colors.grey[400]!,
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        // Live rating text from reviews subcollection with fallback
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('shops')
                              .doc(shopId)
                              .collection('reviews')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return TextWidget(
                                text: rating,
                                fontSize: 14,
                                color: Colors.white,
                              );
                            }
                            final docs = snapshot.data!.docs;
                            final scores = docs
                                .map((d) => d.data()['rating'])
                                .whereType<num>()
                                .map((n) => n.toDouble())
                                .toList();
                            final count = scores.length;
                            final avg = count == 0
                                ? 0.0
                                : scores.reduce((a, b) => a + b) / count;
                            final text = '${avg.toStringAsFixed(1)} ($count)';
                            return TextWidget(
                              text: text,
                              fontSize: 14,
                              color: Colors.white,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (logoUrl != null && logoUrl!.isNotEmpty)
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: CachedNetworkImageProvider(logoUrl!),
                    backgroundColor: Colors.grey[800],
                  )
                else
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: primary,
                    child: const Icon(
                      Icons.local_cafe,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String shopId,
    required String name,
    required String location,
    required String hours,
    required String rating,
    bool isBookmarked = false,
    VoidCallback? onToggleBookmark,
    required String imageUrl,
    String? logoUrl,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CoffeeShopDetailsBottomSheet(
        imageUrl: imageUrl,
        shopId: shopId,
        name: name,
        location: location,
        hours: hours,
        rating: rating,
        isBookmarked: isBookmarked,
        onToggleBookmark: onToggleBookmark,
        logoUrl: logoUrl,
      ),
    );
  }
}
