import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // For BackdropFilter
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';

class SyncResult {
  final bool success;
  final List<Map<String, String>>
      missingLogos; // List of {id: shopId, name: shopName}
  SyncResult({required this.success, this.missingLogos = const []});
}

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

  static String _extractId(dynamic value) {
    if (value == null) return '';
    if (value is DocumentReference) return value.id;
    final String s = value.toString();
    if (s.contains('/')) return s.split('/').last;
    return s;
  }

  static Future<SyncResult> syncLogos(dynamic userId, dynamic listId,
      {bool deleteIfEmpty = false}) async {
    final List<Map<String, String>> missingLogos = [];
    try {
      final String uId = _extractId(userId);
      final String lId = _extractId(listId);

      if (uId.isEmpty || lId.isEmpty) {
        debugPrint('Sync Error: Missing IDs (u:$uId, l:$lId)');
        return SyncResult(success: false);
      }

      // Check if original list exists
      final listRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uId)
          .collection('lists')
          .doc(lId);
      final listSnap = await listRef.get();
      if (!listSnap.exists) {
        debugPrint(
            'Sync Error: Original list does not exist at users/$uId/lists/$lId');
        return SyncResult(success: false);
      }

      final List<String> logos = [];
      int shopCount = 0;

      final data = listSnap.data();
      final type = data?['type'] as String?;
      final filters = data?['filters'] as Map<String, dynamic>?;
      final tags = ((filters?['tags'] as List?)?.cast<String>()) ?? [];

      if (type == 'filter' && tags.isNotEmpty) {
        // Handle tag-based "Smart Collection"
        final shopsSnap = await FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .where('tags', arrayContainsAny: tags)
            .limit(20) // Don't fetch everything, just enough for count/logos
            .get();

        shopCount = shopsSnap.docs.length;
        for (var doc in shopsSnap.docs) {
          final logo = doc.data()['logoUrl'] as String?;
          if (logo != null && logo.isNotEmpty && logos.length < 4) {
            logos.add(logo);
          }
        }
      } else {
        // Handle custom items-based collection
        final itemsSnap = await listRef.collection('items').get();
        shopCount = itemsSnap.docs.length;

        for (var doc in itemsSnap.docs) {
          final rawShopId = doc.data()['shopId'];
          final String shopId = _extractId(rawShopId);

          if (shopId.isNotEmpty) {
            final shopDoc = await FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .get();
            final shopData = shopDoc.data();
            final logo = shopData?['logoUrl'] as String?;
            final name = shopData?['name'] as String? ?? 'Unknown Cafe';

            if (logo != null && logo.isNotEmpty) {
              if (logos.length < 4) logos.add(logo);
            } else {
              missingLogos.add({'id': shopId, 'name': name});
            }
          }
        }
      }

      final sharedDocs = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .where('listId', isEqualTo: lId)
          .where('userId', isEqualTo: uId)
          .get();

      if (sharedDocs.docs.isEmpty) {
        debugPrint(
            'Sync Note: No public sharing found for user $uId, list $lId');
        return SyncResult(success: true, missingLogos: missingLogos);
      }

      for (var doc in sharedDocs.docs) {
        if (deleteIfEmpty && logos.isEmpty && shopCount == 0) {
          debugPrint('Sync: Deleting empty shared collection ${doc.id}');
          await doc.reference.delete();
        } else {
          await doc.reference.update({
            'previewLogos': logos,
            'shopCount': shopCount,
            'lastSynced': FieldValue.serverTimestamp(),
          });
        }
      }
      return SyncResult(success: true, missingLogos: missingLogos);
    } catch (e) {
      debugPrint('Error syncing shared logos: $e');
      return SyncResult(success: false);
    }
  }

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
      useRootNavigator: true,
      showDragHandle: true,
      enableDrag: true,
      isDismissible: true,
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
  String? _headerImageUrl;
  String? _currentTitle;

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.title;
  }

  @override
  Widget build(BuildContext context) {
    // We wrap in a Scaffold solely for the Snackbar support and structure,
    // but the parent is a ModalBottomSheet, so we constrain height.
    return Container(
      height: MediaQuery.of(context).size.height * 0.92, // Almost full screen
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: (widget.listId != null && widget.userId != null)
            ? FloatingActionButton(
                backgroundColor: primary,
                child: const Icon(Icons.add, color: Colors.white),
                onPressed: () => _showAddCafeDialog(context),
              )
            : null,
        body: CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            _buildActionButtons(context),
            _buildListContent(context),
            const SliverToBoxAdapter(
                child: SizedBox(height: 100)), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.black,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down,
            color: Colors.white, size: 32),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        if (widget.listId != null && widget.userId != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _showDeleteListConfirmation(context),
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Dynamic Header Image Background (Blurred)
            if (_headerImageUrl != null)
              Image.network(
                _headerImageUrl!,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                errorBuilder: (_, __, ___) =>
                    Container(color: primary.withValues(alpha: 0.3)),
              )
            else
              Container(
                color: primary.withValues(alpha: 0.2),
                child: Center(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                ),
              ),

            // Blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Placeholder for "Playlist" label or similar
                  TextWidget(
                    text: widget.filterTags != null
                        ? 'FILTER COLLECTION'
                        : 'COLLECTION',
                    fontSize: 12,
                    color: Colors.white70,
                    // isBold: true,
                    // letterSpacing: 1.5,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _currentTitle ?? widget.title,
                          style: const TextStyle(
                            fontSize: 32, // Big title
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Baloo2',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.userId != null &&
                          widget.userId ==
                              FirebaseAuth.instance.currentUser?.uid)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white70, size: 24),
                          onPressed: () => _showEditTitleDialog(context),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Metadata row would be nice here (e.g. "by User • 5 cafes")
                  if (widget.userId != null &&
                      widget.userId == FirebaseAuth.instance.currentUser?.uid)
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 10,
                          backgroundImage: AssetImage('assets/images/logo.png'),
                          // Ideally user avatar
                        ),
                        const SizedBox(width: 8),
                        TextWidget(
                          text: 'You',
                          fontSize: 14,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (widget.listId == null ||
        widget.userId == null ||
        widget.userId != FirebaseAuth.instance.currentUser?.uid) {
      return const SliverToBoxAdapter(child: SizedBox(height: 16));
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            // Privacy Toggle
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .collection('lists')
                  .doc(widget.listId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final isPrivate = data?['isPrivate'] ?? false;
                return TextButton.icon(
                  onPressed: () => _togglePrivacy(context, isPrivate),
                  icon: Icon(
                    isPrivate ? Icons.lock : Icons.public,
                    color: isPrivate ? Colors.grey : primary,
                    size: 20,
                  ),
                  label: TextWidget(
                    text: isPrivate ? 'Private' : 'Public',
                    fontSize: 14,
                    color: isPrivate ? Colors.grey : primary,
                    isBold: true,
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
            const Spacer(),
            // Share Button logic moved or kept?
            // The previous logic for share was "Check and Share".
            // We can add a simple share button icon here.
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white70),
              onPressed: () => _checkAndShareCollection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(BuildContext context) {
    // Logic from old build() to determine source

    // Since we need to update _headerImageUrl, we should do it when we get data.
    // But build() cannot set state.
    // We can use a post-frame callback or just direct assignment if we are careful (but redundant renders).
    // Or just let the first item render inform the header.
    // Actually, standard StreamBuilder is fine. We will extract the image URL from the first item in the list.

    if (widget.shopsList != null) {
      final shops = widget.shopsList!
          .where((s) => !_removedShopIds.contains(s['id']))
          .toList();
      if (shops.isNotEmpty && _headerImageUrl == null) {
        final firstLogo = shops.first['logoUrl'] as String?;
        if (firstLogo != null && firstLogo.isNotEmpty) {
          // Scheduling update to avoid build error
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _headerImageUrl != firstLogo)
              setState(() => _headerImageUrl = firstLogo);
          });
        }
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final data = shops[index];
            return _buildSpotifyCafeRow(
              index: index,
              data: data,
              shopId: data['id'],
              name: (data['name'] as String?) ?? 'Cafe',
              logo: (data['logoUrl'] as String?) ?? '',
            );
          },
          childCount: shops.length,
        ),
      );
    }

    if (widget.shopsStream != null) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.shopsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()));
            final docs = snapshot.data!.docs;
            _updateHeaderImage(docs.map((d) => d.data()).toList());

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final shop = docs[index];
                  final data = shop.data();
                  return _buildSpotifyCafeRow(
                    index: index,
                    data: data,
                    shopId: shop.id,
                    name: (data['name'] as String?) ?? 'Cafe',
                    logo: (data['logoUrl'] as String?) ?? '',
                  );
                },
                childCount: docs.length,
              ),
            );
          });
    }

    if (widget.itemsStream != null) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.itemsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()));
          final items = snapshot.data!.docs.where((i) {
            final sid = (i.data()['shopId'] as String?) ?? i.id;
            return !_removedShopIds.contains(sid);
          }).toList();

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                final shopId = (item.data()['shopId'] as String?) ?? item.id;

                // Need to fetch shop details
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .snapshots(),
                  builder: (context, shopSnap) {
                    final shopData = shopSnap.data?.data() ?? {};
                    final name = (shopData['name'] as String?) ?? 'Cafe';
                    final logo = (shopData['logoUrl'] as String?) ?? '';

                    // Attempt to set header image from first item
                    if (index == 0 &&
                        logo.isNotEmpty &&
                        _headerImageUrl == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _headerImageUrl = logo);
                      });
                    }

                    return _buildSpotifyCafeRow(
                      index: index,
                      data: shopData,
                      shopId: shopId,
                      name: name,
                      logo: logo,
                    );
                  },
                );
              },
              childCount: items.length,
            ),
          );
        },
      );
    }

    // shopIdsStream
    if (widget.shopIdsStream != null) {
      return StreamBuilder<List<String>>(
          stream: widget.shopIdsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()));
            final ids = snapshot.data!
                .where((id) => !_removedShopIds.contains(id))
                .toList();

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final shopId = ids[index];
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .snapshots(),
                    builder: (context, shopSnap) {
                      final shopData = shopSnap.data?.data() ?? {};
                      final name = (shopData['name'] as String?) ?? 'Cafe';
                      final logo = (shopData['logoUrl'] as String?) ?? '';
                      if (index == 0 &&
                          logo.isNotEmpty &&
                          _headerImageUrl == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _headerImageUrl = logo);
                        });
                      }
                      return _buildSpotifyCafeRow(
                        index: index,
                        data: shopData,
                        shopId: shopId,
                        name: name,
                        logo: logo,
                      );
                    },
                  );
                },
                childCount: ids.length,
              ),
            );
          });
    }

    return const SliverToBoxAdapter(child: SizedBox());
  }

  void _updateHeaderImage(List<Map<String, dynamic>> items) {
    if (items.isNotEmpty && _headerImageUrl == null) {
      final firstLogo = items.first['logoUrl'] as String?;
      if (firstLogo != null && firstLogo.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _headerImageUrl != firstLogo)
            setState(() => _headerImageUrl = firstLogo);
        });
      }
    }
  }

  Widget _buildSpotifyCafeRow({
    required int index,
    required Map<String, dynamic> data,
    required String shopId,
    required String name,
    required String logo,
  }) {
    final isOwner = widget.userId != null &&
        widget.userId == FirebaseAuth.instance.currentUser?.uid;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextWidget(
            text: '${index + 1}',
            fontSize: 14,
            color: Colors.grey,
            isBold: false, // Index number
          ),
          const SizedBox(width: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[800],
            ),
            child: logo.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: logo,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const Icon(Icons.error),
                    ),
                  )
                : const Icon(Icons.local_cafe, color: Colors.white54),
          ),
        ],
      ),
      title: TextWidget(
        text: name,
        fontSize: 16,
        color: Colors.white,
        isBold: true,
        maxLines: 1,
      ),
      // subtitles like "Cafe • Distance" could go here if we had data
      trailing: isOwner
          ? IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              onPressed: () => _showItemOptions(context, shopId, name),
            )
          : const Icon(Icons.arrow_forward_ios,
              size: 14, color: Colors.white54),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsScreen(
              shopId: shopId,
              shop: {'name': name, 'logoUrl': logo},
            ),
          ),
        );
      },
    );
  }

  void _showItemOptions(BuildContext context, String shopId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Remove from collection',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Close options
                _showRemoveConfirmation(
                  context: context,
                  shopId: shopId,
                  listId: widget.listId!,
                  userId: widget.userId!,
                  cafeName: name,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Logic Methods (Copied & Adapted) ---

  Future<void> _togglePrivacy(BuildContext context, bool isPrivate) async {
    final newPrivacy = !isPrivate;
    final isNowPublic = !newPrivacy;

    final confirmMessage = isNowPublic
        ? 'People in Community will be able to discover this collection.'
        : 'The collection will disappear from Community but remain available to you.';

    final confirmTitle =
        isNowPublic ? 'Make collection public?' : 'Make collection private?';
    final confirmButton = isNowPublic ? 'Make public' : 'Make private';
    final confirmIcon = isNowPublic ? Icons.public : Icons.lock;

    final confirmed = await CustomDialog.confirm(
      context: context,
      title: confirmTitle,
      message: confirmMessage,
      confirmText: confirmButton,
      icon: confirmIcon,
    );
    if (!confirmed) return;

    try {
      // 1. Update local list privacy
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .update({'isPrivate': newPrivacy});

      // 2. Sync to sharedCollections
      final sharedDocsQuery = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .where('listId', isEqualTo: widget.listId)
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (sharedDocsQuery.docs.isNotEmpty) {
        for (var doc in sharedDocsQuery.docs) {
          await doc.reference.update({
            'isPrivate': !isNowPublic,
          });
        }
      } else if (isNowPublic) {
        // Fetch current user name for attribution
        String sharedByName = 'User';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
          if (userDoc.exists) {
            final name = (userDoc.data()?['name'] as String?)?.trim();
            if (name != null && name.isNotEmpty) {
              sharedByName = name;
            } else {
              sharedByName =
                  FirebaseAuth.instance.currentUser?.displayName ?? 'User';
            }
          }
        } catch (e) {
          debugPrint('Error fetching user name for attribution: $e');
        }

        await FirebaseFirestore.instance.collection('sharedCollections').add({
          'userId': widget.userId,
          'listId': widget.listId,
          'title': _currentTitle ?? widget.title,
          'sharedBy': sharedByName,
          'sharedAt': FieldValue.serverTimestamp(),
          'shopCount': 0,
          'isPrivate': false,
          'previewLogos': [],
        });
      }

      if (isNowPublic) {
        await ListBottomSheet.syncLogos(widget.userId!, widget.listId!);
      }

      if (context.mounted) {
        _showStatusDialog(
          context,
          isNowPublic
              ? 'Collection is now Public'
              : 'Collection is now Private',
          isSuccess: true,
          icon: isNowPublic ? Icons.public : Icons.lock,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showStatusDialog(
            context, 'We could not update the collection privacy.',
            isSuccess: false);
      }
    }
  }

  void _showStatusDialog(BuildContext context, String message,
      {required bool isSuccess, IconData? icon, VoidCallback? onConfirm}) {
    if (isSuccess) {
      CustomToast.showSuccess(context, message);
    } else {
      CustomToast.showError(context, message);
    }
    onConfirm?.call();
  }

  Future<void> _showDeleteListConfirmation(BuildContext context) async {
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Delete collection?',
      message:
          '"${_currentTitle ?? widget.title}" and its saved cafés will be permanently removed.',
      confirmText: 'Delete collection',
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (confirmed && context.mounted) await _removeList(context);
  }

  Future<void> _removeList(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .delete();

      // Also delete shared
      final shared = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .where('listId', isEqualTo: widget.listId)
          .where('userId', isEqualTo: widget.userId)
          .get();
      for (var doc in shared.docs) {
        await doc.reference.delete();
      }

      if (context.mounted) {
        // Show success feedback FIRST, then pop on OK
        _showStatusDialog(
          context,
          'The collection was permanently deleted.',
          isSuccess: true,
          icon: Icons.delete_outline,
          onConfirm: () {
            if (context.mounted) {
              Navigator.of(context).pop(); // Pop the BottomSheet
            }
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showStatusDialog(context, 'We could not delete the collection.',
            isSuccess: false);
      }
    }
  }

  void _showAddCafeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => AddCafeBottomSheet(
        listId: widget.listId!,
        userId: widget.userId!,
        onCafeAdded: () {
          // ItemsStream will handle UI updates
        },
      ),
    );
  }

  void _showEditTitleDialog(BuildContext context) {
    final controller = TextEditingController(text: _currentTitle);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(
                  text: 'Rename Collection',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Collection Name',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: TextWidget(
                        text: 'Cancel', fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final newTitle = controller.text.trim();
                      if (newTitle.isNotEmpty && newTitle != _currentTitle) {
                        Navigator.pop(context);
                        _updateTitle(newTitle);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const TextWidget(
                        text: 'Save',
                        fontSize: 16,
                        color: Colors.white,
                        isBold: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateTitle(String newTitle) async {
    try {
      // 1. Update local state
      setState(() => _currentTitle = newTitle);

      // 2. Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .update(
              {'name': newTitle, 'updatedAt': FieldValue.serverTimestamp()});

      // 3. Update Shared (if exists)
      final sharedQuery = await FirebaseFirestore.instance
          .collection('sharedCollections')
          .where('listId', isEqualTo: widget.listId)
          .where('userId', isEqualTo: widget.userId)
          .get();

      for (var doc in sharedQuery.docs) {
        await doc.reference.update({'title': newTitle});
      }

      if (mounted) {
        _showStatusDialog(context, 'The collection name was updated.',
            isSuccess: true, icon: Icons.edit_note);
      }
    } catch (e) {
      if (mounted) {
        _showStatusDialog(context, 'We could not rename the collection.',
            isSuccess: false);
      }
    }
  }

  void _showRemoveConfirmation({
    required BuildContext context,
    required String shopId,
    required String listId,
    required String userId,
    required String cafeName,
  }) {
    _removeCafeFromList(
      context: context,
      shopId: shopId,
      listId: listId,
      userId: userId,
      cafeName: cafeName,
    );
  }

  Future<void> _syncSharedCollectionLogos() async {
    await ListBottomSheet.syncLogos(widget.userId!, widget.listId!);
  }

  void _removeCafeFromList({
    required BuildContext context,
    required String shopId,
    required String listId,
    required String userId,
    required String cafeName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(shopId)
          .delete();

      // Clear sync after deletion
      await _syncSharedCollectionLogos();

      if (mounted) {
        setState(() {
          _removedShopIds.add(shopId);
        });
        CustomToast.showFromMessenger(
          messenger,
          '$cafeName was removed from this collection.',
          type: ToastType.info,
          title: 'Café removed',
          actionLabel: 'Undo',
          onAction: () => _restoreCafeToList(
            shopId: shopId,
            listId: listId,
            userId: userId,
            cafeName: cafeName,
          ),
        );
      }
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'We could not remove the café. Please try again.',
        type: ToastType.error,
        title: 'Collection not updated',
      );
    }
  }

  Future<void> _restoreCafeToList({
    required String shopId,
    required String listId,
    required String userId,
    required String cafeName,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('lists')
          .doc(listId)
          .collection('items')
          .doc(shopId)
          .set({
        'shopId': shopId,
        'name': cafeName,
        'addedAt': FieldValue.serverTimestamp(),
      });
      await _syncSharedCollectionLogos();
      if (!mounted) return;
      setState(() => _removedShopIds.remove(shopId));
      CustomToast.showSuccess(
        context,
        '$cafeName is back in the collection.',
        title: 'Removal undone',
      );
    } catch (_) {
      if (!mounted) return;
      CustomToast.showError(
        context,
        'We could not restore the café. Add it again from the collection.',
        title: 'Undo failed',
      );
    }
  }

  void _checkAndShareCollection(BuildContext context) async {
    if (widget.listId == null || widget.userId == null) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sharing coming soon')));
  }

  Future<List<String>> _getPreviewLogos() async {
    try {
      if (widget.shopsList != null && widget.shopsList!.isNotEmpty) {
        return widget.shopsList!
            .map((s) => (s['logoUrl'] as String?) ?? '')
            .where((url) => url.isNotEmpty)
            .take(4)
            .toList();
      }

      final itemsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .collection('items')
          .limit(4)
          .get();

      final List<String> logos = [];
      for (var doc in itemsSnap.docs) {
        final shopId = doc.data()['shopId'] as String?;
        if (shopId != null) {
          final shopDoc = await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .get();
          final logo = shopDoc.data()?['logoUrl'] as String?;
          if (logo != null && logo.isNotEmpty) {
            logos.add(logo);
          }
        }
      }
      return logos;
    } catch (e) {
      return [];
    }
  }
}

class AddCafeBottomSheet extends StatefulWidget {
  final String listId;
  final String userId;
  final VoidCallback onCafeAdded;

  const AddCafeBottomSheet({
    super.key,
    required this.listId,
    required this.userId,
    required this.onCafeAdded,
  });

  @override
  State<AddCafeBottomSheet> createState() => _AddCafeBottomSheetState();
}

class _AddCafeBottomSheetState extends State<AddCafeBottomSheet> {
  late TextEditingController _searchController;
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Auto focus the search field after bottom sheet animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey[900], // Premium dark background
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const TextWidget(
                  text: 'Add to Collection',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search for a cafe...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white54, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.black26,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                      color: primary.withValues(alpha: 0.5), width: 1),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Cafe List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('shops').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final searchText = _searchController.text.toLowerCase();
                final cafes = snapshot.data!.docs.where((doc) {
                  final name = (doc['name'] as String? ?? '').toLowerCase();
                  return name.contains(searchText);
                }).toList();

                if (cafes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        TextWidget(
                          text: 'No cafes found',
                          fontSize: 16,
                          color: Colors.white54,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: cafes.length,
                  separatorBuilder: (context, index) => const Divider(
                      color: Colors.white10, height: 1, indent: 86),
                  itemBuilder: (context, index) {
                    final cafe = cafes[index];
                    final cafeName = cafe['name'] as String? ?? 'Unknown';
                    final cafeId = cafe.id;
                    final cafeLogoUrl = cafe['logoUrl'] as String? ?? '';

                    return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('lists')
                            .doc(widget.listId)
                            .collection('items')
                            .doc(cafeId)
                            .snapshots(),
                        builder: (context, itemSnapshot) {
                          final isAdded =
                              itemSnapshot.hasData && itemSnapshot.data!.exists;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: cafeLogoUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: cafeLogoUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(color: Colors.black26),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.local_cafe,
                                                color: Colors.white30),
                                      ),
                                    )
                                  : const Icon(Icons.local_cafe,
                                      color: Colors.white30),
                            ),
                            title: TextWidget(
                              text: cafeName,
                              fontSize: 16,
                              color: Colors.white,
                              isBold: true,
                            ),
                            subtitle: TextWidget(
                              text: 'Cafe',
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                            trailing: isAdded
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check,
                                            color: Colors.white70, size: 16),
                                        const SizedBox(width: 4),
                                        TextWidget(
                                          text: 'Added',
                                          fontSize: 12,
                                          color: Colors.white70,
                                          isBold: true,
                                        ),
                                      ],
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    color: primary,
                                    iconSize: 28,
                                    onPressed: () =>
                                        _addCafeToList(cafeId, cafeName),
                                  ),
                          );
                        });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCafeToList(String cafeId, String cafeName) async {
    try {
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
        // Sync logos after adding
        await ListBottomSheet.syncLogos(widget.userId, widget.listId);
        widget.onCafeAdded();
      }
    } catch (_) {
      if (mounted) {
        CustomToast.showError(
          context,
          'We could not add the café. Please try again.',
          title: 'Collection not updated',
        );
      }
    }
  }
}
