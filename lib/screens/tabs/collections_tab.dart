import 'package:cofi/utils/colors.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/text_widget.dart';
import '../../widgets/list_bottom_sheet.dart';
import '../../widgets/create_list_bottom_sheet.dart';

class CollectionsTab extends StatefulWidget {
  const CollectionsTab({super.key});

  @override
  State<CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<CollectionsTab> {
  late final Stream<int> _favoritesCountStream;
  late final Stream<int> _visitedCountStream;
  int _lastVisitedCount = 0;
  late final Stream<int> _visitedArrayCountStream;
  int _lastVisitedArrayCount = 0;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _favoritesCountStream = Stream<int>.value(0);
      _visitedCountStream = Stream<int>.value(0);
      _visitedArrayCountStream = Stream<int>.value(0);
    } else {
      _favoritesCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) => ((doc.data()?['bookmarks'] as List?)?.length ?? 0));

      final query = FirebaseFirestore.instance
          .collectionGroup('visits')
          .where('userId', isEqualTo: user.uid);
      _visitedCountStream = query.snapshots().map((snap) {
        final uniqueShopIds = <String>{};
        for (final d in snap.docs) {
          final shopId = d.reference.parent.parent?.id;
          if (shopId != null) uniqueShopIds.add(shopId);
        }
        return uniqueShopIds.length;
      });

      _visitedArrayCountStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((doc) =>
              ((doc.data()?['visited'] as List?)?.toSet().length ?? 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextWidget(
                    text: 'Collections',
                    fontSize: 32,
                    color: Colors.white,
                    isBold: true,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => const CreateListBottomSheet(),
                        );
                      },
                      icon:
                          const Icon(Icons.add, color: Colors.white, size: 22),
                      label: TextWidget(
                        text: 'Create',
                        fontSize: 18,
                        color: Colors.white,
                        isBold: true,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white24, thickness: 1),
            // Favorites (dynamic)
            StreamBuilder<int>(
              stream: _favoritesCountStream,
              builder: (context, snap) {
                final count = snap.data ?? 0;
                return _buildCollectionItem(
                  icon: Icons.bookmark_border,
                  iconBg: primary,
                  title: 'Favorites',
                  subtitle: 'Favorite Shop${count == 1 ? '' : 's'}',
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    ListBottomSheet.show(
                      context,
                      title: 'Favorites',
                      shopIdsStream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots()
                          .map((doc) => ((doc.data()?['bookmarks'] as List?)
                                  ?.cast<String>() ??
                              <String>[])),
                    );
                  },
                );
              },
            ),
            // Visited Cafes (dynamic unique shops, all time) - combine both sources
            StreamBuilder<int>(
              stream: _visitedCountStream,
              builder: (context, visitsSnap) {
                int docsCount = _lastVisitedCount;
                if (visitsSnap.hasData) {
                  docsCount = visitsSnap.data ?? _lastVisitedCount;
                  _lastVisitedCount = docsCount;
                }
                return StreamBuilder<int>(
                  stream: _visitedArrayCountStream,
                  builder: (context, arraySnap) {
                    int arrayCount = _lastVisitedArrayCount;
                    if (arraySnap.hasData) {
                      arrayCount = arraySnap.data ?? _lastVisitedArrayCount;
                      _lastVisitedArrayCount = arrayCount;
                    }
                    final count = math.max(docsCount, arrayCount);
                    return _buildCollectionItem(
                      icon: Icons.coffee,
                      iconBg: primary,
                      title: 'Visited Cafes',
                      subtitle: '$count Shop${count == 1 ? '' : 's'}',
                      customIcon: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(
                            'assets/images/logo.png',
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/visitedCafes');
                      },
                    );
                  },
                );
              },
            ),
            const Divider(color: Colors.white24, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TextWidget(
                text: 'Cafe Lists',
                fontSize: 20,
                color: Colors.white,
                isBold: true,
              ),
            ),
            // User-created lists
            Builder(builder: (context) {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: TextWidget(
                    text: 'Sign in to create and view your lists',
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                );
              }
              final listsStream = FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('lists')
                  .orderBy('createdAt', descending: true)
                  .snapshots();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: listsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: Colors.white),
                    ));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: TextWidget(
                        text: 'No lists yet',
                        fontSize: 15,
                        color: Colors.white70,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final d in docs)
                        Builder(
                          builder: (context) {
                            final data = d.data();
                            final title =
                                (data['name'] as String?) ?? 'Untitled';
                            final type = (data['type'] as String?) ?? 'filter';
                            final filters =
                                (data['filters'] as Map<String, dynamic>?) ??
                                    {};
                            final List<String> tags =
                                ((filters['tags'] as List?)?.cast<String>()) ??
                                    const <String>[];

                            // Check if it's a custom collection or filter-based with tags
                            if (type == 'custom') {
                              // Custom collection - use items stream
                              final itemsStream = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('lists')
                                  .doc(d.id)
                                  .collection('items')
                                  .snapshots();
                              return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream: itemsStream,
                                builder: (context, itemsSnap) {
                                  final itemCount =
                                      itemsSnap.data?.docs.length ?? 0;
                                  return _buildCollectionItem(
                                    icon: Icons.local_cafe,
                                    iconBg: primary,
                                    title: title,
                                    subtitle:
                                        '$itemCount Shop${itemCount == 1 ? '' : 's'}',
                                    customIcon: const Icon(Icons.local_cafe,
                                        color: Colors.white, size: 28),
                                    onTap: () async {
                                      try {
                                        final res = await FirebaseFirestore
                                            .instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .collection('lists')
                                            .doc(d.id)
                                            .collection('items')
                                            .get();
                                        final ids = res.docs
                                            .map((doc) =>
                                                (doc.data()['shopId']
                                                    as String?) ??
                                                doc.id)
                                            .where((id) => id.isNotEmpty)
                                            .toSet()
                                            .toList();
                                        if (ids.isEmpty) {
                                          ListBottomSheet.show(
                                            context,
                                            title: title,
                                            shopsList: const <Map<String,
                                                dynamic>>[],
                                            listId: d.id,
                                            userId: user.uid,
                                          );
                                          return;
                                        }
                                        // Fetch shops in batches of 10 due to whereIn limit
                                        final List<Map<String, dynamic>>
                                            shopsList = [];
                                        const int batchSize = 10;
                                        for (var i = 0;
                                            i < ids.length;
                                            i += batchSize) {
                                          final batch = ids.sublist(
                                              i,
                                              i + batchSize > ids.length
                                                  ? ids.length
                                                  : i + batchSize);
                                          final snap = await FirebaseFirestore
                                              .instance
                                              .collection('shops')
                                              .where('isVerified',
                                                  isEqualTo: true)
                                              .where(FieldPath.documentId,
                                                  whereIn: batch)
                                              .get();
                                          shopsList
                                              .addAll(snap.docs.map((e) => {
                                                    ...e.data(),
                                                    'id': e.id,
                                                  }));
                                        }
                                        if (!mounted) return;
                                        ListBottomSheet.show(
                                          context,
                                          title: title,
                                          shopsList: shopsList,
                                          listId: d.id,
                                          userId: user.uid,
                                          filterTags:
                                              tags.isNotEmpty ? tags : null,
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to load cafes: $e')),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            } else if (tags.isNotEmpty) {
                              // Filter-based collection with tags
                              final shopsQuery = FirebaseFirestore.instance
                                  .collection('shops')
                                  .where('isVerified', isEqualTo: true)
                                  .where('tags', arrayContainsAny: tags);
                              final shopsStream = shopsQuery.snapshots();
                              return StreamBuilder<
                                  QuerySnapshot<Map<String, dynamic>>>(
                                stream: shopsStream,
                                builder: (context, shopSnap) {
                                  final count = shopSnap.data?.docs.length ?? 0;
                                  return _buildCollectionItem(
                                    icon: Icons.local_cafe,
                                    iconBg: primary,
                                    title: title,
                                    subtitle:
                                        '$count Shop${count == 1 ? '' : 's'}',
                                    customIcon: const Icon(Icons.local_cafe,
                                        color: Colors.white, size: 28),
                                    onTap: () async {
                                      try {
                                        final shopsList = shopSnap.data?.docs
                                            .map((d) => {
                                                  ...d.data(),
                                                  'id': d.id,
                                                })
                                            .toList();

                                        if (!mounted) return;
                                        ListBottomSheet.show(
                                          context,
                                          title: title,
                                          shopsList: shopsList,
                                          listId: d.id,
                                          userId: user.uid,
                                          filterTags:
                                              tags.isNotEmpty ? tags : null,
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Failed to load cafes: $e')),
                                        );
                                      }
                                    },
                                  );
                                },
                              );
                            }

                            // Fallback: items-based list
                            final itemsStream = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('lists')
                                .doc(d.id)
                                .collection('items')
                                .snapshots();
                            return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>>(
                              stream: itemsStream,
                              builder: (context, itemsSnap) {
                                final itemCount =
                                    itemsSnap.data?.docs.length ?? 0;
                                return _buildCollectionItem(
                                  icon: Icons.local_cafe,
                                  iconBg: primary,
                                  title: title,
                                  subtitle:
                                      '$itemCount Shop${itemCount == 1 ? '' : 's'}',
                                  customIcon: const Icon(Icons.local_cafe,
                                      color: Colors.white, size: 28),
                                  onTap: () async {
                                    try {
                                      final res = await FirebaseFirestore
                                          .instance
                                          .collection('users')
                                          .doc(user.uid)
                                          .collection('lists')
                                          .doc(d.id)
                                          .collection('items')
                                          .get();
                                      final ids = res.docs
                                          .map((doc) =>
                                              (doc.data()['shopId']
                                                  as String?) ??
                                              doc.id)
                                          .where((id) => id.isNotEmpty)
                                          .toSet()
                                          .toList();
                                      if (ids.isEmpty) {
                                        ListBottomSheet.show(
                                          context,
                                          title: title,
                                          shopsList: const <Map<String,
                                              dynamic>>[],
                                          listId: d.id,
                                          userId: user.uid,
                                        );
                                        return;
                                      }
                                      // Fetch shops in batches of 10 due to whereIn limit
                                      final List<Map<String, dynamic>>
                                          shopsList = [];
                                      const int batchSize = 10;
                                      for (var i = 0;
                                          i < ids.length;
                                          i += batchSize) {
                                        final batch = ids.sublist(
                                            i,
                                            i + batchSize > ids.length
                                                ? ids.length
                                                : i + batchSize);
                                        final snap = await FirebaseFirestore
                                            .instance
                                            .collection('shops')
                                            .where('isVerified',
                                                isEqualTo: true)
                                            .where(FieldPath.documentId,
                                                whereIn: batch)
                                            .get();
                                        shopsList.addAll(snap.docs.map((e) => {
                                              ...e.data(),
                                              'id': e.id,
                                            }));
                                      }
                                      if (!mounted) return;
                                      ListBottomSheet.show(
                                        context,
                                        title: title,
                                        shopsList: shopsList,
                                        listId: d.id,
                                        userId: user.uid,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to load cafes: $e')),
                                      );
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                    ],
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionItem(
      {required IconData icon,
      required Color iconBg,
      required String title,
      required String subtitle,
      Widget? customIcon,
      VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIcon ?? Icon(icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: title,
                  fontSize: 18,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(height: 2),
                TextWidget(
                  text: subtitle,
                  fontSize: 15,
                  color: Colors.white54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
