import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';

class SelectedShopCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String shopId;
  final bool isBookmarked;
  final VoidCallback onClose;
  final VoidCallback onToggleBookmark;
  final VoidCallback onTap;

  const SelectedShopCard({
    super.key,
    required this.data,
    required this.shopId,
    required this.isBookmarked,
    required this.onClose,
    required this.onToggleBookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? 'Unknown';
    final address = (data['address'] as String?) ?? '';

    final gallery = (data['gallery'] as List?)?.cast<String>() ?? [];
    final imageUrl = gallery.isNotEmpty ? gallery[0] : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
                image: DecorationImage(
                  image: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/images/placeholder.jpg')
                          as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Bold',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'Regular',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('shops')
                              .doc(shopId)
                              .collection('reviews')
                              .snapshots(),
                          builder: (context, snapshot) {
                            double displayRating = 0.0;
                            if (snapshot.hasData) {
                              final docs = snapshot.data!.docs;
                              final scores = docs
                                  .map((d) => d.data()['rating'])
                                  .whereType<num>()
                                  .map((n) => n.toDouble())
                                  .toList();
                              if (scores.isNotEmpty) {
                                displayRating =
                                    scores.reduce((a, b) => a + b) /
                                        scores.length;
                              }
                            }
                            return Row(
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  displayRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Bold',
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onToggleBookmark,
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: isBookmarked ? primary : Colors.grey,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ], // End Row children
        ), // End Row
      ), // End Container
    ); // End GestureDetector
  }
}
