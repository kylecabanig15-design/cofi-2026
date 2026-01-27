import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cofi/widgets/list_bottom_sheet.dart';

class SharedCollectionScreen extends StatefulWidget {
  const SharedCollectionScreen({super.key});

  @override
  State<SharedCollectionScreen> createState() => _SharedCollectionScreenState();
}

class _SharedCollectionScreenState extends State<SharedCollectionScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _collectionData;
  List<Map<String, dynamic>>? _shopsList;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _collectionData == null) {
      _loadSharedCollection(args['collectionId'] as String);
    }
  }

  Future<void> _loadSharedCollection(String collectionId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get shared collection data
      final sharedDoc = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .doc(collectionId)
          .get();

      if (!sharedDoc.exists) {
        setState(() {
          _error = 'Collection not found';
          _isLoading = false;
        });
        return;
      }

      final data = sharedDoc.data()!;
      final userId = data['userId'] as String;
      final listId = data['listId'] as String;

      // Get the original list data
      final listDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .get();

      if (!listDoc.exists) {
        setState(() {
          _error = 'Original collection not found';
          _isLoading = false;
        });
        return;
      }

      final listData = listDoc.data()!;
      final filters = listData['filters'] as Map<String, dynamic>? ?? {};
      final List<String> tags =
          ((filters['tags'] as List?)?.cast<String>()) ?? const <String>[];

      List<Map<String, dynamic>> shopsList = [];

      if (tags.isNotEmpty) {
        // Tag-based collection
        final shopsQuery = FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .where('tags', arrayContainsAny: tags);
        final res = await shopsQuery.get();
        shopsList = res.docs.map((d) {
          final data = d.data();
          // Make sure we add the document ID
          data['id'] = d.id;
          return data;
        }).toList();
      } else {
        // Item-based collection
        final itemsRes = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('lists')
            .doc(listId)
            .collection('items')
            .get();

        final ids = itemsRes.docs
            .map((doc) => (doc.data()['shopId'] as String?) ?? doc.id)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        if (ids.isNotEmpty) {
          // Fetch shops in batches of 10 due to whereIn limit
          const int batchSize = 10;
          for (var i = 0; i < ids.length; i += batchSize) {
            final batch = ids.sublist(
                i, i + batchSize > ids.length ? ids.length : i + batchSize);
            final snap = await FirebaseFirestore.instance
                .collection('shops')
                .where('isVerified', isEqualTo: true)
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            shopsList.addAll(snap.docs.map((e) {
              final data = e.data();
              // Make sure we add the document ID
              data['id'] = e.id;
              return data;
            }));
          }
        }
      }

      setState(() {
        _collectionData = {
          ...data,
          'originalTitle': listData['name'] ?? 'Untitled Collection',
        };
      });

      // Fetch the owner's name from high-level user object for better accuracy
      try {
        final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (ownerDoc.exists) {
          final ownerName = (ownerDoc.data()?['name'] as String?)?.trim();
          if (ownerName != null && ownerName.isNotEmpty) {
             setState(() {
               _collectionData!['sharedBy'] = ownerName;
             });
          }
        }
      } catch (e) {
        debugPrint('Error fetching owner name: $e');
      }

      setState(() {
        _shopsList = shopsList;
        _isLoading = false;
      });

      // SELF-REPAIR: If data is stale or missing, trigger a silent sync
      final currentCount = data['shopCount'] as int? ?? 0;
      final currentLogos = (data['previewLogos'] as List?) ?? [];
      if (currentCount == 0 || currentLogos.isEmpty) {
        // Run in background to not block the UI
        ListBottomSheet.syncLogos(userId, listId);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load collection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_collectionData == null || _shopsList == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: TextWidget(text: 'No data available', fontSize: 16, color: Colors.white70),
        ),
      );
    }

    final List<String> previewLogos = ((_collectionData!['previewLogos'] as List?)?.cast<String>() ?? []);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Hero Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Logo Grid Collage
                  if (previewLogos.isNotEmpty)
                    GridView.count(
                      crossAxisCount: 2,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (var logo in previewLogos)
                          CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.cover,
                            color: Colors.black.withOpacity(0.5),
                            colorBlendMode: BlendMode.darken,
                          ),
                      ],
                    )
                  else
                    Opacity(
                      opacity: 0.2,
                      child: Center(
                        child: Image.asset('assets/images/logo.png', width: 120),
                      ),
                    ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Title and Info
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: primary.withValues(alpha: 0.3)),
                          ),
                          child: TextWidget(
                            text: 'Collection',
                            fontSize: 10,
                            color: primary,
                            isBold: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _collectionData!['originalTitle'] ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.local_cafe, color: Colors.white60, size: 14),
                            const SizedBox(width: 4),
                            TextWidget(
                              text: '${_shopsList!.length} coffee shops',
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.person, color: Colors.white60, size: 14),
                            const SizedBox(width: 4),
                            TextWidget(
                              text: 'Shared by ${_collectionData!['sharedBy'] ?? 'Community'}',
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Shops List
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: _shopsList!.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: TextWidget(text: 'No shops in this collection', fontSize: 16, color: Colors.white54),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildShopItem(_shopsList![index]);
                      },
                      childCount: _shopsList!.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(Map<String, dynamic> shop) {
    final name = (shop['name'] as String?) ?? 'Cafe';
    final logoUrl = shop['logoUrl'] as String? ?? '';
    final shopId = shop['id'] as String?;
    return InkWell(
      onTap: () {
        if (shopId != null && shopId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CafeDetailsScreen(
                shopId: shopId,
                shop: {'name': name, 'logoUrl': logoUrl},
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withOpacity(0.05),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: logoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: logoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.white10),
                        errorWidget: (context, url, error) => const Icon(Icons.local_cafe, color: Colors.white24),
                      )
                    : const Icon(Icons.local_cafe, color: Colors.white24),
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
                      Icon(Icons.star, color: primary, size: 12),
                      const SizedBox(width: 4),
                      Builder(builder: (context) {
                        // Calculate accurate rating from embedded reviews if available
                        double avgRating = ((shop['ratings'] ?? 0.0) as num).toDouble();
                        final reviews = (shop['reviews'] as List?) ?? [];
                        if (reviews.isNotEmpty) {
                          final validRatings = reviews
                              .map((r) => (r as Map<String, dynamic>)['rating'])
                              .whereType<num>()
                              .map((n) => n.toDouble())
                              .toList();
                          if (validRatings.isNotEmpty) {
                            avgRating = validRatings.reduce((a, b) => a + b) / validRatings.length;
                          }
                        }

                        final address = (shop['address'] as String?) ?? 'Cafe';
                        
                        return Expanded(
                          child: TextWidget(
                            text: '${avgRating.toStringAsFixed(1)} • $address',
                            fontSize: 12,
                            color: Colors.white54,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white24,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              TextWidget(text: _error!, fontSize: 16, color: Colors.white),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: TextWidget(text: 'Go Back', fontSize: 16, color: Colors.white, isBold: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
