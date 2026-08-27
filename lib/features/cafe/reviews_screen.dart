import 'package:intl/intl.dart';
import 'package:cofi/utils/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/business/response_review_bottom_sheet.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';

class ReviewsScreen extends StatelessWidget {
  final String? shopId;
  final List? fallbackReviews;

  const ReviewsScreen({super.key, this.shopId, this.fallbackReviews});

  @override
  Widget build(BuildContext context) {
    final hasShopId = shopId != null && shopId!.isNotEmpty;
    final query = hasShopId
        ? FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('reviews')
            .orderBy('createdAt', descending: true)
        : null;

    return Scaffold(
      backgroundColor: BusinessWorkspaceColors.canvas,
      appBar: AppBar(
        backgroundColor: BusinessWorkspaceColors.canvas,
        title: TextWidget(
            text: 'Guest feedback',
            fontSize: 18,
            color: BusinessWorkspaceColors.paper,
            isBold: true),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: hasShopId
                ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: query!.snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return TextWidget(
                        text: '$count Reviews',
                        fontSize: 14,
                        color: Colors.white,
                      );
                    },
                  )
                : TextWidget(
                    text: '${(fallbackReviews ?? const []).length} Reviews',
                    fontSize: 14,
                    color: Colors.white,
                  ),
          ),
        ],
      ),
      body: BusinessWorkspaceTheme(
        accentColor: Colors.orangeAccent,
        child: hasShopId
            ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: query!.snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? const [];
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      const SizedBox(height: 16),
                      const BusinessPageIntro(
                        eyebrow: 'Reputation desk',
                        title: 'Listen, then respond',
                        description:
                            'See what guests remember and reply with the voice of your café.',
                        icon: Icons.forum_rounded,
                      ),
                      const SizedBox(height: 18),
                      if (docs.isNotEmpty) ...[
                        _buildReviewMetrics(docs.map((doc) => doc.data())),
                        const SizedBox(height: 18),
                      ],
                      if (docs.isEmpty)
                        const BusinessEmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No guest notes yet',
                          message:
                              'New reviews will collect here when customers share their café experience.',
                        )
                      else
                        ...docs.map((d) {
                          final m = d.data();
                          final name =
                              (m['authorName'] ?? m['name'] ?? 'Anonymous')
                                  .toString();
                          final review =
                              (m['text'] ?? m['comment'] ?? '').toString();
                          final tags = (m['tags'] is List)
                              ? (m['tags'] as List).cast<String>()
                              : <String>[];
                          final imageUrl = m['imageUrl'] as String?;
                          final userId = (m['userId'] ?? '').toString();
                          final authorPhotoUrl =
                              (m['authorPhotoUrl'] as String?)?.trim();
                          final responses = (m['responses'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              [];

                          return _buildReviewCard(
                            context: context,
                            rating: m['rating'] is num
                                ? (m['rating'] as num).toInt()
                                : 0,
                            name: name,
                            userId: userId,
                            authorPhotoUrl: authorPhotoUrl,
                            review: review.isNotEmpty ? review : '—',
                            tags: tags,
                            imagePath: 'assets/images/review_placeholder.jpg',
                            imageUrl: imageUrl,
                            createdAt: m['createdAt'] is Timestamp
                                ? m['createdAt'] as Timestamp
                                : null,
                            responses: responses,
                            shopId: shopId,
                            reviewId: d.id,
                          );
                        }),
                    ],
                  );
                },
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 16),
                  const BusinessPageIntro(
                    eyebrow: 'Reputation desk',
                    title: 'Listen, then respond',
                    description:
                        'See what guests remember and reply with the voice of your café.',
                    icon: Icons.forum_rounded,
                  ),
                  const SizedBox(height: 18),
                  if ((fallbackReviews ?? const []).isNotEmpty) ...[
                    _buildReviewMetrics((fallbackReviews ?? const []).map(
                      (review) => review is Map
                          ? review.cast<String, dynamic>()
                          : <String, dynamic>{},
                    )),
                    const SizedBox(height: 18),
                  ],
                  if ((fallbackReviews ?? const []).isEmpty)
                    const BusinessEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No guest notes yet',
                      message:
                          'New reviews will collect here when customers share their café experience.',
                    )
                  else
                    ...fallbackReviews!.map((r) {
                      final m = (r is Map)
                          ? r.cast<String, dynamic>()
                          : <String, dynamic>{};
                      final name = (m['authorName'] ?? m['name'] ?? 'Anonymous')
                          .toString();
                      final review =
                          (m['text'] ?? m['comment'] ?? '').toString();
                      final tags = (m['tags'] is List)
                          ? (m['tags'] as List).cast<String>()
                          : <String>[];
                      final imageUrl = m['imageUrl'] as String?;
                      final userId = (m['userId'] ?? '').toString();
                      final authorPhotoUrl =
                          (m['authorPhotoUrl'] as String?)?.trim();
                      final createdAt = m['createdAt'] as Timestamp?;
                      final responses = (m['responses'] as List?)
                              ?.cast<Map<String, dynamic>>() ??
                          [];

                      return _buildReviewCard(
                        context: context,
                        rating: m['rating'] is num
                            ? (m['rating'] as num).toInt()
                            : 0,
                        name: name,
                        userId: userId,
                        authorPhotoUrl: authorPhotoUrl,
                        review: review.isNotEmpty ? review : '—',
                        tags: tags,
                        imagePath: 'assets/images/review_placeholder.jpg',
                        imageUrl: imageUrl,
                        createdAt: createdAt,
                        responses: responses,
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildReviewMetrics(Iterable<Map<String, dynamic>> reviews) {
    final items = reviews.toList(growable: false);
    final ratings = items
        .map((review) => review['rating'])
        .whereType<num>()
        .map((rating) => rating.toDouble())
        .toList(growable: false);
    final average = ratings.isEmpty
        ? 0.0
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    final awaitingReply = items.where((review) {
      final responses = review['responses'];
      return responses is! List || responses.isEmpty;
    }).length;

    return BusinessMetricsStrip(
      items: [
        BusinessMetricData('${items.length}', 'Total reviews'),
        BusinessMetricData(
          average.toStringAsFixed(1),
          'Average rating',
          color: Colors.amber,
        ),
        BusinessMetricData('$awaitingReply', 'Need reply'),
      ],
    );
  }

  /// True when the signed-in user may manage review responses: the shop's
  /// owner (posterId fallback matches deployed security rules semantics) or
  /// an admin.
  Future<bool> _isStaffOrAdmin(String? uid, String? shopId) async {
    if (uid == null || shopId == null || shopId.isEmpty) return false;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);
      final shopData = results[0].data();
      final ownerId = shopData?['ownerId'] as String?;
      final posterId = shopData?['posterId'] as String?;
      final effectiveOwner =
          (ownerId != null && ownerId.isNotEmpty) ? ownerId : posterId;
      if (effectiveOwner != null && effectiveOwner == uid) return true;
      return results[1].data()?['isAdmin'] == true;
    } catch (_) {
      return false;
    }
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required String name,
    required String userId,
    String? authorPhotoUrl,
    required String review,
    required List<String> tags,
    required String imagePath,
    String? imageUrl,
    required int rating,
    Timestamp? createdAt,
    List<Map<String, dynamic>>? responses,
    String? shopId,
    String? reviewId,
  }) {
    // Calculate time difference
    String postedAt = '1 week ago'; // Default fallback
    if (createdAt != null) {
      postedAt = DateFormat('MMM dd, yyyy').format(createdAt.toDate());
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    return FutureBuilder<bool>(
      future: _isStaffOrAdmin(currentUser?.uid, shopId),
      builder: (context, staffSnap) {
        final isOwner = staffSnap.data ?? false;
        final accent = Theme.of(context).colorScheme.secondary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: BusinessWorkspaceColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: BusinessWorkspaceColors.line),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ReviewAuthorAvatar(
                      userId: userId,
                      name: name,
                      storedPhotoUrl: authorPhotoUrl,
                      accent: accent,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      '$rating.0',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              TextWidget(
                                text: postedAt,
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map((tag) => Chip(
                              side: const BorderSide(
                                  color: BusinessWorkspaceColors.line),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100)),
                              label: TextWidget(
                                text: tag,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                              backgroundColor:
                                  BusinessWorkspaceColors.surfaceRaised,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                TextWidget(
                  text: review,
                  fontSize: 14,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
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
                          child: Icon(Icons.image,
                              color: Colors.white38, size: 60),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Owner's Response Section
                if (responses != null &&
                    responses.isNotEmpty &&
                    shopId != null &&
                    shopId.isNotEmpty) ...[
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

                    String responseDate = 'Just now';
                    if (responseCreatedAt != null) {
                      responseDate =
                          DateFormat('MMM dd, yyyy').format(responseCreatedAt);
                    }

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('shops')
                          .doc(shopId)
                          .get(),
                      builder: (context, shopSnap) {
                        final shopData =
                            shopSnap.data?.data() as Map<String, dynamic>? ??
                                {};
                        final shopName =
                            (shopData['name'] as String?) ?? 'Café';
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
                                  if (shopLogoUrl != null &&
                                      shopLogoUrl.isNotEmpty)
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
                                          placeholder: (context, url) =>
                                              Container(
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
                                        child: Icon(Icons.store,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextWidget(
                                          text: shopName,
                                          fontSize: 13,
                                          color: Colors.white,
                                          isBold: true,
                                        ),
                                        TextWidget(
                                          text: responseDate,
                                          fontSize: 11,
                                          color: Colors.white60,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.white),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) =>
                                                ResponseReviewBottomSheet(
                                              shopId: shopId,
                                              reviewId: reviewId ?? '',
                                              reviewText: review,
                                              reviewAuthor: name,
                                              ownerName: shopName,
                                              ownerAvatarUrl: shopLogoUrl,
                                              isEdit: true,
                                              existingResponse: responseText,
                                              responseId:
                                                  response['id'] as String?,
                                              existingResponseImageUrl:
                                                  response['imageUrl']
                                                      as String?,
                                            ),
                                          );
                                        } else if (value == 'delete') {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final confirmed =
                                              await CustomDialog.confirm(
                                            context: context,
                                            title: 'Delete response?',
                                            message:
                                                'Your reply and its attached image will be permanently removed.',
                                            confirmText: 'Delete response',
                                            isDestructive: true,
                                          );
                                          if (!confirmed) return;
                                          try {
                                            await _deleteResponse(
                                              shopId: shopId,
                                              reviewId: reviewId ?? '',
                                              response: response,
                                            );
                                            CustomToast.showFromMessenger(
                                              messenger,
                                              'Your response was deleted.',
                                              type: ToastType.success,
                                              title: 'Response deleted',
                                            );
                                          } catch (_) {
                                            CustomToast.showFromMessenger(
                                              messenger,
                                              'We could not delete the response. Please try again.',
                                              type: ToastType.error,
                                              title: 'Delete failed',
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem<String>(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit,
                                                  size: 16,
                                                  color: Colors.white),
                                              SizedBox(width: 8),
                                              Text('Edit',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      color: Colors.grey[800],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextWidget(
                                text: responseText,
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                              if ((response['imageUrl'] as String?)
                                      ?.isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: response['imageUrl'] as String,
                                    width: double.infinity,
                                    height: 140,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const SizedBox(
                                      height: 80,
                                      child: Center(
                                        child: Icon(Icons.broken_image_outlined,
                                            color: Colors.white38),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  }),
                ],

                // Reply Button
                if (isOwner && shopId != null && reviewId != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => ResponseReviewBottomSheet(
                            shopId: shopId,
                            reviewId: reviewId,
                            reviewText: review,
                            reviewAuthor: name,
                            ownerName: 'Café Owner',
                            ownerAvatarUrl: null,
                          ),
                        );
                      },
                      icon: const Icon(Icons.reply_rounded, size: 18),
                      label: const Text('Reply to review'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteResponse({
    required String shopId,
    required String reviewId,
    required Map<String, dynamic> response,
  }) async {
    if (reviewId.isEmpty) {
      throw StateError('Missing review ID.');
    }
    final reviewRef = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('reviews')
        .doc(reviewId);
    final responseId = (response['id'] ?? '').toString();

    if (responseId.isEmpty) {
      await reviewRef.update({
        'responses': FieldValue.arrayRemove([response]),
      });
    } else {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(reviewRef);
        final responses = ((snapshot.data()?['responses'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => item['id'] != responseId)
            .toList();
        transaction.update(reviewRef, {'responses': responses});
      });
    }

    final imageUrl = (response['imageUrl'] as String?)?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (_) {
        // The Firestore response is already gone; do not surface cleanup-only
        // failures to the owner.
      }
    }
  }
}

class _ReviewAuthorAvatar extends StatefulWidget {
  const _ReviewAuthorAvatar({
    required this.userId,
    required this.name,
    required this.storedPhotoUrl,
    required this.accent,
  });

  final String userId;
  final String name;
  final String? storedPhotoUrl;
  final Color accent;

  @override
  State<_ReviewAuthorAvatar> createState() => _ReviewAuthorAvatarState();
}

class _ReviewAuthorAvatarState extends State<_ReviewAuthorAvatar> {
  late Future<String?> _photoFuture;

  @override
  void initState() {
    super.initState();
    _photoFuture = _resolvePhoto();
  }

  @override
  void didUpdateWidget(covariant _ReviewAuthorAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.storedPhotoUrl != widget.storedPhotoUrl) {
      _photoFuture = _resolvePhoto();
    }
  }

  Future<String?> _resolvePhoto() async {
    if (widget.userId.isNotEmpty) {
      try {
        final user = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        final currentPhoto = (user.data()?['photoUrl'] as String?)?.trim();
        if (currentPhoto != null && currentPhoto.isNotEmpty) {
          return currentPhoto;
        }
      } catch (_) {
        // Fall through to the review snapshot or Auth profile.
      }
    }

    final stored = widget.storedPhotoUrl?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser?.uid == widget.userId) return authUser?.photoURL;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _photoFuture,
      builder: (context, snapshot) {
        final photoUrl = snapshot.data?.trim() ?? '';
        return Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.accent.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: photoUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _initial(),
                )
              : _initial(),
        );
      },
    );
  }

  Widget _initial() {
    final trimmedName = widget.name.trim();
    return Text(
      trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase(),
      style: TextStyle(
        color: widget.accent,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
