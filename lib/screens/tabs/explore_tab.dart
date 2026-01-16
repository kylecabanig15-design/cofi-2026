import 'dart:math' as math;

import 'package:cofi/screens/subscreens/cafe_details_screen.dart';
import 'package:cofi/screens/subscreens/event_details_screen.dart';
import '../../services/google_sign_in_service.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/text_widget.dart';

class ExploreTab extends StatefulWidget {
  final VoidCallback? onOpenCommunity;
  const ExploreTab({super.key, this.onOpenCommunity});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  int _selectedChip = -1; // Changed to -1 to indicate no selection by default

  // ==========================================================================
  // COSINE SIMILARITY INDEX ALGORITHM FOR CAFÉ RECOMMENDATIONS
  // ==========================================================================
  //
  // This algorithm calculates the similarity between two users based on their
  // café ratings, visit tags, and amenity preferences. The formula used is:
  //
  //                    Σ(Xp + Tp + Ap)(Yp + Tp + Ap)
  // Similarity = ─────────────────────────────────────────────────
  //              √[Σ(Xp + Tp + Ap)²] × √[Σ(Yp + Tp + Ap)²]
  //
  // Where:
  //   Xp = rating of the first user on the p-th café (1-5 scale)
  //   Yp = rating of the second user on the p-th café (1-5 scale)
  //   Tp = visit tag weight on the p-th café (based on matching tags)
  //   Ap = amenity weight of the p-th café (based on shop amenity tags)
  //   n  = number of cafés both users have rated
  //
  // Returns: A double value between 0 and 1, where:
  //   - 1.0 = Perfect similarity (users have identical preferences)
  //   - 0.0 = No similarity (users have completely different preferences)
  // ==========================================================================

  /// Calculates the Cosine Similarity Index between two users based on their
  /// café ratings, visit tags, and amenity preferences.
  ///
  /// Parameters:
  /// - [user1Reviews]: List of review maps from the first user
  ///   Each map should contain: 'shopId', 'rating', 'tags' (visit tags)
  /// - [user2Reviews]: List of review maps from the second user
  ///   Each map should contain: 'shopId', 'rating', 'tags' (visit tags)
  /// - [shopAmenities]: Map of shopId to list of amenity tags for each shop
  /// - [visitTagWeights]: Optional map of visit tag to weight value (defaults provided)
  /// - [amenityTagWeights]: Optional map of amenity tag to weight value (defaults provided)
  ///
  /// Returns: A double value between 0.0 and 1.0 representing similarity
  double calculateCosineSimilarity({
    required List<Map<String, dynamic>> user1Reviews,
    required List<Map<String, dynamic>> user2Reviews,
    required Map<String, List<String>> shopAmenities,
    Map<String, double>? visitTagWeights,
    Map<String, double>? amenityTagWeights,
  }) {
    // ========================================================================
    // STEP 1: Define default weights for visit tags and amenity tags
    // ========================================================================
    // Visit tags represent the purpose/context of a user's visit to a café.
    // Higher weights indicate more significant matching factors.
    final Map<String, double> defaultVisitTagWeights = {
      'Business Meeting': 1.0,
      'Chill / Hangout': 0.8,
      'Study Session': 1.0,
      'Group Gathering': 0.7,
    };

    // Amenity tags represent the features/characteristics of a café.
    // These weights reflect the importance of each amenity for similarity.
    final Map<String, double> defaultAmenityTagWeights = {
      'Specialty Coffee': 1.0,
      'Matcha Drinks': 0.8,
      'Pastries': 0.6,
      'Work-Friendly (Wi-Fi + outlets)': 1.0,
      'Pet-Friendly': 0.7,
      'Parking Available': 0.5,
      'Family Friendly': 0.6,
      'Study Sessions': 1.0,
      'Night Café (Open Late)': 0.7,
      'Minimalist / Modern': 0.5,
      'Rustic / Cozy': 0.5,
      'Outdoor / Garden': 0.6,
      'Seaside / Scenic': 0.6,
      'Artsy / Aesthetic': 0.5,
      'Instagrammable': 0.4,
    };

    // Use provided weights or fall back to defaults
    final visitWeights = visitTagWeights ?? defaultVisitTagWeights;
    final amenityWeights = amenityTagWeights ?? defaultAmenityTagWeights;

    // ========================================================================
    // STEP 2: Build lookup maps for efficient access to user reviews by shopId
    // ========================================================================
    // Create a map from shopId to review data for each user.
    // This allows O(1) lookup when finding common cafés.
    final Map<String, Map<String, dynamic>> user1ReviewMap = {
      for (var review in user1Reviews)
        if (review['shopId'] != null) review['shopId'] as String: review
    };

    final Map<String, Map<String, dynamic>> user2ReviewMap = {
      for (var review in user2Reviews)
        if (review['shopId'] != null) review['shopId'] as String: review
    };

    // ========================================================================
    // STEP 3: Find common cafés (cafés that both users have rated)
    // ========================================================================
    // The algorithm only considers cafés where BOTH users have left reviews.
    // This is essential for computing meaningful similarity.
    final Set<String> user1Shops = user1ReviewMap.keys.toSet();
    final Set<String> user2Shops = user2ReviewMap.keys.toSet();
    final Set<String> commonShops = user1Shops.intersection(user2Shops);

    // If there are no common cafés, similarity cannot be computed
    // Return 0.0 indicating no measurable similarity
    if (commonShops.isEmpty) {
      return 0.0;
    }

    // ========================================================================
    // STEP 4: Calculate component values for each common café
    // ========================================================================
    // Initialize accumulators for the cosine similarity formula:
    // - numerator: Σ(Xp + Tp + Ap)(Yp + Tp + Ap)
    // - sumUser1Squared: Σ(Xp + Tp + Ap)²
    // - sumUser2Squared: Σ(Yp + Tp + Ap)²
    double numerator = 0.0;
    double sumUser1Squared = 0.0;
    double sumUser2Squared = 0.0;

    for (final shopId in commonShops) {
      // Get review data for both users for this café
      final review1 = user1ReviewMap[shopId]!;
      final review2 = user2ReviewMap[shopId]!;

      // ----------------------------------------------------------------------
      // STEP 4a: Extract ratings (Xp and Yp)
      // ----------------------------------------------------------------------
      // Ratings are on a 1-5 scale. Convert to double for calculation.
      final double xp = (review1['rating'] as num?)?.toDouble() ?? 0.0;
      final double yp = (review2['rating'] as num?)?.toDouble() ?? 0.0;

      // ----------------------------------------------------------------------
      // STEP 4b: Calculate visit tag weight (Tp)
      // ----------------------------------------------------------------------
      // Tp represents the weighted sum of matching visit tags between users.
      // If both users tagged their visit with the same purpose, it increases
      // the similarity weight for this café.
      final List<String> user1VisitTags =
          (review1['tags'] as List?)?.cast<String>() ?? [];
      final List<String> user2VisitTags =
          (review2['tags'] as List?)?.cast<String>() ?? [];

      // Find common visit tags and sum their weights
      double tp = 0.0;
      for (final tag in user1VisitTags) {
        if (user2VisitTags.contains(tag)) {
          // Both users used this tag - add its weight
          tp += visitWeights[tag] ?? 0.5; // Default weight if tag not in map
        }
      }

      // ----------------------------------------------------------------------
      // STEP 4c: Calculate amenity weight (Ap)
      // ----------------------------------------------------------------------
      // Ap represents the weighted sum of amenity tags for this café.
      // This reflects the café's characteristics that both users experienced.
      final List<String> cafeAmenities = shopAmenities[shopId] ?? [];

      double ap = 0.0;
      for (final amenity in cafeAmenities) {
        ap += amenityWeights[amenity] ?? 0.3; // Default weight if not in map
      }

      // ----------------------------------------------------------------------
      // STEP 4d: Calculate combined scores for this café
      // ----------------------------------------------------------------------
      // For user 1: (Xp + Tp + Ap)
      // For user 2: (Yp + Tp + Ap)
      // Note: Tp and Ap are the same for both users as they relate to the café
      final double user1Score = xp + tp + ap;
      final double user2Score = yp + tp + ap;

      // ----------------------------------------------------------------------
      // STEP 4e: Accumulate values for the formula
      // ----------------------------------------------------------------------
      // Numerator: Add the product of both user scores
      numerator += user1Score * user2Score;

      // Denominators: Add squared scores for each user
      sumUser1Squared += user1Score * user1Score;
      sumUser2Squared += user2Score * user2Score;
    }

    // ========================================================================
    // STEP 5: Calculate the final cosine similarity value
    // ========================================================================
    // Formula: numerator / (sqrt(sumUser1Squared) * sqrt(sumUser2Squared))
    //
    // Handle edge case where denominators might be zero (no valid data)
    final double denominator = (sumUser1Squared > 0 && sumUser2Squared > 0)
        ? (sqrt(sumUser1Squared) * sqrt(sumUser2Squared))
        : 0.0;

    // Avoid division by zero
    if (denominator == 0.0) {
      return 0.0;
    }

    // Calculate final similarity score
    final double similarity = numerator / denominator;

    // ========================================================================
    // STEP 6: Clamp result to valid range [0.0, 1.0]
    // ========================================================================
    // Due to floating-point arithmetic, the result might slightly exceed 1.0
    // or be slightly negative. Clamp to ensure valid range.
    return similarity.clamp(0.0, 1.0);
  }

  /// Helper function: Square root calculation using dart:math
  double sqrt(double value) {
    if (value <= 0) return 0.0;
    return math.sqrt(value);
  }

  // ==========================================================================
  // END OF COSINE SIMILARITY ALGORITHM
  // ==========================================================================
  final bool _isOpenNow = false;
  final bool _isOpenToday = false;
  final bool _isFavorites = false;
  final bool _isVisited = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  User? _user;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  Set<String> _bookmarks = {};
  Set<String> _visited = {};
  List<String> _userInterests = []; // New field to store user interests

  // Map of shopId -> recommendation score computed from similar users (cosine-based)
  Map<String, double> _shopRecommendationScores = {};

  // Tag filters
  final Set<String> _selectedTags = {};
  final List<String> _availableTags = [
    'Specialty Coffee',
    'Matcha Drinks',
    'Pastries',
    'Work-Friendly (Wi-Fi + outlets)',
    'Pet-Friendly',
    'Parking Available',
    'Family Friendly',
    'Study Sessions',
    'Night Café (Open Late)',
    'Minimalist / Modern',
    'Rustic / Cozy',
    'Outdoor / Garden',
    'Seaside / Scenic',
    'Artsy / Aesthetic',
    'Instagrammable',
  ];

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .snapshots();

      // Load recommendation scores for shops using cosine similarity over similar users
      _loadRecommendationScores();
    }
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim();
      if (q != _query) setState(() => _query = q);
    });

    // Fetch user interests
    _fetchUserInterests();
  }

  // New method to fetch user interests
  Future<void> _fetchUserInterests() async {
    if (_user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final interests = (data?['interests'] as List?)?.cast<String>() ?? [];
        setState(() {
          _userInterests = interests;
        });
      }
    } catch (e) {
      // Handle error silently or log it
      print('Error fetching user interests: $e');
    }
  }

  /// Compute recommendation scores per shop using similar users' reviews.
  /// This uses _findSimilarUsers(), which is based on calculateCosineSimilarity.
  Future<void> _loadRecommendationScores() async {
    if (_user == null) return;

    try {
      final similarUsers = await _findSimilarUsers();
      if (similarUsers.isEmpty) return;

      final Map<String, double> userSimilarity = {
        for (final u in similarUsers)
          u['userId'] as String: (u['similarity'] as double),
      };

      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      final currentData = currentUserDoc.data() ?? {};
      final currentBookmarks =
          (currentData['bookmarks'] as List?)?.cast<String>() ?? [];
      final currentVisited =
          (currentData['visited'] as List?)?.cast<String>() ?? [];
      final currentShopSet = <String>{...currentBookmarks, ...currentVisited};

      final Map<String, double> scores = {};

      for (final shopDoc in shopsSnapshot.docs) {
        final shopId = shopDoc.id;

        // Optionally skip shops the current user already knows
        if (currentShopSet.contains(shopId)) continue;

        final reviewsSnapshot =
            await shopDoc.reference.collection('reviews').get();

        double score = 0.0;

        for (final reviewDoc in reviewsSnapshot.docs) {
          final userId = reviewDoc['userId'] as String;
          final sim = userSimilarity[userId];
          if (sim == null || sim <= 0) continue;

          final rating = (reviewDoc['rating'] as num).toDouble();
          // Simple scoring: similarity * rating
          score += sim * rating;
        }

        if (score > 0.0) {
          scores[shopId] = score;
        }
      }

      if (!mounted) return;
      setState(() {
        _shopRecommendationScores = scores;
      });
    } catch (e) {
      print('Error loading recommendation scores: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterChips = [
      'Popular',
      'Newest',
      'Open now',
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        const SizedBox(height: 16),
        _buildSearchBar(),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (int i = 0; i < filterChips.length; i++) ...[
                FilterChip(
                  label: TextWidget(
                    text: filterChips[i],
                    fontSize: 14,
                    color: Colors.white,
                    isBold: true,
                  ),
                  backgroundColor: _selectedChip == i
                      ? Colors.white12
                      : const Color(0xFF222222),
                  selected: _selectedChip == i,
                  selectedColor: primary,
                  checkmarkColor: white,
                  onSelected: (_) {
                    setState(() {
                      _selectedChip = _selectedChip == i ? -1 : i;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: const BorderSide(
                    color: Colors.white12,
                    width: 1,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                if (i < filterChips.length - 1) const SizedBox(width: 5),
              ]
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Tag filters
        _buildTagFilters(),
        const SizedBox(height: 18),
        if (_query.isEmpty) ...[
          _sectionTitle('Monthly Featured Cafe Shops'),
          const SizedBox(height: 10),
          if (_userStream != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, userSnap) {
                if (userSnap.hasData) {
                  final data = userSnap.data!.data();
                  final bm =
                      (data?['bookmarks'] as List?)?.cast<String>() ?? [];
                  final vd = (data?['visited'] as List?)?.cast<String>() ?? [];
                  _bookmarks = bm.toSet();
                  _visited = vd.toSet();
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _getFeaturedShopsStream(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final docs = snap.data!.docs;
                    // Sort featured shops using collaborative algorithm
                    return FutureBuilder<
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                      future: _sortFeaturedShopsWithAlgorithm(docs),
                      builder: (context, sortedSnap) {
                        if (!sortedSnap.hasData) {
                          return const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final sorted = sortedSnap.data!;
                        if (sorted.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No featured shops yet',
                                style: TextStyle(color: Colors.white70)),
                          );
                        }
                        return SizedBox(
                          height: 275,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final d = sorted[idx];
                              return SizedBox(
                                width: 360,
                                child: _buildFeaturedCard(
                                  id: d.id,
                                  name: ((d.data()['name'] ?? '') as String?) ??
                                      '',
                                  city:
                                      _getAddressAsString(d.data()['address']),
                                  hours: _hoursFromSchedule(
                                      _getScheduleAsMap(d.data()['schedule'])),
                                  ratingText: _ratingStreamText(
                                    d.id,
                                    d.data()['ratings'],
                                    (d.data()['reviews'] is List
                                        ? (d.data()['reviews'] as List).length
                                        : 0),
                                  ),
                                  isBookmarked: _bookmarks.contains(d.id),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CafeDetailsScreen(
                                          shopId: d.id,
                                          shop: d.data(),
                                        ),
                                      ),
                                    );
                                  },
                                  onBookmark: () => _toggleBookmark(
                                    d.id,
                                    _bookmarks.contains(d.id),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Sign in to see featured',
                  style: TextStyle(color: Colors.white70)),
            ),
          const SizedBox(height: 18),
          _sectionTitle('Upcoming Events'),
          const SizedBox(height: 10),
          _buildEventsSection(),
          const SizedBox(height: 18),
        ],
        GestureDetector(
            onTap: () => widget.onOpenCommunity?.call(),
            child: _buildCheckCommunityButton()),
        const SizedBox(height: 18),
        _sectionTitle('Shops'),
        const SizedBox(height: 10),
        // Bookmarks + Shops stream
        if (_userStream != null)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userStream,
            builder: (context, userSnap) {
              if (userSnap.hasData) {
                final data = userSnap.data!.data();
                final list =
                    (data?['bookmarks'] as List?)?.cast<String>() ?? [];
                final vlist = (data?['visited'] as List?)?.cast<String>() ?? [];
                _bookmarks = list.toSet();
                _visited = vlist.toSet();
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getShopsStream(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  if (snap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Failed to load shops',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  // Apply filters and sorting based on chips and bottom-sheet
                  final filtered = _applyFilters(docs);
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No shops yet',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }
                  return Column(
                    children: [
                      for (final d in filtered) ...[
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CafeDetailsScreen(
                                  shopId: d.id,
                                  shop: d.data(),
                                ),
                              ),
                            );
                          },
                          child: _buildShopCard(
                            logo:
                                ((d.data()['logoUrl'] ?? '') as String?) ?? '',
                            id: d.id,
                            name: ((d.data()['name'] ?? '') as String?) ?? '',
                            city: _getAddressAsString(d.data()['address']),
                            hours: _hoursFromSchedule(
                                _getScheduleAsMap(d.data()['schedule'])),
                            ratingText: _ratingStreamText(
                              d.id,
                              d.data()['ratings'],
                              (d.data()['reviews'] is List
                                  ? (d.data()['reviews'] as List).length
                                  : 0),
                            ),
                            isBookmarked: _bookmarks.contains(d.id),
                            icon: FontAwesomeIcons.coffee,
                            onBookmark: () => _toggleBookmark(
                              d.id,
                              _bookmarks.contains(d.id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 24),
                    ],
                  );
                },
              );
            },
          )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Sign in to see shops',
                style: TextStyle(color: Colors.white70)),
          ),
      ],
    );
  }

  // New method to get the appropriate stream for featured shops
  /// Helper function to sort featured shops by rating and review count (fallback)
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortFeaturedShops(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) {
    final sorted = shops.toList();
    sorted.sort((a, b) {
      // Primary: Sort by rating (highest first)
      final ratingA = (a.data()['ratings'] is num)
          ? (a.data()['ratings'] as num).toDouble()
          : 0.0;
      final ratingB = (b.data()['ratings'] is num)
          ? (b.data()['ratings'] as num).toDouble()
          : 0.0;
      if (ratingB != ratingA) return ratingB.compareTo(ratingA);

      // Secondary: Sort by review count (highest first)
      final reviewsA = (a.data()['reviews'] is List
          ? (a.data()['reviews'] as List).length
          : 0);
      final reviewsB = (b.data()['reviews'] is List
          ? (b.data()['reviews'] as List).length
          : 0);
      return reviewsB.compareTo(reviewsA);
    });
    return sorted;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getFeaturedShopsStream() {
    // Query featured shops only (configurable by admin)
    // No rating orderBy to avoid requiring a composite index
    return FirebaseFirestore.instance
        .collection('shops')
        .where('isFeatured', isEqualTo: true)
        .limit(50)
        .snapshots();
  }

  // New method to get the appropriate stream for regular shops
  Stream<QuerySnapshot<Map<String, dynamic>>> _getShopsStream() {
    // If we have user interests and no filter is selected, show recommended shops
    if (_userInterests.isNotEmpty && _selectedChip == -1) {
      // Query shops that match user interests and are verified
      return FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .where('tags', arrayContainsAny: _userInterests)
          .orderBy('postedAt', descending: true)
          .limit(50)
          .snapshots();
    } else {
      // Default behavior based on selected chip
      switch (_selectedChip) {
        case 1: // Newest
          return FirebaseFirestore.instance
              .collection('shops')
              .where('isVerified', isEqualTo: true)
              .orderBy('postedAt', descending: true)
              .limit(50)
              .snapshots();
        case 2: // Open now
          return FirebaseFirestore.instance
              .collection('shops')
              .where('isVerified', isEqualTo: true)
              .orderBy('postedAt', descending: true)
              .limit(50)
              .snapshots();
        case 0: // Popular (default)
        default:
          return FirebaseFirestore.instance
              .collection('shops')
              .where('isVerified', isEqualTo: true)
              .orderBy('ratings', descending: true)
              .limit(50)
              .snapshots();
      }
    }
  }

  // Modified filter method to handle recommendations
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> out = docs;

    // Bottom sheet filters
    if (_isFavorites) {
      out = out.where((d) => _bookmarks.contains(d.id));
    }
    if (_isVisited) {
      out = out.where((d) => _visited.contains(d.id));
    }
    if (_isOpenToday) {
      out = out.where((d) => _isOpenTodayFromSchedule(
          (d.data()['schedule'] ?? {}) as Map<String, dynamic>));
    }
    if (_isOpenNow) {
      out = out.where((d) => _isOpenNowFromSchedule(
          (d.data()['schedule'] ?? {}) as Map<String, dynamic>));
    }

    // Tag filters
    if (_selectedTags.isNotEmpty) {
      out = out.where((d) {
        final tags = (d.data()['tags'] as List?)?.cast<String>() ?? [];
        return _selectedTags.any((selectedTag) => tags.contains(selectedTag));
      });
    }

    final list = out.toList();

    // Search filter on name and address
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list.retainWhere((d) {
        final name = ((d.data()['name'] ?? '') as String).toLowerCase();
        final addr = ((d.data()['address'] ?? '') as String).toLowerCase();
        return name.contains(q) || addr.contains(q);
      });
    }

    // Sort primarily by recommendation score (cosine-based), then by rating and review count
    list.sort((a, b) {
      final sa = _shopRecommendationScores[a.id] ?? 0.0;
      final sb = _shopRecommendationScores[b.id] ?? 0.0;

      // 1) Primary: recommendation score (higher is better)
      if (sb != sa) return sb.compareTo(sa);

      // 2) Fallback: rating
      num ra = a.data().containsKey('ratings') && a.data()['ratings'] is num
          ? a.data()['ratings'] as num
          : 0;
      num rb = b.data().containsKey('ratings') && b.data()['ratings'] is num
          ? b.data()['ratings'] as num
          : 0;
      if (rb != ra) return rb.compareTo(ra);

      // 3) Fallback: review count
      int ca = ((a.data()['reviews'] as List?)?.length ?? 0);
      int cb = ((b.data()['reviews'] as List?)?.length ?? 0);
      return cb.compareTo(ca);
    });

    // Chip filters: 0 Popular, 1 Newest, 2 Open now
    // Only apply additional filtering when a chip is selected (not -1)
    if (_selectedChip != -1) {
      switch (_selectedChip) {
        case 2: // Open now
          list.retainWhere((d) => _isOpenNowFromSchedule(
              (d.data()['schedule'] ?? {}) as Map<String, dynamic>));
          break;
        case 1: // Newest - re-sort by date after rating sort
          list.sort((a, b) {
            final ta = a.data()['postedAt'];
            final tb = b.data()['postedAt'];
            return (tb is Timestamp
                    ? tb.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo((ta is Timestamp
                    ? ta.toDate()
                    : DateTime.fromMillisecondsSinceEpoch(0)));
          });
          break;
        case 0: // Popular - already sorted by rating above
          break;
        default:
          break;
      }
    }

    return list;
  }

  Widget _buildFeaturedCard({
    required String id,
    required String name,
    required String city,
    required String hours,
    required Widget ratingText,
    required bool isBookmarked,
    required VoidCallback onTap,
    required VoidCallback onBookmark,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('shops').doc(id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TextWidget(
                            text: hours,
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 10),
                          const FaIcon(FontAwesomeIcons.solidStar,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 5),
                          ratingText,
                        ],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 280,
                        child: TextWidget(
                          text: name,
                          fontSize: 17,
                          color: Colors.white,
                          isBold: true,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: Text(
                          _truncateCity(city),
                          style: TextStyle(
                            fontSize: city.length > 30 ? 10.5 : 12,
                            color: Colors.white70,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return _buildFeaturedCardWithImage(
            id: id,
            name: name,
            city: city,
            hours: hours,
            ratingText: ratingText,
            isBookmarked: isBookmarked,
            onTap: onTap,
            onBookmark: onBookmark,
            galleryImages: [],
            isVerified: false,
            logo: '',
          );
        }

        final data = snapshot.data?.data();
        final gallery = _getGalleryList(data?['gallery']);
        final isVerified = (data?['isVerified'] as bool?) ?? false;
        final logo = (data?['logoUrl'] as String?) ?? '';

        return _buildFeaturedCardWithImage(
          id: id,
          name: name,
          city: city,
          hours: hours,
          ratingText: ratingText,
          isBookmarked: isBookmarked,
          onTap: onTap,
          onBookmark: onBookmark,
          galleryImages: gallery,
          isVerified: isVerified,
          logo: logo,
        );
      },
    );
  }

  Widget _buildFeaturedCardWithImage({
    required String id,
    required String name,
    required String city,
    required String hours,
    required Widget ratingText,
    required bool isBookmarked,
    required VoidCallback onTap,
    required VoidCallback onBookmark,
    List<String>? galleryImages,
    bool isVerified = false,
    String? logo,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: _buildFeaturedGallerySlider(
            galleryImages: galleryImages ?? [],
            isBookmarked: isBookmarked,
            onBookmark: onBookmark,
            isVerified: isVerified,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextWidget(
                      text: hours,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    const FaIcon(FontAwesomeIcons.solidStar,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 5),
                    ratingText,
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 280,
                  child: TextWidget(
                    text: name,
                    fontSize: 17,
                    color: Colors.white,
                    isBold: true,
                    maxLines: 1,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: Text(
                    _truncateCity(city),
                    style: TextStyle(
                      fontSize: city.length > 30 ? 10.5 : 12,
                      color: Colors.white70,
                      overflow: TextOverflow.ellipsis,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            if (logo != null && logo.isNotEmpty)
              CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(logo),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.local_cafe,
                    color: Colors.white70, size: 20),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeaturedGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
    bool isVerified = false,
  }) {
    if (galleryImages.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18), bottom: Radius.circular(18)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.image, color: Colors.white38, size: 50),
            ),
            // Verified badge
            if (isVerified)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: onBookmark,
              ),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setSliderState) {
        final currentIndex = ValueNotifier<int>(0);
        final pageController = PageController();
        return Container(
          height: 200,
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
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: galleryImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
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
              // Verified badge
              if (isVerified)
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              // Bookmark button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                  onPressed: onBookmark,
                ),
              ),
              // Left arrow button
              if (galleryImages.length > 1)
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
              if (galleryImages.length > 1)
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
              if (galleryImages.length > 1)
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
                            galleryImages.length,
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Find Cafes',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white54),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.black,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (context) => _buildFilterBottomSheet(context),
              );
            },
          ),
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white54),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
    );
  }

  String _ratingText(dynamic ratings, dynamic ratingCount) {
    final num r = (ratings is num) ? ratings : 0;
    final num c = (ratingCount is num) ? ratingCount : 0;
    final display = (c > 0) ? (r.toDouble()).toStringAsFixed(1) : '0.0';
    return '$display (${c.toInt()})';
  }

  String _hoursFromSchedule(Map<String, dynamic> schedule) {
    final key = _weekdayKey(DateTime.now().weekday);
    final day = _getMapValue(schedule[key] ?? {});
    final isOpen = (day['isOpen'] ?? false) == true;
    final open = (day['open'] ?? '') as String?;
    final close = (day['close'] ?? '') as String?;
    if (isOpen && (open?.isNotEmpty ?? false) && (close?.isNotEmpty ?? false)) {
      return '${_to12h(open ?? '')} - ${_to12h(close ?? '')}';
    }
    return 'Closed today';
  }

  // Live rating/count from reviews subcollection with fallback
  Widget _ratingStreamText(
      String shopId, dynamic embeddedRatings, int embeddedCount) {
    final query = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('reviews');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return TextWidget(
            text: _ratingText(embeddedRatings, embeddedCount),
            fontSize: 13,
            color: Colors.white,
          );
        }
        final docs = snapshot.data!.docs;
        final ratings = docs
            .map((d) => d.data()['rating'])
            .whereType<num>()
            .map((n) => n.toDouble())
            .toList();
        final count = ratings.length;
        final avg = count == 0 ? 0.0 : ratings.reduce((a, b) => a + b) / count;
        final text = '${avg.toStringAsFixed(1)} ($count)';
        return TextWidget(text: text, fontSize: 13, color: Colors.white);
      },
    );
  }

  bool _isOpenTodayFromSchedule(Map<String, dynamic> schedule) {
    final key = _weekdayKey(DateTime.now().weekday);
    final day = (schedule[key] ?? {}) as Map<String, dynamic>;
    return (day['isOpen'] ?? false) == true;
  }

  bool _isOpenNowFromSchedule(Map<String, dynamic> schedule) {
    final key = _weekdayKey(DateTime.now().weekday);
    final day = (schedule[key] ?? {}) as Map<String, dynamic>;
    if ((day['isOpen'] ?? false) != true) return false;
    final open = (day['open'] ?? '') as String;
    final close = (day['close'] ?? '') as String;
    if (open.isEmpty || close.isEmpty) return false;
    int om = _toMinutes(open);
    int cm = _toMinutes(close);
    final now = DateTime.now();
    int nm = now.hour * 60 + now.minute;
    // Handle overnight ranges (e.g., 22:00 - 02:00)
    if (cm <= om) {
      // closes next day
      return nm >= om || nm < cm;
    }
    return nm >= om && nm < cm;
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  String _to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm $suffix';
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
      default:
        return 'sunday';
    }
  }

  Future<void> _toggleBookmark(String shopId, bool isBookmarked) async {
    if (_user == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(_user!.uid);
    try {
      await ref.update({
        'bookmarks': isBookmarked
            ? FieldValue.arrayRemove([shopId])
            : FieldValue.arrayUnion([shopId])
      });
    } catch (e) {
      await ref.set({
        'bookmarks': [shopId],
      }, SetOptions(merge: true));
    }
  }

  /// Helper function to safely extract address as a String
  String _getAddressAsString(dynamic addressData) {
    if (addressData == null) {
      return '';
    }
    if (addressData is String) {
      return addressData;
    } else if (addressData is Map) {
      // If address is a Map, try to extract the city or first available field
      final map = addressData as Map<String, dynamic>;
      return (map['city'] as String?) ?? (map['address'] as String?) ?? '';
    }
    return '';
  }

  /// Helper function to truncate city/address to only show barangay and city
  String _truncateCity(String city) {
    final parts = city.split(',');
    if (parts.length > 1) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return city;
  }

  /// Helper function to safely extract gallery URLs as List<String>
  List<String> _getGalleryList(dynamic galleryData) {
    if (galleryData is List) {
      return galleryData.whereType<String>().cast<String>().toList();
    }
    return [];
  }

  /// Helper function to safely convert schedule Map
  Map<String, dynamic> _getScheduleAsMap(dynamic scheduleData) {
    if (scheduleData == null) {
      return {};
    }
    if (scheduleData is Map) {
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return Map<String, dynamic>.from(scheduleData);
    }
    return {};
  }

  /// Helper function to safely get a nested map value
  Map<String, dynamic> _getMapValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  /// Helper function to sort featured shops using collaborative algorithm
  /// Primary: Recommendation score based on user preferences
  /// Secondary: Rating and review count
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _sortFeaturedShopsWithAlgorithm(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> shops) async {
    if (_user == null || shops.isEmpty) {
      // No user logged in, sort by rating + review count only
      return _sortFeaturedShops(shops);
    }

    try {
      final userReviews = <Map<String, dynamic>>[];
      final userVisits = <Map<String, dynamic>>[];

      // STEP 1: Get user's data ONLY for featured shops (not all shops)
      final shopAmenities = <String, List<String>>{};
      final shopReviewsMap = <String, List<Map<String, dynamic>>>{};

      for (final shop in shops) {
        final shopId = shop.id;

        // Get amenities for this shop
        try {
          final tags = (shop.data()['tags'] as List?)?.cast<String>() ?? [];
          shopAmenities[shopId] = tags;
        } catch (e) {
          shopAmenities[shopId] = [];
        }

        // Get reviews for this featured shop
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('reviews')
            .get();

        final shopReviews = <Map<String, dynamic>>[];

        for (final reviewDoc in reviewsSnapshot.docs) {
          final userId = reviewDoc['userId'] as String;
          final reviewData = {
            'shopId': shopId,
            'rating': reviewDoc['rating'],
            'tags': reviewDoc['tags'] ?? [],
            'userId': userId,
          };

          shopReviews.add(reviewData);

          // If this is current user's review, add to their reviews
          if (userId == _user!.uid) {
            userReviews.add(reviewData);
          }
        }

        shopReviewsMap[shopId] = shopReviews;
      }

      // Get user's visits for featured shops
      for (final shop in shops) {
        final shopId = shop.id;
        final visitsSnapshot = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('visits')
            .where('userId', isEqualTo: _user!.uid)
            .get();

        for (final visitDoc in visitsSnapshot.docs) {
          userVisits.add({
            'shopId': shopId,
            'tags': visitDoc['tags'] ?? [],
          });
        }
      }

      final userCombined = [...userReviews, ...userVisits];

      // If user has no activity on featured shops, fall back to rating/review count
      if (userCombined.isEmpty) {
        return _sortFeaturedShops(shops);
      }

      // Calculate recommendation scores for each featured shop
      final scoreMap = <String, double>{};
      for (final shop in shops) {
        final shopId = shop.id;

        // Get this shop's reviews (from other users) using pre-fetched data
        final allShopReviews = shopReviewsMap[shopId] ?? [];
        final otherUsersReviews =
            allShopReviews.where((r) => r['userId'] != _user!.uid).toList();

        // Calculate similarity score
        final score = calculateCosineSimilarity(
          user1Reviews: userCombined,
          user2Reviews: otherUsersReviews,
          shopAmenities: shopAmenities,
        );

        scoreMap[shopId] = score;
      }

      // Sort shops by recommendation score, then by rating/review count
      final sorted = shops.toList();
      sorted.sort((a, b) {
        final scoreA = scoreMap[a.id] ?? 0.0;
        final scoreB = scoreMap[b.id] ?? 0.0;

        // Primary: Recommendation score (higher is better)
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);

        // Secondary: Rating (higher is better)
        final ratingA = (a.data()['ratings'] is num)
            ? (a.data()['ratings'] as num).toDouble()
            : 0.0;
        final ratingB = (b.data()['ratings'] is num)
            ? (b.data()['ratings'] as num).toDouble()
            : 0.0;
        if (ratingB != ratingA) return ratingB.compareTo(ratingA);

        // Tertiary: Review count (higher is better)
        final reviewsA = (a.data()['reviews'] is List
            ? (a.data()['reviews'] as List).length
            : 0);
        final reviewsB = (b.data()['reviews'] is List
            ? (b.data()['reviews'] as List).length
            : 0);
        return reviewsB.compareTo(reviewsA);
      });

      return sorted;
    } catch (e) {
      print('Error calculating featured shop recommendations: $e');
      // Fallback to simple sorting
      return _sortFeaturedShops(shops);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextWidget(
        text: title,
        fontSize: 18,
        color: Colors.white,
        isBold: true,
      ),
    );
  }

  Widget _buildShopCard({
    required String id,
    required String name,
    required String city,
    required String hours,
    required Widget ratingText,
    required bool isBookmarked,
    required IconData icon,
    required String logo,
    required VoidCallback onBookmark,
  }) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('shops').doc(id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TextWidget(
                              text: hours,
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 10),
                            const FaIcon(FontAwesomeIcons.solidStar,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 5),
                            ratingText,
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 280,
                          child: TextWidget(
                            text: name,
                            fontSize: 17,
                            color: Colors.white,
                            isBold: true,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: Text(
                            _truncateCity(city),
                            style: TextStyle(
                              fontSize: city.length > 30 ? 10.5 : 12,
                              color: Colors.white70,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(logo),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildShopCardWithImage(
            logo: logo,
            id: id,
            name: name,
            city: city,
            hours: hours,
            ratingText: ratingText,
            isBookmarked: isBookmarked,
            icon: icon,
            onBookmark: onBookmark,
            galleryImages: [],
          );
        }

        final data = snapshot.data?.data();
        final gallery = (data?['gallery'] as List?)?.cast<String>() ?? [];

        return _buildShopCardWithImage(
          logo: logo,
          id: id,
          name: name,
          city: city,
          hours: hours,
          ratingText: ratingText,
          isBookmarked: isBookmarked,
          icon: icon,
          onBookmark: onBookmark,
          galleryImages: gallery,
        );
      },
    );
  }

  Widget _buildShopCardWithImage({
    required String id,
    required String name,
    required String city,
    required String hours,
    required Widget ratingText,
    required bool isBookmarked,
    required IconData icon,
    required VoidCallback onBookmark,
    required String logo,
    List<String>? galleryImages,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // Image gallery slider
          _buildGallerySlider(
            galleryImages: galleryImages ?? [],
            isBookmarked: isBookmarked,
            onBookmark: onBookmark,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextWidget(
                        text: hours,
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      const FaIcon(FontAwesomeIcons.solidStar,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 5),
                      ratingText,
                    ],
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 280,
                    child: TextWidget(
                      text: name,
                      fontSize: 17,
                      color: Colors.white,
                      isBold: true,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: Text(
                      _truncateCity(city),
                      style: TextStyle(
                        fontSize: city.length > 30 ? 10.5 : 12,
                        color: Colors.white70,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              // Logo in bottom right
              if (logo.isNotEmpty)
                CircleAvatar(
                  radius: 20,
                  backgroundImage: CachedNetworkImageProvider(logo),
                )
              else
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[800],
                  child: const Icon(Icons.local_cafe,
                      color: Colors.white70, size: 20),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
  }) {
    if (galleryImages.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(18), bottom: Radius.circular(18)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(Icons.image, color: Colors.white38, size: 50),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: onBookmark,
              ),
            ),
          ],
        ),
      );
    }

    return StatefulBuilder(
      builder: (context, setGalleryState) {
        final currentIndex = ValueNotifier<int>(0);
        final pageController = PageController();
        return Container(
          height: 200,
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
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18), bottom: Radius.circular(18)),
                    child: CachedNetworkImage(
                      imageUrl: galleryImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
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
              // Bookmark button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                  ),
                  onPressed: onBookmark,
                ),
              ),
              // Left arrow button
              if (galleryImages.length > 1)
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
              if (galleryImages.length > 1)
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
              if (galleryImages.length > 1)
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
                            galleryImages.length,
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

  Widget _buildCheckCommunityButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.mugSaucer,
              color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWidget(
                  text: 'Check Community',
                  fontSize: 16,
                  color: Colors.white,
                  isBold: true,
                ),
                TextWidget(
                  text: 'Find Coffee Events / Job Offers',
                  fontSize: 13,
                  color: Colors.white70,
                  isBold: false,
                ),
              ],
            ),
          ),
          const FaIcon(FontAwesomeIcons.angleRight,
              color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildEventsSection() {
    final now = DateTime.now();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('events')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Failed to load events',
                style: TextStyle(color: Colors.white70)),
          );
        }
        final docs = snapshot.data?.docs ?? [];

        // Auto-archive finished events (mark them as archived)
        for (final doc in docs) {
          final event = doc.data();
          final endDate = event['endDate'];
          bool isFinished = false;

          if (endDate is String && endDate.isNotEmpty) {
            try {
              final end = DateTime.parse(endDate);
              isFinished = end.isBefore(now);
            } catch (_) {}
          }

          // If event is finished and not yet marked as archived, mark it
          if (isFinished && event['isArchived'] != true) {
            doc.reference.update({'isArchived': true}).catchError((_) {});
          }
        }

        // Filter to only show UPCOMING events (not started, not ended)
        // NOTE: Paused events are still shown with a visual indicator
        final upcomingEvents = docs.where((doc) {
          final event = doc.data();

          // First: Check if event has ended
          final endDate = event['endDate'];
          DateTime? endDateTime;
          if (endDate is Timestamp) {
            endDateTime = endDate.toDate();
          } else if (endDate is String && endDate.isNotEmpty) {
            try {
              endDateTime = DateTime.parse(endDate);
            } catch (_) {}
          }

          // If event has ended, don't show
          if (endDateTime != null && endDateTime.isBefore(now)) {
            return false;
          }

          // Second: Check if event has started
          final startDate = event['startDate'];
          DateTime? startDateTime;
          if (startDate is Timestamp) {
            startDateTime = startDate.toDate();
          } else if (startDate is String && startDate.isNotEmpty) {
            try {
              startDateTime = DateTime.parse(startDate);
            } catch (_) {}
          }

          // Only show if start date is in the future (hasn't started yet)
          if (startDateTime != null) {
            return startDateTime.isAfter(now);
          }

          // If no valid dates found, don't show
          return false;
        }).toList();

        if (upcomingEvents.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No upcoming events',
                style: TextStyle(color: Colors.white70)),
          );
        }

        return SizedBox(
          height: 230,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcomingEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final event = upcomingEvents[idx].data();
              final eventId = upcomingEvents[idx].id;
              return SizedBox(
                width: 360,
                height: 220,
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EventDetailsScreen(event: {
                          ...event,
                          'id': eventId,
                        }),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        image: DecorationImage(
                            opacity: event['isPaused'] == true ? 0.85 : 0.65,
                            image: CachedNetworkImageProvider(
                              event['imageUrl'] ?? '',
                            ),
                            fit: BoxFit.cover),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Paused overlay
                          if (event['isPaused'] == true)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                          // Content
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top badges
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: event['isPaused'] == true
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: TextWidget(
                                            text: 'PAUSED',
                                            fontSize: 12,
                                            color: Colors.white,
                                            isBold: true,
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: TextWidget(
                                            text: 'UPCOMING',
                                            fontSize: 12,
                                            color: Colors.black,
                                            isBold: true,
                                          ),
                                        ),
                                ),
                              ),
                              // Bottom text
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextWidget(
                                        text: (event['title'] ?? 'Event')
                                            .toString(),
                                        fontSize: 18,
                                        color: Colors.white,
                                        isBold: true,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      TextWidget(
                                        text: _eventSubtitle(event),
                                        fontSize: 14,
                                        color: Colors.white,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _eventSubtitle(Map<String, dynamic> event) {
    final date = event['date'];
    final start = event['startDate'];
    final end = event['endDate'];

    // Try startDate first
    DateTime? startDate;
    DateTime? endDate;

    // Parse startDate
    if (start is Timestamp) {
      startDate = start.toDate();
    } else if (start is String && start.isNotEmpty) {
      try {
        startDate = DateTime.parse(start);
      } catch (_) {}
    }

    // Parse endDate
    if (end is Timestamp) {
      endDate = end.toDate();
    } else if (end is String && end.isNotEmpty) {
      try {
        endDate = DateTime.parse(end);
      } catch (_) {}
    }

    if (startDate != null) {
      if (endDate != null &&
          endDate.year == startDate.year &&
          endDate.month == startDate.month &&
          endDate.day == startDate.day) {
        // Same day event
        return _formatDate(startDate);
      } else if (endDate != null) {
        // Multi-day event
        return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
      } else {
        return _formatDate(startDate);
      }
    }

    // Try simple date field
    if (date is String && date.isNotEmpty) return date;

    // Only return TBD if truly no dates exist
    return 'Date TBD';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  /// Finds users similar to the current user using the Cosine Similarity algorithm.
  /// Used internally to derive shop recommendation scores.
  Future<List<Map<String, dynamic>>> _findSimilarUsers() async {
    if (_user == null) return [];

    try {
      // STEP 1: Get current user's reviews AND visits
      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();

      final currentUserReviews = <Map<String, dynamic>>[];
      final currentUserVisits = <Map<String, dynamic>>[];

      // Get reviews
      for (final shopDoc in shopsSnapshot.docs) {
        final reviewsSnapshot = await shopDoc.reference
            .collection('reviews')
            .where('userId', isEqualTo: _user!.uid)
            .get();

        for (final reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          currentUserReviews.add({
            'shopId': shopDoc.id,
            'rating': reviewData['rating'],
            'tags': (reviewData['tags'] as List?)?.cast<String>() ?? [],
          });
        }

        // Get visits (with tags)
        final visitsSnapshot = await shopDoc.reference
            .collection('visits')
            .where('userId', isEqualTo: _user!.uid)
            .get();

        for (final visitDoc in visitsSnapshot.docs) {
          final visitData = visitDoc.data();
          currentUserVisits.add({
            'shopId': shopDoc.id,
            'tags': (visitData['tags'] as List?)?.cast<String>() ?? [],
          });
        }
      }

      // Combine reviews and visits into one signal
      final currentUserCombined = [...currentUserReviews, ...currentUserVisits];

      // If current user has no reviews or visits, return empty list
      if (currentUserCombined.isEmpty) return [];

      // STEP 2: Get all other users' reviews AND visits
      final allUsersCombined = <String, List<Map<String, dynamic>>>{};

      for (final shopDoc in shopsSnapshot.docs) {
        // Get all reviews
        final reviewsSnapshot =
            await shopDoc.reference.collection('reviews').get();

        for (final reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data();
          final userId = reviewData['userId'] as String?;
          if (userId == null || userId == _user!.uid) continue;

          allUsersCombined.putIfAbsent(userId, () => []);
          allUsersCombined[userId]!.add({
            'shopId': shopDoc.id,
            'rating': reviewData['rating'],
            'tags': (reviewData['tags'] as List?)?.cast<String>() ?? [],
          });
        }

        // Get all visits
        final visitsSnapshot =
            await shopDoc.reference.collection('visits').get();

        for (final visitDoc in visitsSnapshot.docs) {
          final visitData = visitDoc.data();
          final userId = visitData['userId'] as String?;
          if (userId == null || userId == _user!.uid) continue;

          allUsersCombined.putIfAbsent(userId, () => []);
          allUsersCombined[userId]!.add({
            'shopId': shopDoc.id,
            'tags': (visitData['tags'] as List?)?.cast<String>() ?? [],
          });
        }
      }

      // STEP 3: Get shop amenities for all shops
      final shopAmenities = <String, List<String>>{};
      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final tags = (shopData['tags'] as List?)?.cast<String>() ?? [];
        shopAmenities[shopDoc.id] = tags;
      }

      // STEP 4: Calculate similarity for each user using the Cosine Similarity algorithm
      final List<Map<String, dynamic>> similarUsers = [];

      for (final entry in allUsersCombined.entries) {
        final otherUserId = entry.key;
        final otherUserCombined = entry.value;

        // Calculate cosine similarity using our implemented algorithm
        final similarity = calculateCosineSimilarity(
          user1Reviews: currentUserCombined,
          user2Reviews: otherUserCombined,
          shopAmenities: shopAmenities,
        );

        // Only include users with meaningful similarity (> 0.1)
        if (similarity > 0.1) {
          // Get user info
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'User';

          // Calculate common shops count
          final currentUserShops =
              currentUserCombined.map((r) => r['shopId'] as String).toSet();
          final otherUserShops =
              otherUserCombined.map((r) => r['shopId'] as String).toSet();
          final commonShops =
              currentUserShops.intersection(otherUserShops).length;

          similarUsers.add({
            'userId': otherUserId,
            'userName': userName,
            'similarity': similarity,
            'commonShops': commonShops,
          });
        }
      }

      // STEP 5: Sort by similarity (highest first) and return top 5
      similarUsers.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      return similarUsers.take(5).toList();
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  Widget _buildTagFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableTags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tag = _availableTags[i];
          final isSelected = _selectedTags.contains(tag);
          return FilterChip(
            label: TextWidget(
              text: tag,
              fontSize: 12,
              color: Colors.white,
              isBold: false,
            ),
            backgroundColor: isSelected ? primary : const Color(0xFF222222),
            selected: isSelected,
            selectedColor: primary,
            checkmarkColor: white,
            onSelected: (_) {
              setState(() {
                if (isSelected) {
                  _selectedTags.remove(tag);
                } else {
                  _selectedTags.add(tag);
                }
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            side: const BorderSide(
              color: Colors.white12,
              width: 1,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBottomSheet(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextWidget(
                        text: 'Filters',
                        fontSize: 18,
                        color: Colors.white,
                        isBold: true,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      TextWidget(
                        text: 'Amenities & Features',
                        fontSize: 14,
                        color: Colors.white70,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableTags.map((tag) {
                          final isSelected = _selectedTags.contains(tag);
                          return FilterChip(
                            label: TextWidget(
                              text: tag,
                              fontSize: 13,
                              color: Colors.white,
                              isBold: false,
                            ),
                            backgroundColor:
                                isSelected ? primary : const Color(0xFF333333),
                            selected: isSelected,
                            selectedColor: primary,
                            checkmarkColor: white,
                            onSelected: (_) {
                              setBottomSheetState(() {
                                if (isSelected) {
                                  _selectedTags.remove(tag);
                                } else {
                                  _selectedTags.add(tag);
                                }
                              });
                              setState(() {});
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _selectedTags.isEmpty
                            ? null
                            : () {
                                setBottomSheetState(() {
                                  _selectedTags.clear();
                                });
                                setState(() {});
                              },
                        child: TextWidget(
                          text: 'Clear all',
                          fontSize: 14,
                          color:
                              _selectedTags.isEmpty ? Colors.white30 : primary,
                          isBold: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
