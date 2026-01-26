import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';

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
        _shopsList = shopsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load collection: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextWidget(
          text: _collectionData?['title'] ?? 'Shared Collection',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              TextWidget(
                text: _error!,
                fontSize: 16,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: TextWidget(
                  text: 'Go Back',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_collectionData == null) {
      return Center(
        child: TextWidget(
          text: 'No collection data available',
          fontSize: 16,
          color: Colors.white,
        ),
      );
    }

    if (_shopsList == null) {
      return Center(
        child: TextWidget(
          text: 'No shops data available',
          fontSize: 16,
          color: Colors.white,
        ),
      );
    }

    return Column(
      children: [
        // Collection info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.grey[900],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.collections_bookmark,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text:
                              _collectionData!['originalTitle'] ?? 'Collection',
                          fontSize: 20,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 4),
                        TextWidget(
                          text: '${_shopsList!.length} coffee shops',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Shops list
        Expanded(
          child: _shopsList!.isEmpty
              ? Center(
                  child: TextWidget(
                    text: 'No coffee shops in this collection',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shopsList!.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white24),
                  itemBuilder: (context, index) {
                    final shop = _shopsList![index];
                    final shopName = (shop['name'] as String?) ?? 'Cafe';
                    final shopId = shop['id'] as String?;
                    return _buildShopItem(
                        shopName, shop['logoUrl'] ?? '', shopId);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShopItem(String name, String logoUrl, String? shopId) {
    return GestureDetector(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[800],
                image: logoUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(logoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: logoUrl.isEmpty
                  ? const Icon(
                      Icons.local_cafe,
                      color: Colors.white70,
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextWidget(
                text: name,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
