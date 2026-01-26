import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ListBottomSheet extends StatefulWidget {
  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? itemsStream;
  final Stream<List<String>>? shopIdsStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? shopsStream;
  final List<Map<String, dynamic>>? shopsList;
  final String? listId;
  final String? userId;
  final List<String>? filterTags;

  const ListBottomSheet(
      {super.key,
      required this.title,
      this.itemsStream,
      this.shopIdsStream,
      this.shopsStream,
      this.shopsList,
      this.listId,
      this.userId,
      this.filterTags});

  @override
  State<ListBottomSheet> createState() => _ListBottomSheetState();

  static void show(BuildContext context,
      {required String title,
      List<Map<String, dynamic>>? shopsList,
      Stream<QuerySnapshot<Map<String, dynamic>>>? itemsStream,
      Stream<List<String>>? shopIdsStream,
      Stream<QuerySnapshot<Map<String, dynamic>>>? shopsStream,
      String? listId,
      String? userId,
      List<String>? filterTags}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ListBottomSheet(
          title: title,
          shopsList: shopsList,
          itemsStream: itemsStream,
          shopIdsStream: shopIdsStream,
          shopsStream: shopsStream,
          listId: listId,
          userId: userId,
          filterTags: filterTags),
    );
  }
}

class _ListBottomSheetState extends State<ListBottomSheet> {
  final Set<String> _removedShopIds = {};

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextWidget(
                      text: widget.title,
                      fontSize: 18,
                      color: Colors.white,
                      isBold: true,
                    ),
                    Row(
                      children: [
                        // Delete list button
                        if (widget.listId != null && widget.userId != null)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white, size: 24),
                              onPressed: () =>
                                  _showDeleteListConfirmation(context),
                            ),
                          ),
                        // Share button for user-created lists
                        if (widget.listId != null && widget.userId != null)
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('sharedCollections')
                                .where('userId', isEqualTo: widget.userId)
                                .where('listId', isEqualTo: widget.listId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              return SizedBox(
                                width: 40,
                                height: 40,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.share,
                                      color: Colors.white, size: 24),
                                  onPressed: () =>
                                      _showShareConfirmation(context),
                                ),
                              );
                            },
                          ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 24),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Filter tags (if this is a filter-based list)
              if (widget.filterTags != null && widget.filterTags!.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.filterTags!.map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: primary,
                              border:
                                  Border.all(color: Colors.white24, width: 1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: TextWidget(
                              text: tag,
                              fontSize: 12,
                              color: Colors.white,
                              isBold: false,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              // List items
              Expanded(
                child: Builder(
                  builder: (context) {
                    // If no data source is provided, avoid indefinite loading
                    final noData = widget.shopsList == null &&
                        widget.shopsStream == null &&
                        widget.itemsStream == null &&
                        widget.shopIdsStream == null;
                    if (noData) {
                      return const Center(
                        child: Text(
                          'Nothing to show (no data source provided).',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    // Static list path (preferred when provided)
                    if (widget.shopsList != null) {
                      final shops = widget.shopsList!
                          .where(
                              (shop) => !_removedShopIds.contains(shop['id']))
                          .toList();
                      if (shops.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Expanded(
                              child: Center(
                                child: Text(
                                  'No cafes yet',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: shops.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(color: Colors.white24),
                              itemBuilder: (context, index) {
                                final data = shops[index];
                                final shopName =
                                    (data['name'] as String?) ?? 'Cafe';
                                final shopId = data['id'] as String? ?? '';
                                print(shopId);
                                return KeyedSubtree(
                                  key: ValueKey(shopId),
                                  child: _buildCafeItem(
                                      name: shopName,
                                      logo: (data['logoUrl'] ?? '') as String,
                                      shopId: shopId,
                                      listId: widget.listId,
                                      userId: widget.userId),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }
                    // Priority: direct shops stream -> list items -> shopIds
                    if (widget.shopsStream != null) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.shopsStream,
                        builder: (context, snapshot) {
                          final debugLine =
                              'src=shops, state=${snapshot.connectionState}, hasData=${snapshot.hasData}, count=${snapshot.data?.docs.length}';
                          if (snapshot.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Error loading cafes',
                                        style: TextStyle(color: Colors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          final shops = snapshot.data?.docs;

                          if (shops == null || shops.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'No cafes yet',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(debugLine,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: shops.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(color: Colors.white24),
                                  itemBuilder: (context, index) {
                                    final shop = shops[index];
                                    final data = shop.data();
                                    final shopName =
                                        (data['name'] as String?) ?? 'Cafe';
                                    return _buildCafeItem(
                                        name: shopName,
                                        logo: (data['logoUrl'] ?? '') as String,
                                        shopId: shop.id,
                                        listId: widget.listId,
                                        userId: widget.userId);
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    if (widget.itemsStream != null) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: widget.itemsStream,
                        builder: (context, snapshot) {
                          final debugLine =
                              'src=items, state=${snapshot.connectionState}, hasData=${snapshot.hasData}, count=${snapshot.data?.docs.length}';
                          if (snapshot.hasError) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (kDebugMode)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(debugLine,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12)),
                                  ),
                                const Expanded(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'Error loading list',
                                        style: TextStyle(color: Colors.white70),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          final items = snapshot.data?.docs;
                          if (items == null || items.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'No cafes yet',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                          // Filter out removed items
                          final filteredItems = items.where((item) {
                            final data = item.data();
                            final shopId =
                                (data['shopId'] as String?) ?? item.id;
                            return !_removedShopIds.contains(shopId);
                          }).toList();

                          if (filteredItems.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'No cafes yet',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (kDebugMode)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(debugLine,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 12)),
                                ),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: filteredItems.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(color: Colors.white24),
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    final data = item.data();
                                    final shopId =
                                        (data['shopId'] as String?) ?? item.id;
                                    if (shopId.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    final shopRef = FirebaseFirestore.instance
                                        .collection('shops')
                                        .doc(shopId);
                                    return StreamBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: shopRef.snapshots(),
                                      builder: (context, shopSnap) {
                                        if (shopSnap.hasError) {
                                          return _buildCafeItem(
                                              name: 'Cafe',
                                              logo: '',
                                              shopId: shopId,
                                              listId: widget.listId,
                                              userId: widget.userId);
                                        }

                                        if (!shopSnap.hasData ||
                                            !shopSnap.data!.exists) {
                                          return _buildCafeItem(
                                              name: 'Cafe',
                                              logo: '',
                                              shopId: shopId,
                                              listId: widget.listId,
                                              userId: widget.userId);
                                        }

                                        final shopData = shopSnap.data!.data();
                                        final shopName =
                                            (shopData?['name'] as String?) ??
                                                'Cafe';
                                        final logoUrl =
                                            (shopData?['logoUrl'] as String?) ??
                                                '';
                                        return _buildCafeItem(
                                            name: shopName,
                                            logo: logoUrl,
                                            shopId: shopId,
                                            listId: widget.listId,
                                            userId: widget.userId);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }
                    // shopIdsStream rendering path
                    return StreamBuilder<List<String>>(
                      stream: widget.shopIdsStream!,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Error loading cafes',
                                      style: TextStyle(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        final ids = snapshot.data;
                        if (ids == null || ids.isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'No cafes yet',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ListView.separated(
                                itemCount: ids.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(color: Colors.white24),
                                itemBuilder: (context, index) {
                                  final shopId = ids[index];
                                  if (shopId.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  final shopRef = FirebaseFirestore.instance
                                      .collection('shops')
                                      .doc(shopId);
                                  return StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: shopRef.snapshots(),
                                    builder: (context, shopSnap) {
                                      if (shopSnap.hasError) {
                                        return _buildCafeItem(
                                            name: 'Cafe',
                                            logo: '',
                                            shopId: shopId,
                                            listId: widget.listId,
                                            userId: widget.userId);
                                      }

                                      if (!shopSnap.hasData ||
                                          !shopSnap.data!.exists) {
                                        return SizedBox();
                                      }

                                      final shopData = shopSnap.data!.data();
                                      final shopName =
                                          (shopData?['name'] as String?) ??
                                              'Cafe';
                                      final logoUrl =
                                          (shopData?['logoUrl'] as String?) ??
                                              '';
                                      return _buildCafeItem(
                                          name: shopName,
                                          logo: logoUrl,
                                          shopId: shopId,
                                          listId: widget.listId,
                                          userId: widget.userId);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Floating action button in bottom-right
        if (widget.listId != null && widget.userId != null)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => _showAddCafeDialog(context),
              backgroundColor: primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
      ],
    );
  }

  Widget _buildCafeItem({
    required String name,
    required String logo,
    String? shopId,
    String? listId,
    String? userId,
  }) {
    return Builder(
      builder: (context) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final isOwner = currentUser?.uid == userId;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (shopId != null && shopId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CafeDetailsScreen(
                    shopId: shopId,
                    shop: {'name': name, 'logoUrl': logo},
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[800],
                    image: logo.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(logo),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: logo.isEmpty
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
                if (isOwner && listId != null && shopId != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => _showRemoveConfirmation(
                      context: context,
                      shopId: shopId,
                      listId: listId,
                      userId: userId!,
                      cafeName: name,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRemoveConfirmation({
    required BuildContext context,
    required String shopId,
    required String listId,
    required String userId,
    required String cafeName,
  }) {
    final originalContext = context; // Store the original context
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: TextWidget(
            text: 'Remove Cafe',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          content: TextWidget(
            text:
                'Are you sure you want to remove "$cafeName" from this collection?',
            fontSize: 16,
            color: Colors.white70,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: TextWidget(
                text: 'Cancel',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _removeCafeFromList(
                  context: originalContext,
                  shopId: shopId,
                  listId: listId,
                  userId: userId,
                  cafeName: cafeName,
                );
              },
              child: TextWidget(
                text: 'Remove',
                fontSize: 14,
                color: Colors.red,
                isBold: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeCafeFromList({
    required BuildContext context,
    required String shopId,
    required String listId,
    required String userId,
    required String cafeName,
  }) async {
    try {
      // Find the item document with this shopId
      final itemsCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .collection('items');

      final query = await itemsCollection
          .where('shopId', isEqualTo: shopId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.delete();
      }

      // Always remove from display and show success (even if query was empty)
      if (mounted) {
        setState(() {
          // Add to removed set to filter from display
          _removedShopIds.add(shopId);
        });
      }

      // Show success snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$cafeName removed from collection'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to remove cafe: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddCafeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AddCafeToListDialog(
          listId: widget.listId!,
          userId: widget.userId!,
          onCafeAdded: () {
            Navigator.pop(dialogContext);
            // Refresh the list
            setState(() {});
          },
        );
      },
    );
  }

  void _showDeleteListConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: TextWidget(
            text: 'Delete Collection',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          content: TextWidget(
            text:
                'Are you sure you want to delete "${widget.title}"? This action cannot be undone.',
            fontSize: 16,
            color: Colors.white70,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: TextWidget(
                text: 'Cancel',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteList(context);
              },
              child: TextWidget(
                text: 'Delete',
                fontSize: 14,
                color: Colors.red,
                isBold: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteList(BuildContext context) async {
    try {
      if (widget.listId == null || widget.userId == null) return;

      // Delete the list document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .delete();

      // Close the bottom sheet and show success message
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('"${widget.title}" collection deleted'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to delete collection: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showShareConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: TextWidget(
            text: 'Share Collection',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          content: TextWidget(
            text:
                'Are you sure you want to share your collection "${widget.title}" with others?',
            fontSize: 16,
            color: Colors.white70,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: TextWidget(
                text: 'Cancel',
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkAndShareCollection(context);
              },
              child: TextWidget(
                text: 'Share',
                fontSize: 14,
                color: Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  void _checkAndShareCollection(BuildContext context) async {
    if (widget.listId == null || widget.userId == null) return;

    try {
      // Check if this collection has already been shared by this user
      final existingShareQuery = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .where('userId', isEqualTo: widget.userId)
          .where('listId', isEqualTo: widget.listId)
          .get();

      if (existingShareQuery.docs.isNotEmpty) {
        // Collection already shared

        // Generate shareable link
        final shareableLink =
            'https://cofi.app/shared-collection/${existingShareQuery.docs.first.id}';

        // Create share content
        final String shareText =
            'Check out my coffee collection "${widget.title}" on Cofi!\n\n$shareableLink';

        // Share the collection
        await Share.share(
          shareText,
          subject: 'Coffee Collection: ${widget.title}',
        );
        // if (context.mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     const SnackBar(
        //       content: Text('You have already shared this collection'),
        //       backgroundColor: Colors.orange,
        //     ),
        //   );
        // }

        return;
      }

      // Proceed with sharing
      _shareCollection(context);
    } catch (e) {
      if (kDebugMode) print('Error checking shared collection: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share collection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareCollection(BuildContext context) async {
    if (widget.listId == null || widget.userId == null) return;

    try {
      // Save collection to shared collections
      final sharedCollectionRef =
          await FirebaseFirestore.instance.collection('sharedCollections').add({
        'userId': widget.userId,
        'listId': widget.listId,
        'title': widget.title,
        'sharedBy':
            'User', // You could get the actual username from user profile
        'sharedAt': FieldValue.serverTimestamp(),
        'shopCount': widget.shopsList?.length ?? 0,
      });

      // Generate shareable link
      final shareableLink =
          'https://cofi.app/shared-collection/${sharedCollectionRef.id}';

      // Create share content
      final String shareText =
          'Check out my coffee collection "${widget.title}" on Cofi!\n\n$shareableLink';

      // Share the collection
      await Share.share(
        shareText,
        subject: 'Coffee Collection: ${widget.title}',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error sharing collection: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share collection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class AddCafeToListDialog extends StatefulWidget {
  final String listId;
  final String userId;
  final VoidCallback onCafeAdded;

  const AddCafeToListDialog({
    super.key,
    required this.listId,
    required this.userId,
    required this.onCafeAdded,
  });

  @override
  State<AddCafeToListDialog> createState() => _AddCafeToListDialogState();
}

class _AddCafeToListDialogState extends State<AddCafeToListDialog> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Cafe to Collection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search cafes...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            // Cafes list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('shops').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final searchText = _searchController.text.toLowerCase();
                  final cafes = snapshot.data!.docs.where((doc) {
                    final name = (doc['name'] as String? ?? '').toLowerCase();
                    return name.contains(searchText);
                  }).toList();

                  if (cafes.isEmpty) {
                    return Center(
                      child: Text(
                        'No cafes found',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: cafes.length,
                    itemBuilder: (context, index) {
                      final cafe = cafes[index];
                      final cafeName = cafe['name'] as String? ?? 'Unknown';
                      final cafeId = cafe.id;

                      final cafeLogoUrl = cafe['logoUrl'] as String? ?? '';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: cafeLogoUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: cafeLogoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: Colors.grey[800]),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.local_cafe,
                                            color: Colors.grey),
                                  ),
                                )
                              : const Icon(Icons.local_cafe,
                                  color: Colors.grey),
                        ),
                        title: Text(
                          cafeName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () => _addCafeToList(cafeId, cafeName),
                          child: const Text(
                            'Add',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _addCafeToList(String cafeId, String cafeName) async {
    try {
      // Add cafe to the list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .collection('items')
          .doc(cafeId)
          .set({
        'shopId': cafeId,
        'name': cafeName,
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('$cafeName added to collection'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onCafeAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add cafe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
