import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VisitedCafesScreen extends StatelessWidget {
  const VisitedCafesScreen({super.key});

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
          text: 'Visited Cafes',
          fontSize: 20,
          color: Colors.white,
          isBold: true,
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: TextWidget(
                text: '2025',
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Builder(builder: (context) {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              return const Center(
                child: Text(
                  'Sign in to view visited cafes',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final visitsStream = FirebaseFirestore.instance
                .collectionGroup('visits')
                .where('userId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .snapshots();

            return StreamBuilder<QuerySnapshot>(
              stream: visitsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                // Dedupe by shopId; keep the latest createdAt for ordering
                final Map<String, Timestamp> latestByShop = {};
                for (final d in docs) {
                  final shopId = d.reference.parent.parent?.id;
                  if (shopId == null) continue;
                  final createdAt = (d.get('createdAt') as Timestamp?);
                  if (createdAt == null) continue;
                  final prev = latestByShop[shopId];
                  if (prev == null ||
                      createdAt.millisecondsSinceEpoch >
                          prev.millisecondsSinceEpoch) {
                    latestByShop[shopId] = createdAt;
                  }
                }

                final entries = latestByShop.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                if (entries.isEmpty) {
                  return const Center(
                    child: Text(
                      'No visited cafes yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) return const SizedBox(height: 24);
                    final entry = entries[index - 1];
                    final shopRef = FirebaseFirestore.instance
                        .collection('shops')
                        .doc(entry.key);
                    return StreamBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      stream: shopRef.snapshots(),
                      builder: (context, shopSnap) {
                        final shopName =
                            (shopSnap.data?.data()?['name'] as String?) ??
                                'Cafe';
                        return GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/cafeDetails',
                              arguments: {'shopId': entry.key},
                            );
                          },
                          child: _buildCafeCard(
                            cafeName: shopName,
                            cafeImage: shopSnap.data?.data()?['logoUrl'],
                            backgroundColor: Colors.grey[700]!,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCafeCard({
    required String cafeName,
    required String? cafeImage,
    required Color backgroundColor,
  }) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Cafe image/icon section
          Container(
            width: 72,
            height: 72,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              image: cafeImage != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(cafeImage),
                      fit: BoxFit.cover)
                  : null,
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: cafeImage == null
                ? const Icon(Icons.coffee, color: Colors.white70)
                : null,
          ),
          // Cafe name section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: TextWidget(
                text: cafeName,
                fontSize: 16,
                color: Colors.white,
                isBold: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
