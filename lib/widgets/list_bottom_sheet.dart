import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui'; // For BackdropFilter

class SyncResult {
  final bool success;
  final List<Map<String, String>> missingLogos; // List of {id: shopId, name: shopName}
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

  static Future<SyncResult> syncLogos(dynamic userId, dynamic listId, {bool deleteIfEmpty = false}) async {
    final List<Map<String, String>> missingLogos = [];
    try {
      final String uId = _extractId(userId);
      final String lId = _extractId(listId);

      if (uId.isEmpty || lId.isEmpty) {
        debugPrint('Sync Error: Missing IDs (u:$uId, l:$lId)');
        return SyncResult(success: false);
      }

      // Check if original list exists
      final listRef = FirebaseFirestore.instance.collection('users').doc(uId).collection('lists').doc(lId);
      final listSnap = await listRef.get();
      if (!listSnap.exists) {
        debugPrint('Sync Error: Original list does not exist at users/$uId/lists/$lId');
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
        debugPrint('Sync Note: No public sharing found for user $uId, list $lId');
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
             const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
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
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
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
                            errorBuilder: (_,__,___) => Container(color: primary.withOpacity(0.3)),
                        )
                     else
                        Container(
                            color: primary.withOpacity(0.2),
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
                        child: Container(color: Colors.black.withOpacity(0.5)),
                    ),

                    // Gradient Overlay
                    Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.8),
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
                                    text: widget.filterTags != null ? 'FILTER COLLECTION' : 'COLLECTION',
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
                                        if (widget.userId != null && widget.userId == FirebaseAuth.instance.currentUser?.uid)
                                           IconButton(
                                               icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 24),
                                               onPressed: () => _showEditTitleDialog(context),
                                           ),
                                    ],
                                ),
                                const SizedBox(height: 8),
                                // Metadata row would be nice here (e.g. "by User • 5 cafes")
                                if (widget.userId != null && widget.userId == FirebaseAuth.instance.currentUser?.uid)
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
      if (widget.listId == null || widget.userId == null || widget.userId != FirebaseAuth.instance.currentUser?.uid) {
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
                                        backgroundColor: Colors.white.withOpacity(0.05),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          final shops = widget.shopsList!.where((s) => !_removedShopIds.contains(s['id'])).toList();
           if (shops.isNotEmpty && _headerImageUrl == null) {
               final firstLogo = shops.first['logoUrl'] as String?;
               if (firstLogo != null && firstLogo.isNotEmpty) {
                   // Scheduling update to avoid build error
                   WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted && _headerImageUrl != firstLogo) setState(() => _headerImageUrl = firstLogo);
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
                  if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
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
              }
          );
      }
      
      if (widget.itemsStream != null) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.itemsStream,
              builder: (context, snapshot) {
                 if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
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
                                 stream: FirebaseFirestore.instance.collection('shops').doc(shopId).snapshots(),
                                 builder: (context, shopSnap) {
                                     final shopData = shopSnap.data?.data() ?? {};
                                     final name = (shopData['name'] as String?) ?? 'Cafe';
                                     final logo = (shopData['logoUrl'] as String?) ?? '';
                                     
                                     // Attempt to set header image from first item
                                     if (index == 0 && logo.isNotEmpty && _headerImageUrl == null) {
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
                   if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                   final ids = snapshot.data!.where((id) => !_removedShopIds.contains(id)).toList();
                   
                    return SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (context, index) {
                             final shopId = ids[index];
                             return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                 stream: FirebaseFirestore.instance.collection('shops').doc(shopId).snapshots(),
                                 builder: (context, shopSnap) {
                                     final shopData = shopSnap.data?.data() ?? {};
                                     final name = (shopData['name'] as String?) ?? 'Cafe';
                                     final logo = (shopData['logoUrl'] as String?) ?? '';
                                     if (index == 0 && logo.isNotEmpty && _headerImageUrl == null) {
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
              }
          );
        }

      return const SliverToBoxAdapter(child: SizedBox());
  }

  void _updateHeaderImage(List<Map<String, dynamic>> items) {
       if (items.isNotEmpty && _headerImageUrl == null) {
           final firstLogo = items.first['logoUrl'] as String?;
           if (firstLogo != null && firstLogo.isNotEmpty) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                   if (mounted && _headerImageUrl != firstLogo) setState(() => _headerImageUrl = firstLogo);
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
      final isOwner = widget.userId != null && widget.userId == FirebaseAuth.instance.currentUser?.uid;
      
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
                                  errorWidget: (_,__,___) => const Icon(Icons.error),
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
             : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
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
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) => SafeArea(
              child: Wrap(
                  children: [
                      ListTile(
                          leading: const Icon(Icons.delete, color: Colors.redAccent),
                          title: const Text('Remove from collection', style: TextStyle(color: Colors.white)),
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

    // ADDED: Confirmation for BOTH directions
    final confirmMessage = isNowPublic
        ? 'Making this list Public will share it with the community in the Explore tab. Continue?'
        : 'Making this list Private will remove it from the Community tab. Are you sure?';
    
    final confirmTitle = isNowPublic ? 'Unlock List?' : 'Make Private?';
    final confirmButton = isNowPublic ? 'Make Public' : 'Make Private';
    final confirmIcon = isNowPublic ? Icons.public : Icons.lock;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(confirmIcon, color: isNowPublic ? primary : Colors.white70, size: 24),
            const SizedBox(width: 8),
            TextWidget(text: confirmTitle, fontSize: 18, color: Colors.white, isBold: true),
          ],
        ),
        content: TextWidget(
          text: confirmMessage,
          fontSize: 14,
          color: Colors.white70,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: TextWidget(text: 'Cancel', fontSize: 14, color: Colors.grey[400]),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: TextWidget(text: confirmButton, fontSize: 14, color: isNowPublic ? primary : Colors.redAccent, isBold: true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

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
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
          if (userDoc.exists) {
            final name = (userDoc.data()?['name'] as String?)?.trim();
            if (name != null && name.isNotEmpty) {
              sharedByName = name;
            } else {
              sharedByName = FirebaseAuth.instance.currentUser?.displayName ?? 'User';
            }
          }
        } catch (e) {
          debugPrint('Error fetching user name for attribution: $e');
        }

        await FirebaseFirestore.instance.collection('sharedCollections').add({
          'userId': widget.userId,
          'listId': widget.listId,
          'title': widget.title,
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
          isNowPublic ? 'Collection is now Public' : 'Collection is now Private',
          isSuccess: true,
          icon: isNowPublic ? Icons.public : Icons.lock,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showStatusDialog(context, 'Failed to update: $e', isSuccess: false);
      }
    }
  }

  void _showStatusDialog(BuildContext context, String message, {required bool isSuccess, IconData? icon, VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? primary.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? (isSuccess ? Icons.check_circle_outline : Icons.error_outline),
                  color: isSuccess ? primary : Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              TextWidget(
                text: isSuccess ? 'Success' : 'Oops!',
                fontSize: 20,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              TextWidget(
                text: message,
                fontSize: 14,
                color: Colors.white70,
                align: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (onConfirm != null) onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? primary : Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const TextWidget(text: 'OK', fontSize: 16, color: Colors.white, isBold: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteListConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 20),
              const TextWidget(text: 'Delete Collection?', fontSize: 20, color: Colors.white, isBold: true),
              const SizedBox(height: 8),
              TextWidget(
                text: 'Are you sure you want to delete "${widget.title}"? This action cannot be undone.',
                fontSize: 14,
                color: Colors.white70,
                align: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: TextWidget(text: 'Cancel', fontSize: 16, color: Colors.grey[400], isBold: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // Close confirmation dialog
                        _removeList(context); // Pass the sheet context
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const TextWidget(text: 'Delete', fontSize: 16, color: Colors.white, isBold: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeList(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('lists')
          .doc(widget.listId)
          .delete();
      
      // Also delete shared
      final shared = await FirebaseFirestore.instance.collection('sharedCollections')
          .where('listId', isEqualTo: widget.listId)
          .where('userId', isEqualTo: widget.userId)
          .get();
      for(var doc in shared.docs) {
          await doc.reference.delete();
      }

      if (context.mounted) {
        // Show success feedback FIRST, then pop on OK
        _showStatusDialog(
          context, 
          'Collection deleted successfully', 
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
        _showStatusDialog(context, 'Failed to delete: $e', isSuccess: false);
      }
    }
  }

  void _showAddCafeDialog(BuildContext context) {
      showDialog(
          context: context,
          builder: (context) => AddCafeToListDialog(
              listId: widget.listId!,
              userId: widget.userId!,
              onCafeAdded: () {
                   setState(() {}); // Refresh? Stream should handle it.
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
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextWidget(text: 'Rename Collection', fontSize: 20, color: Colors.white, isBold: true),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: TextWidget(text: 'Cancel', fontSize: 16, color: Colors.grey[400]),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const TextWidget(text: 'Save', fontSize: 16, color: Colors.white, isBold: true),
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
          .update({'name': newTitle, 'updatedAt': FieldValue.serverTimestamp()});

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
         _showStatusDialog(context, 'Title updated successfully', isSuccess: true, icon: Icons.edit_note);
      }
    } catch (e) {
      if (mounted) {
        _showStatusDialog(context, 'Failed to update title: $e', isSuccess: false);
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
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[800],
          title: TextWidget(
              text: 'Remove Cafe', fontSize: 18, color: Colors.white, isBold: true),
          content: TextWidget(
              text: 'Remove "$cafeName" from this collection?',
              fontSize: 16, color: Colors.white70),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: TextWidget(text: 'Cancel', fontSize: 14, color: Colors.grey[400]),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _removeCafeFromList(
                  context: context, 
                  shopId: shopId,
                  listId: listId,
                  userId: userId,
                  cafeName: cafeName,
                );
              },
              child: TextWidget(text: 'Remove', fontSize: 14, color: Colors.redAccent),
            ),
          ],
        );
      },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cafeName removed'),
            backgroundColor: Colors.grey[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove cafe'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _checkAndShareCollection(BuildContext context) async {
     if (widget.listId == null || widget.userId == null) return;
     
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing coming soon')));
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

// Keep AddCafeToListDialog as is from the original file (I need to copy it back or assume it's there)
// Since I'm overwriting the file, I MUST include AddCafeToListDialog.

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
        height: 600,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text(
                    'Add Cafe',
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
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
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
                            vertical: 8),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            backgroundColor: Colors.green, // Keep green for success
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Sync logos after adding
        await ListBottomSheet.syncLogos(widget.userId, widget.listId);

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
