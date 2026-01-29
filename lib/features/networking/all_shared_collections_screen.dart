import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/networking/shared_collection_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AllSharedCollectionsScreen extends StatelessWidget {
  const AllSharedCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: TextWidget(
          text: 'All Shared Collections',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sharedCollections')
            .orderBy('sharedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextWidget(
                text: 'Failed to load shared collections',
                fontSize: 16,
                color: Colors.redAccent,
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          
          // Filter out private collections (legacy docs might miss the isPrivate field)
          final publicDocs = docs.where((d) {
            final data = d.data();
            return data['isPrivate'] != true;
          }).toList();

          if (publicDocs.isEmpty) {
            return Center(
              child: TextWidget(
                text: 'No shared collections found',
                fontSize: 16,
                color: Colors.white60,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: publicDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final d = publicDocs[index];
              final collection = d.data();
              return _buildSharedCollectionItem(context, collection, d.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildSharedCollectionItem(BuildContext context,
      Map<String, dynamic> collection, String collectionId) {
    final title = collection['title'] ?? 'Untitled Collection';
    final shopCount = collection['shopCount'] ?? 0;
    final sharedAt = collection['sharedAt'] as Timestamp?;
    final List<String> previewLogos = ((collection['previewLogos'] as List?)?.cast<String>() ?? []);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SharedCollectionScreen(),
            settings: RouteSettings(
              arguments: {
                'collectionId': collectionId,
                'title': title,
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Responsive Logo Collage Icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewLogos.isEmpty
                  ? Center(child: Icon(Icons.collections_bookmark, color: primary, size: 24))
                  : (previewLogos.length < 4)
                      ? CachedNetworkImage(
                          imageUrl: previewLogos[0],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => const Icon(Icons.local_cafe, color: Colors.white24),
                        )
                      : GridView.count(
                          crossAxisCount: 2,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < 4; i++)
                              CachedNetworkImage(
                                imageUrl: previewLogos[i],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                                errorWidget: (context, url, error) => Container(color: Colors.grey[850]),
                              ),
                          ],
                        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWidget(
                    text: title,
                    fontSize: 16,
                    color: Colors.white,
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  TextWidget(
                    text:
                        '$shopCount shops • Shared by ${collection['sharedBy'] ?? 'Community'}',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white12,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
  }
}
