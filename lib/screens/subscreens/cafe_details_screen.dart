import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/screens/subscreens/reviews_screen.dart';
import 'package:cofi/screens/subscreens/log_visit_screen.dart';
import 'package:cofi/screens/subscreens/write_review_screen.dart';
import 'package:cofi/screens/subscreens/menu_photos_screen.dart';

class _ContactItem {
  final String label;
  final String url;
  const _ContactItem({required this.label, required this.url});
}

IconData _contactIcon(String label) {
  switch (label.toLowerCase()) {
    case 'instagram':
      return Icons.camera_alt;
    case 'facebook':
      return Icons.facebook;
    case 'tiktok':
      return Icons.music_note;
    default:
      return Icons.link;
  }
}

class _BookmarkButton extends StatelessWidget {
  final String? shopId;
  const _BookmarkButton({required this.shopId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || shopId == null) {
      return const Icon(Icons.bookmark_border, color: Colors.white);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final List bookmarks = (data['bookmarks'] as List?) ?? const [];
        final bool isBookmarked = bookmarks.contains(shopId);
        return IconButton(
          icon: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: Colors.white,
          ),
          onPressed: () async {
            final ref =
                FirebaseFirestore.instance.collection('users').doc(user.uid);
            try {
              if (isBookmarked) {
                await ref.update({
                  'bookmarks': FieldValue.arrayRemove([shopId])
                });
              } else {
                await ref.update({
                  'bookmarks': FieldValue.arrayUnion([shopId])
                });
              }
            } catch (_) {
              await ref.set({
                'bookmarks': isBookmarked ? [] : [shopId],
              }, SetOptions(merge: true));
            }
          },
        );
      },
    );
  }
}

class CafeDetailsScreen extends StatelessWidget {
  final String? shopId;
  final Map<String, dynamic>? shop;

  const CafeDetailsScreen({super.key, this.shopId, this.shop});

  @override
  Widget build(BuildContext context) {
    // If we have a shopId, fetch the latest data from Firestore
    if (shopId != null && shopId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: TextWidget(
                  text: 'Error loading shop details',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            );
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: TextWidget(
                  text: 'Shop not found',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            );
          }

          return _buildContent(context, data);
        },
      );
    }

    // If we don't have a shopId, use the provided shop data
    return _buildContent(context, shop ?? const <String, dynamic>{});
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> s) {
    final String name = (s['name'] ?? '') as String;
    final String address = (s['address'] ?? '') as String;
    final String about = (s['about'] ?? '') as String;
    final List<String> tags = (s['tags'] as List?)?.cast<String>() ?? const [];
    final Map<String, dynamic> schedule =
        (s['schedule'] ?? {}) as Map<String, dynamic>;
    final num ratings = (s['ratings'] is num) ? s['ratings'] as num : 0;
    final List reviews = (s['reviews'] as List?) ?? const [];
    final String ratingText =
        '${ratings.toStringAsFixed(1)} (${reviews.length}) · Verified';
    final String scheduleText = _scheduleToText(schedule);
    final Map<String, dynamic> contacts =
        (s['contacts'] ?? {}) as Map<String, dynamic>;

    // Get location data
    final double latitude =
        (s['latitude'] is num) ? s['latitude'].toDouble() : 0.0;
    final double longitude =
        (s['longitude'] is num) ? s['longitude'].toDouble() : 0.0;

    // Get logo URL
    final String? logoUrl = s['logoUrl'] as String?;

    // Get menu/price photos
    final List<String> menuPricePhotos =
        (s['menuPricePhotos'] as List?)?.cast<String>() ?? const [];

    // Get gallery photos
    final List<String> gallery =
        (s['gallery'] as List?)?.cast<String>() ?? const [];

    // Build contacts with links
    final List<_ContactItem> contactItems = [];
    void addContact(String label, dynamic value) {
      final v = (value ?? '').toString().trim();
      if (v.isEmpty) return;
      String url = v;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // If provided is a handle or bare link, default to https
        url = 'https://$url';
      }
      contactItems.add(_ContactItem(label: label, url: url));
    }

    addContact('Instagram', contacts['instagram']);
    addContact('Facebook', contacts['facebook']);
    addContact('Tiktok', contacts['tiktok']);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section with gallery slider
                  Stack(
                    children: [
                      _buildGallerySlider(
                        galleryImages: gallery.isNotEmpty
                            ? gallery
                            : [logoUrl ?? '']
                                .where((url) => url.isNotEmpty)
                                .toList(),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: _BookmarkButton(shopId: shopId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderRatingWidget(shopId, ratings,
                                      reviews.length, ratingText),
                                  const SizedBox(height: 4),
                                  TextWidget(
                                    text: name,
                                    fontSize: 28,
                                    color: Colors.white,
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ),
                            if (logoUrl != null && logoUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundImage: NetworkImage(logoUrl),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey[800],
                                  child: const Icon(Icons.local_cafe,
                                      color: Colors.white70, size: 24),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            spacing: 8,
                            children: tags.isNotEmpty
                                ? tags.map((t) => _buildChip(t)).toList()
                                : [
                                    _buildChip('Cafe'),
                                  ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSection('About', about.isNotEmpty ? about : '—'),
                  SizedBox(
                    height: 10,
                  ),
                  _buildSection('Address', address.isNotEmpty ? address : '—'),
                  SizedBox(
                    height: 10,
                  ),
                  // Map section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: latitude != 0.0 && longitude != 0.0
                          ? _CafeMap(latitude: latitude, longitude: longitude)
                          : const Center(
                              child: Icon(Icons.map,
                                  color: Colors.white38, size: 60),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSection(
                      'Schedule', scheduleText.isNotEmpty ? scheduleText : '—'),
                  const SizedBox(height: 32),
                  _buildContactsSection(contactItems),
                  const SizedBox(height: 32),
                  _buildMenuSection(context, name, menuPricePhotos),
                  const SizedBox(height: 32),
                  (shopId != null && shopId!.isNotEmpty)
                      ? _buildReviewsSummaryStream(shopId!)
                      : _buildReviewsSummary(reviews),
                  (shopId != null && shopId!.isNotEmpty)
                      ? _buildReviewsSectionStream(shopId!)
                      : _buildReviewsSection(reviews),
                  // Add extra padding to ensure content isn't hidden behind fixed buttons
                  const SizedBox(height: 200),
                ],
              ),
            ),
            // Fixed action buttons at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildActionButtons(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRatingWidget(
      String? shopId, num ratings, int embeddedCount, String fallbackText) {
    if (shopId != null && shopId.isNotEmpty) {
      final query = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('reviews');
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? const [];
          final ratingValues = docs
              .map((d) => d.data()['rating'])
              .whereType<num>()
              .map((n) => n.toDouble())
              .toList();
          final count = ratingValues.length;
          final avg =
              count == 0 ? 0.0 : ratingValues.reduce((a, b) => a + b) / count;
          final text = '${avg.toStringAsFixed(1)} ($count) · Verified';
          return Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              TextWidget(text: text, fontSize: 14, color: Colors.white),
            ],
          );
        },
      );
    }
    // Fallback to provided values if no shopId
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 20),
        const SizedBox(width: 4),
        TextWidget(text: fallbackText, fontSize: 14, color: Colors.white),
      ],
    );
  }

  Widget _buildReviewsSummary(List reviews) {
    double avg = 0;
    int count = 0;
    if (reviews.isNotEmpty) {
      final ratings = reviews
          .map((r) {
            final m = (r is Map) ? r : const {};
            final v = m['rating'];
            if (v is num) return v.toDouble();
            return 0.0;
          })
          .where((v) => v > 0)
          .toList();
      if (ratings.isNotEmpty) {
        count = ratings.length;
        avg = ratings.reduce((a, b) => a + b) / count;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'Reviews',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          if (count == 0)
            TextWidget(
              text: 'No reviews yet',
              fontSize: 14,
              color: Colors.white70,
            )
          else
            Row(
              children: [
                TextWidget(
                  text: avg.toStringAsFixed(1),
                  fontSize: 32,
                  color: Colors.white,
                  isBold: true,
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                TextWidget(
                  text: '$count Reviews',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _scheduleToText(Map<String, dynamic> schedule) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    String cap(String s) =>
        s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
    final lines = <String>[];
    for (final d in days) {
      final day = (schedule[d] ?? {}) as Map<String, dynamic>;
      final isOpen = (day['isOpen'] ?? false) == true;
      final open = (day['open'] ?? '') as String;
      final close = (day['close'] ?? '') as String;
      if (isOpen && open.isNotEmpty && close.isNotEmpty) {
        lines.add('${cap(d)} · ${_to12h(open)} - ${_to12h(close)}');
      } else {
        lines.add('${cap(d)} · Closed');
      }
    }
    return lines.join('\n');
  }

  String _to12h(String hhmm) {
    // Expecting HH:mm
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm $period';
  }

  Widget _buildChip(String label) {
    return Chip(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          TextWidget(
            text: label,
            fontSize: 14,
            color: Colors.white,
          ),
        ],
      ),
      backgroundColor: primary,
    );
  }

  Widget _buildSection(String title, String content, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: title,
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          if (title == 'Schedule')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.split('\n').map((line) {
                final parts = line.split('·');
                return Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: parts[0].trim(),
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    TextWidget(
                      text: '•',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    TextWidget(
                      text: parts.length > 1 ? parts[1].trim() : '',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ],
                );
              }).toList(),
            )
          else if (title == 'Contacts')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.split('\n').map((contact) {
                IconData? icon;
                switch (contact.trim().toLowerCase()) {
                  case 'instagram':
                    icon = Icons.camera_alt;
                    break;
                  case 'facebook':
                    icon = Icons.facebook;
                    break;
                  case 'tiktok':
                    icon = Icons.music_note;
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      TextWidget(
                        text: contact.trim(),
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
          else if (icon != null)
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                TextWidget(
                  text: content,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ],
            )
          else
            TextWidget(
              text: content,
              fontSize: 16,
              color: Colors.white,
            ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(
      BuildContext context, String shopName, List<String> menuPricePhotos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'Menu',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MenuPhotosScreen(
                    menuPhotos: menuPricePhotos,
                    shopName: shopName,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu_book,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextWidget(
                      text: menuPricePhotos.isEmpty
                          ? 'No menu photos available'
                          : 'Tap to view Menu (${menuPricePhotos.length} photos)',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySlider({required List<String> galleryImages}) {
    final images = galleryImages.where((url) => url.isNotEmpty).toList();

    if (images.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18), bottom: Radius.circular(18)),
        ),
        child: const Center(
          child: Icon(Icons.image, color: Colors.white38, size: 50),
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setCafeGalleryState) {
        final currentIndex = ValueNotifier<int>(0);
        final pageController = PageController();
        return Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18), bottom: Radius.circular(18)),
          ),
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  currentIndex.value = index;
                },
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 400,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child:
                            Icon(Icons.image, color: Colors.white38, size: 50),
                      ),
                    ),
                  );
                },
              ),
              // Left arrow button
              if (images.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: GestureDetector(
                      onTap: () {
                        pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              // Right arrow button
              if (images.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              // Dots indicator
              if (images.length > 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ValueListenableBuilder<int>(
                      valueListenable: currentIndex,
                      builder: (context, index, _) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == i ? 12 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    index == i ? Colors.white : Colors.white54,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactsSection(List<_ContactItem> contacts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'Contacts',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          if (contacts.isEmpty)
            TextWidget(text: '—', fontSize: 16, color: Colors.white)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contacts.map((c) {
                final icon = _contactIcon(c.label);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () async {
                      final uri = Uri.parse(c.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextWidget(
                            text: '${c.label}: ${c.url}',
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(List reviews) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'Recent reviews',
            fontSize: 18,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 8),
          if (reviews.isEmpty)
            TextWidget(
              text: 'No reviews yet',
              fontSize: 14,
              color: Colors.white70,
            )
          else
            ...reviews.map((r) {
              final m =
                  (r is Map) ? r.cast<String, dynamic>() : <String, dynamic>{};
              final name =
                  (m['authorName'] ?? m['name'] ?? 'Anonymous').toString();
              final review = (m['text'] ?? m['comment'] ?? '').toString();
              final tags = (m['tags'] is List)
                  ? (m['tags'] as List).cast<String>()
                  : <String>[];
              final imageUrl = m['imageUrl'] as String?;
              final responses =
                  (m['responses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
              return _buildReviewCard(
                name: name,
                review: review.isNotEmpty ? review : '—',
                tags: tags,
                imagePath: 'assets/images/review_placeholder.jpg',
                imageUrl: imageUrl,
                rating: m['rating'],
                createdAt: m['createdAt'],
                responses: responses,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String name,
    required String review,
    required List<String> tags,
    required String imagePath,
    String? imageUrl,
    required int rating,
    Timestamp? createdAt,
    List<Map<String, dynamic>>? responses,
  }) {
    // Calculate time difference
    String timeAgo = '1 week ago'; // Default fallback
    if (createdAt != null) {
      final now = DateTime.now();
      final reviewDate = createdAt.toDate();
      final difference = now.difference(reviewDate);

      if (difference.inDays > 7) {
        timeAgo =
            '${difference.inDays ~/ 7} week${(difference.inDays ~/ 7) > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        timeAgo =
            '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        timeAgo =
            '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        timeAgo =
            '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        timeAgo = 'Just now';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
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
                        Row(
                          children: List.generate(
                            rating,
                            (index) => const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                          ),
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        TextWidget(
                          text: timeAgo,
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: tags
                  .map((tag) => Chip(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        label: TextWidget(
                          text: tag,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        backgroundColor: Colors.grey[800],
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextWidget(
              text: review,
              fontSize: 14,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.image, color: Colors.white38, size: 60),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
                child: const Center(
                  child: Icon(Icons.image, color: Colors.white38, size: 60),
                ),
              ),
            // Owner's Response Section
            if (responses != null && responses.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextWidget(
                text: "Owner's Response",
                fontSize: 14,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 12),
              ...responses.map((response) {
                final responseText =
                    (response['responseText'] as String?) ?? '';
                final responseCreatedAt =
                    (response['createdAt'] as Timestamp?)?.toDate();

                String responseTimeAgo = 'Just now';
                if (responseCreatedAt != null) {
                  final diff = DateTime.now().difference(responseCreatedAt);
                  if (diff.inDays > 7) {
                    responseTimeAgo = '${diff.inDays ~/ 7}w ago';
                  } else if (diff.inDays > 0) {
                    responseTimeAgo = '${diff.inDays}d ago';
                  } else if (diff.inHours > 0) {
                    responseTimeAgo = '${diff.inHours}h ago';
                  }
                }

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .get(),
                  builder: (context, shopSnap) {
                    final shopData =
                        shopSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final shopName = (shopData['name'] as String?) ?? 'Café';
                    final shopLogoUrl = (shopData['logoUrl'] as String?);

                    return Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primary, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (shopLogoUrl != null && shopLogoUrl.isNotEmpty)
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: shopLogoUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: primary,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(color: primary),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextWidget(
                                      text: shopName,
                                      fontSize: 13,
                                      color: Colors.white,
                                      isBold: true,
                                    ),
                                    TextWidget(
                                      text: responseTimeAgo,
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextWidget(
                            text: responseText,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSummaryStream(String shopId) {
    final query = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('reviews');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final ratings = docs
            .map((d) => d.data()['rating'])
            .whereType<num>()
            .map((n) => n.toDouble())
            .toList();
        final count = ratings.length;
        final avg = count == 0 ? 0.0 : ratings.reduce((a, b) => a + b) / count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: 'Reviews',
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              if (count == 0)
                TextWidget(
                  text: 'No reviews yet',
                  fontSize: 14,
                  color: Colors.white70,
                )
              else
                Row(
                  children: [
                    TextWidget(
                      text: avg.toStringAsFixed(1),
                      fontSize: 32,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: '$count Reviews',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsSectionStream(String shopId) {
    final query = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(10);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final items = docs.map((d) => d.data()).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextWidget(
                text: 'Recent reviews',
                fontSize: 18,
                color: Colors.white,
                isBold: true,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                TextWidget(
                  text: 'No reviews yet',
                  fontSize: 14,
                  color: Colors.white70,
                )
              else
                ...items.map((m) {
                  final name =
                      (m['authorName'] ?? m['name'] ?? 'Anonymous').toString();
                  final review = (m['text'] ?? m['comment'] ?? '').toString();
                  final tags = (m['tags'] is List)
                      ? (m['tags'] as List).cast<String>()
                      : <String>[];
                  final imageUrl = m['imageUrl'] as String?;
                  final responses =
                      (m['responses'] as List?)?.cast<Map<String, dynamic>>() ??
                          [];
                  return _buildReviewCard(
                    name: name,
                    review: review.isNotEmpty ? review : '—',
                    tags: tags,
                    imagePath: 'assets/images/review_placeholder.jpg',
                    imageUrl: imageUrl,
                    rating: m['rating'],
                    createdAt: m['createdAt'] as Timestamp?,
                    responses: responses,
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(context) {
    final sm = shop ?? const <String, dynamic>{};
    final List embeddedReviews = (sm['reviews'] as List?) ?? const [];
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReviewsScreen(
                    shopId: shopId,
                    fallbackReviews: embeddedReviews,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              maximumSize: Size(350, 50),
              minimumSize: Size(350, 50),
              backgroundColor: Colors.transparent,
              side: BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: TextWidget(
              text: 'Show all reviews',
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  final sm = shop ?? const <String, dynamic>{};
                  final shopName = (sm['name'] ?? '').toString();
                  final shopAddress = (sm['address'] ?? '').toString();
                  final logo = (sm['logoUrl'] ?? '').toString();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LogVisitScreen(
                        logo: logo,
                        shopId: shopId ?? '',
                        shopName: shopName,
                        shopAddress: shopAddress,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: 'Log a Visit',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final sm = shop ?? const <String, dynamic>{};
                  final shopName = (sm['name'] ?? '').toString();
                  final shopAddress = (sm['address'] ?? '').toString();
                  final logo = (sm['logoUrl'] ?? '').toString();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WriteReviewScreen(
                        logo: logo,
                        shopId: shopId ?? '',
                        shopName: shopName,
                        shopAddress: shopAddress,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.white),
                    const SizedBox(width: 8),
                    TextWidget(
                      text: 'Review',
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class _CafeMap extends StatefulWidget {
  final double latitude;
  final double longitude;

  const _CafeMap({required this.latitude, required this.longitude});

  @override
  State<_CafeMap> createState() => _CafeMapState();
}

class _CafeMapState extends State<_CafeMap> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.latitude, widget.longitude),
            zoom: 15.0,
          ),
          onMapCreated: (controller) {
            _controller = controller;
          },
          markers: {
            Marker(
              markerId: const MarkerId('shop_location'),
              position: LatLng(widget.latitude, widget.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          },
          zoomControlsEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          tiltGesturesEnabled: false,
          rotateGesturesEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              _buildZoomButton(Icons.add, () {
                _controller?.animateCamera(CameraUpdate.zoomIn());
              }),
              const SizedBox(height: 8),
              _buildZoomButton(Icons.remove, () {
                _controller?.animateCamera(CameraUpdate.zoomOut());
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.black87, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
