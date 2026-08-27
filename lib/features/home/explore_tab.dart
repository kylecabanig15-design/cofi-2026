import 'package:cofi/utils/logger.dart';

import 'package:cofi/features/cafe/cafe_details_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:get_storage/get_storage.dart';

import 'explore/widgets/explore_shop_card.dart';
import 'explore/widgets/explore_featured_card.dart';
import 'explore/widgets/explore_search_bar.dart';
import 'explore/widgets/explore_events_section.dart';
import 'explore/utils/explore_utils.dart';
import 'explore/services/recommendation_service.dart';
import 'package:cofi/utils/app_signals.dart';

class ExploreTab extends StatefulWidget {
  final VoidCallback? onOpenCommunity;
  final GlobalKey? searchKey;
  final GlobalKey? filterKey;
  final GlobalKey? firstCafeKey;
  final ScrollController? scrollController;
  final void Function(String shopId, Map<String, dynamic> data)? onFirstCafeTap;
  const ExploreTab(
      {super.key,
      this.onOpenCommunity,
      this.searchKey,
      this.filterKey,
      this.firstCafeKey,
      this.scrollController,
      this.onFirstCafeTap});

  @override
  State<ExploreTab> createState() => ExploreTabState();
}

class ExploreTabState extends State<ExploreTab> {
  int _selectedChip = 0; // Default to 'For You'
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _currentShops = [];

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
  Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedShopsStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _featuredShopsStream;

  void _updateShopsStream() {
    _cachedShopsStream = _getShopsStream(_userInterests);
  }

  // Map of shopId -> recommendation score computed from similar users (cosine-based)
  Map<String, double> _shopRecommendationScores = {};
  final _box = GetStorage();
  int _recommendationRequestId = 0;

  // Consolidated Grouped Filters
  final Set<String> _selectedFilters = {};
  final Map<String, List<String>> _groupedFilters = {
    '☕ Drink Types': [
      'Espresso',
      'Flat White',
      'Spanish Latte',
      'Vietnamese Coffee',
      'Cold Brew',
      'Pour Over',
      'Specialty Coffee',
    ],
    '🍵 Non-Coffee Drinks': [
      'Matcha Drinks',
    ],
    '🥐 Food Options': [
      'Pastries',
    ],
    '🧑‍💻 Use Case / Activities': [
      'Work-Friendly (Wi-Fi + outlets)',
      'Study Sessions',
      'Night Café (Open Late)',
      'Family Friendly',
    ],
    '🐾 Accessibility & Convenience': [
      'Pet-Friendly',
      'Parking Available',
    ],
    '🎨 Vibe / Ambience': [
      'Minimalist / Modern',
      'Rustic / Cozy',
      'Outdoor / Garden',
      'Seaside / Scenic',
      'Artsy / Aesthetic',
      'Instagrammable',
    ],
  };

  // Source filters
  String _sourceFilter = 'All'; // 'All', 'Business', 'Community'

  @override
  void initState() {
    super.initState();
    recommendationVersion.addListener(_refreshRecommendations);
    _updateShopsStream();
    _featuredShopsStream = FirebaseFirestore.instance
        .collection('shops')
        .where('isFeatured', isEqualTo: true)
        .limit(5)
        .snapshots();
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
      if (q != _query) {
        setState(() {
          _query = q;
          // If searching, deactivate/switch away from "For You" (index 0)
          if (q.isNotEmpty && _selectedChip == 0) {
            _selectedChip = 1; // Default to "Popular"
          }
        });
      }
    });

    // Fetch user interests
    _fetchUserInterests();
  }

  void _refreshRecommendations() {
    _fetchUserInterests();
    _loadRecommendationScores(forceRefresh: true);
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
        final interests =
            (data?['interests'] as List?)?.whereType<String>().toList() ?? [];
        if (!mounted) return;
        setState(() {
          _userInterests = interests;
          _updateShopsStream();
        });
      }
    } catch (e) {
      // Handle error silently or log it
      debugLog('Error fetching user interests: $e');
    }
  }

  /// Compute recommendation scores per shop using similar users' reviews.
  /// This uses _findSimilarUsers(), which is based on calculateCosineSimilarity.
  /// includes Caching (24h) and optimizations.
  Future<void> _loadRecommendationScores({bool forceRefresh = false}) async {
    final requestId = ++_recommendationRequestId;
    final scores = await RecommendationService().loadRecommendationScores(
      user: _user,
      box: _box,
      forceRefresh: forceRefresh,
    );
    if (!mounted || requestId != _recommendationRequestId) return;
    setState(() {
      _shopRecommendationScores = scores;
    });
  }

  @override
  void dispose() {
    recommendationVersion.removeListener(_refreshRecommendations);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Programmatically open the first cafe in the list
  void openFirstCafe() {
    if (_currentShops.isNotEmpty) {
      final firstCafe = _currentShops.first;
      if (widget.onFirstCafeTap != null) {
        widget.onFirstCafeTap!(firstCafe.id, firstCafe.data());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterChips = [
      'For You',
      'Popular',
      'Newest',
      'Open now',
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _userStream == null
          ? _buildScrollView(null, null)
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, userSnap) {
                if (userSnap.hasData) {
                  final data = userSnap.data!.data();
                  final list =
                      (data?['bookmarks'] as List?)?.cast<String>() ?? [];
                  final vlist =
                      (data?['visited'] as List?)?.cast<String>() ?? [];
                  _bookmarks = list.toSet();
                  _visited = vlist.toSet();

                  final newInterests =
                      (data?['interests'] as List?)?.cast<String>() ?? [];
                  if (newInterests.join(',') != _userInterests.join(',')) {
                    _userInterests = newInterests;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _updateShopsStream();
                        });
                      }
                    });
                  }
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _cachedShopsStream ?? _getShopsStream(_userInterests),
                  builder: (context, shopsSnap) {
                    return _buildScrollView(userSnap, shopsSnap);
                  },
                );
              },
            ),
    );
  }

  Widget _buildScrollView(
    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>? userSnap,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>? shopsSnap,
  ) {
    final filterChips = [
      'For You',
      'Popular',
      'Newest',
      'Open now',
    ];

    return RefreshIndicator(
      onRefresh: () async {
        // Firestore streams already refresh the visible feed. Re-read the
        // user's interests and use the cached score immediately instead of
        // blocking the pull gesture on a full collaborative recomputation.
        await _fetchUserInterests();
        await _loadRecommendationScores();
      },
      color: primary,
      backgroundColor: Colors.black87,
      child: CustomScrollView(
        controller: widget.scrollController,
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.white.withValues(alpha: 0.6)
                        ],
                        stops: const [0.0, 0.88, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: filterChips.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        // Automatically remove "For You" chip when searching as requested
                        if (_query.isNotEmpty && i == 0) {
                          return const SizedBox.shrink();
                        }

                        final isSelected = _selectedChip == i;
                        return GestureDetector(
                          onTap: () {
                            if (!isSelected) {
                              setState(() {
                                _selectedChip = i;
                                _updateShopsStream();
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary
                                  : const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? primary : Colors.white12,
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primary.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: TextWidget(
                              text: filterChips[i],
                              fontSize: 14,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Tag filters
                // _buildTagFilters(),
                const SizedBox(height: 18),
                if (_query.isEmpty &&
                    _selectedFilters.isEmpty &&
                    _selectedChip == 0) ...[
                  _sectionTitle('Monthly Featured Cafe Shops'),
                  const SizedBox(height: 10),
                  if (userSnap != null)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _featuredShopsStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final docs = snap.data!.docs;
                        // Sort featured shops using collaborative algorithm
                        return FutureBuilder<
                            List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                          future: Future.value(_sortFeaturedShops(docs)),
                          builder: (context, sortedSnap) {
                            if (sortedSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 220,
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
                              height: 240,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white,
                                        Colors.white,
                                        Colors.white.withValues(alpha: 0.6)
                                      ],
                                      stops: [0.0, 0.88, 1.0],
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.dstIn,
                                  child: PageView.builder(
                                    padEnds: false,
                                    controller:
                                        PageController(viewportFraction: 0.96),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: sorted.length,
                                    itemBuilder: (context, idx) {
                                      final d = sorted[idx];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 14),
                                        child: _buildFeaturedCard(
                                          shopData: d.data(),
                                          id: d.id,
                                          name: ((d.data()['name'] ?? '')
                                                  as String?) ??
                                              '',
                                          city: _getAddressAsString(
                                              d.data()['address']),
                                          hours: _hoursFromSchedule(
                                              _getScheduleAsMap(
                                                  d.data()['schedule'])),
                                          ratingText: TextWidget(
                                            text: _ratingText(
                                              d.data()['ratings'],
                                              d.data()['reviews'],
                                            ),
                                            fontSize: 13,
                                            color: Colors.white,
                                          ),
                                          isBookmarked:
                                              _bookmarks.contains(d.id),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    CafeDetailsScreen(
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
                                          width: double.infinity,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                      onTap: () => widget.onOpenCommunity?.call(),
                      child: _buildCheckCommunityButton()),
                ),
                const SizedBox(height: 18),
                _sectionTitle('Shops'),
                const SizedBox(height: 10),
              ],
            ),
          ),
          // Shops stream result
          if (shopsSnap != null) ...[
            _buildShopsSliver(shopsSnap),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]
        ],
      ),
    );
  }

  Widget _buildShopsSliver(
      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
    if (snap.hasError) {
      return const SliverToBoxAdapter(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Failed to load shops',
            style: TextStyle(color: Colors.white70)),
      ));
    }

    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered;

    if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
      if (_currentShops.isNotEmpty) {
        // Retain previous list to prevent snap/flicker while new stream loads
        filtered = _currentShops;
      } else {
        return const SliverToBoxAdapter(
            child: Center(
                child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        )));
      }
    } else {
      final docs = snap.data?.docs ?? [];
      // Apply filters and sorting based on chips and bottom-sheet
      filtered = _applyFilters(docs, _userInterests);

      // Save for programmatic access
      // Wrap in microtask to avoid state modification during build
      Future.microtask(() {
        if (mounted) {
          _currentShops = filtered;
        }
      });
    }

    if (filtered.isEmpty) {
      return const SliverToBoxAdapter(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
            'No verified shops yet. Recently added community shops are being reviewed by admins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70)),
      ));
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            return Column(
              children: [
                GestureDetector(
                  key: i == 0 ? widget.firstCafeKey : null,
                  onTap: () {
                    if (i == 0 && widget.onFirstCafeTap != null) {
                      widget.onFirstCafeTap!(
                          filtered[i].id, filtered[i].data());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CafeDetailsScreen(
                            shopId: filtered[i].id,
                            shop: filtered[i].data(),
                          ),
                        ),
                      );
                    }
                  },
                  child: _buildShopCard(
                    logo: ((filtered[i].data()['logoUrl'] ?? '') as String?) ??
                        '',
                    id: filtered[i].id,
                    name: ((filtered[i].data()['name'] ?? '') as String?) ?? '',
                    city: _getAddressAsString(filtered[i].data()['address']),
                    hours: _hoursFromSchedule(
                        _getScheduleAsMap(filtered[i].data()['schedule'])),
                    ratingText: TextWidget(
                        text: _ratingText(filtered[i].data()['ratings'],
                            filtered[i].data()['reviews']),
                        fontSize: 13,
                        color: Colors.white),
                    isBookmarked: _bookmarks.contains(filtered[i].id),
                    icon: Icons.coffee,
                    onBookmark: () => _toggleBookmark(
                      filtered[i].id,
                      _bookmarks.contains(filtered[i].id),
                    ),
                    rank: (_selectedChip == 0 &&
                            _selectedFilters.isEmpty &&
                            _query.isEmpty)
                        ? (i + 1)
                        : null,
                    galleryImages: (filtered[i].data()['gallery'] as List?)
                            ?.cast<String>() ??
                        [],
                    isVerified: filtered[i].data()['isVerified'] == true,
                    submissionType: (filtered[i].data()['submissionType'] ??
                        'community') as String,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
          childCount: filtered.length,
        ),
      ),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _getShopsStream(
      List<String> userInterests) {
    // Default behavior based on selected chip
    switch (_selectedChip) {
      case 0: // For You (Recommendations)
        // Soft Filter: Fetch all approved/verified, rank later by algorithm
        // Increased limit to 300 to ensure older shops that were recently approved are visible
        return FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .orderBy('postedAt', descending: true)
            .limit(300)
            .snapshots();

      case 2: // Newest
        return FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .orderBy('postedAt', descending: true)
            .limit(300)
            .snapshots();

      case 3: // Open now
        return FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .orderBy('postedAt', descending: true)
            .limit(300)
            .snapshots();

      case 1: // Popular
      default:
        return FirebaseFirestore.instance
            .collection('shops')
            .where('isVerified', isEqualTo: true)
            .orderBy('ratings', descending: true)
            .limit(300)
            .snapshots();
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      List<String> interests) {
    // Visibility Filter: Hide shops that are explicitly marked as hidden or archived
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> out = docs.where(
        (d) =>
            d.data()['isHidden'] != true &&
            d.data()['approvalStatus'] != 'archived');

    // Bottom sheet filters
    if (_isFavorites) {
      out = out.where((d) => _bookmarks.contains(d.id));
    }
    if (_isVisited) {
      out = out.where((d) => _visited.contains(d.id));
    }
    if (_isOpenToday) {
      out = out.where((d) {
        final sched = d.data()['schedule'];
        final map = (sched is Map)
            ? Map<String, dynamic>.from(sched)
            : <String, dynamic>{};
        return _isOpenTodayFromSchedule(map);
      });
    }
    if (_isOpenNow) {
      out = out.where((d) {
        final sched = d.data()['schedule'];
        final map = (sched is Map)
            ? Map<String, dynamic>.from(sched)
            : <String, dynamic>{};
        return _isOpenNowFromSchedule(map);
      });
    }

    // Unified Tag/Parameter filters
    if (_selectedFilters.isNotEmpty) {
      out = out.where((d) {
        final tags = (d.data()['tags'] as List?)?.cast<String>() ?? [];
        return _selectedFilters
            .any((selectedTag) => tags.contains(selectedTag));
      });
    }

    // Source filters (Aliased to match Admin Center labels)
    if (_sourceFilter != 'All') {
      out = out.where((d) {
        final data = d.data();
        final submissionType = data['submissionType'] as String? ?? 'community';
        final ownerId = data['ownerId'] as String?;
        final isBusiness = (submissionType == 'business' ||
            (ownerId != null && ownerId.isNotEmpty));

        if (_sourceFilter == 'Business') {
          return isBusiness;
        } else if (_sourceFilter == 'Community') {
          return !isBusiness;
        }
        return true;
      });
    }

    final list = out.toList();

    // Search filter on name and address
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list.retainWhere((d) {
        final name = ((d.data()['name'] ?? '') as String).toLowerCase();
        final addr = ((d.data()['address'] ?? '') as String).toLowerCase();
        // Priority: Starts with name, then contains name, then contains address
        return name.startsWith(q) || name.contains(q) || addr.contains(q);
      });

      // Sort results to put "startsWith" matches at the top during search
      list.sort((a, b) {
        final nameA = ((a.data()['name'] ?? '') as String).toLowerCase();
        final nameB = ((b.data()['name'] ?? '') as String).toLowerCase();
        final startsA = nameA.startsWith(q);
        final startsB = nameB.startsWith(q);

        if (startsA && !startsB) return -1;
        if (!startsA && startsB) return 1;
        return 0; // Maintain existing sort order for equal priority
      });
    }

    // Sort based on selected chip or recommendation score
    if (_selectedChip == 0 && _selectedFilters.isEmpty) {
      // 0: For You - Sort by (Collaborative Score + Interest Match Bonus)
      list.sort((a, b) {
        // 1) Get Collaborative Score (if available)
        final sa = _shopRecommendationScores[a.id] ?? 0.0;
        final sb = _shopRecommendationScores[b.id] ?? 0.0;

        // 2) Get Interest Bonus (Content-based)
        double getBonus(QueryDocumentSnapshot<Map<String, dynamic>> d,
            List<String> interests) {
          if (interests.isEmpty) return 0.0;
          final tags = (d.data()['tags'] as List?)?.cast<String>() ?? [];
          final matchCount = tags.where((t) => interests.contains(t)).length;
          return matchCount * 1.5; // Strong bonus for direct interest matches
        }

        final bonusA = getBonus(a, interests);
        final bonusB = getBonus(b, interests);
        final scoreA = sa + bonusA;
        final scoreB = sb + bonusB;

        // 1) Primary Sort: Combined Score
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);

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

      // DEBUG PRINT: Show the top 3 breakdown to verify logic
      debugLog('🚀 [ALGORITHM] FOR YOU RANKING BREAKDOWN:');
      for (int i = 0; i < (list.length > 5 ? 5 : list.length); i++) {
        final d = list[i];
        final collab = _shopRecommendationScores[d.id] ?? 0.0;
        final tags = (d.data()['tags'] as List?)?.cast<String>() ?? [];
        final matches = tags.where((t) => interests.contains(t)).toList();
        final bonus = matches.length * 1.5;
        debugLog(
            '   #${i + 1} ${d.data()['name']} | Final Score: ${(collab + bonus).toStringAsFixed(2)} '
            '(Collab: ${collab.toStringAsFixed(2)} + Interests: ${bonus.toStringAsFixed(2)} [${matches.join(', ')}])');
      }
    } else if (_selectedChip == 1 ||
        (_selectedChip == 0 && _selectedFilters.isNotEmpty)) {
      // 1: Popular OR (For You with tag filters) - Sort by ratings, then by review count
      list.sort((a, b) {
        num ra = a.data().containsKey('ratings') && a.data()['ratings'] is num
            ? a.data()['ratings'] as num
            : 0;
        num rb = b.data().containsKey('ratings') && b.data()['ratings'] is num
            ? b.data()['ratings'] as num
            : 0;
        if (rb != ra) return rb.compareTo(ra);

        // Secondary: review count
        int ca = ((a.data()['reviews'] as List?)?.length ?? 0);
        int cb = ((b.data()['reviews'] as List?)?.length ?? 0);
        return cb.compareTo(ca);
      });
    } else if (_selectedChip == 2) {
      // 2: Newest - Sort by postedAt (already sorted by Firestore, but ensure it)
      list.sort((a, b) {
        final ta =
            (a.data()['postedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tb =
            (b.data()['postedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tb.compareTo(ta);
      });
    } else if (_selectedChip == 3) {
      // 3: Open Now - Sort by postedAt for now (or distance if available)
      list.sort((a, b) {
        final ta =
            (a.data()['postedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final tb =
            (b.data()['postedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return tb.compareTo(ta);
      });
    }

    // Additional filtering for Open Now chip (Index 3)
    if (_selectedChip == 3) {
      list.retainWhere((d) => _isOpenNowFromSchedule(
          (d.data()['schedule'] ?? {}) as Map<String, dynamic>));
    }
    return list;
  }

  Widget _buildFeaturedCard({
    required Map<String, dynamic> shopData,
    required String id,
    required String name,
    required String city,
    required String hours,
    required Widget ratingText,
    required bool isBookmarked,
    required VoidCallback onTap,
    required VoidCallback onBookmark,
    double? width,
  }) {
    return ExploreFeaturedCard(
      shopData: shopData,
      id: id,
      name: name,
      city: city,
      hours: hours,
      ratingText: ratingText,
      isBookmarked: isBookmarked,
      onTap: onTap,
      onBookmark: onBookmark,
      width: width ?? MediaQuery.of(context).size.width * 0.89,
      height: 200,
    );
  }

  Widget _buildSubmissionBadge(bool isVerified, String submissionType) {
    return const SizedBox.shrink();
  }

  Widget _buildFeaturedGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
  }) {
    return const SizedBox.shrink();
  }

  Widget _buildSearchBar() {
    return ExploreSearchBar(
      searchKey: widget.searchKey,
      filterKey: widget.filterKey,
      searchCtrl: _searchCtrl,
      query: _query,
      onClear: () {
        _searchCtrl.clear();
        setState(() => _query = '');
      },
      onFilterTap: () {
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
      onSubmitted: (_) => setState(() {}),
    );
  }

  String _ratingText(dynamic ratings, dynamic reviewsData) {
    num r = (ratings is num) ? ratings : 0;
    int c = 0;

    if (reviewsData is List) {
      c = reviewsData.length;
      if (r == 0 && c > 0) {
        double total = 0;
        for (var rev in reviewsData) {
          if (rev is Map && rev['rating'] is num) {
            total += (rev['rating'] as num).toDouble();
          }
        }
        r = total / c;
      }
    } else if (reviewsData is num) {
      c = reviewsData.toInt();
    }

    return ExploreUtils.ratingText(r, c);
  }

  String _hoursFromSchedule(Map<String, dynamic> schedule) {
    return ExploreUtils.hoursFromSchedule(schedule);
  }

  bool _isOpenTodayFromSchedule(Map<String, dynamic> schedule) {
    return ExploreUtils.isOpenTodayFromSchedule(schedule);
  }

  bool _isOpenNowFromSchedule(Map<String, dynamic> schedule) {
    return ExploreUtils.isOpenNowFromSchedule(schedule);
  }

  int _toMinutes(String hhmm) {
    return 0; // Not used outside of ExploreUtils anymore
  }

  String _to12h(String hhmm) {
    return ExploreUtils.to12h(hhmm);
  }

  String _weekdayKey(int weekday) {
    return ExploreUtils.weekdayKey(weekday);
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
    return ExploreUtils.getAddressAsString(addressData);
  }

  /// Helper function to safely extract gallery URLs as List<String>
  List<String> _getGalleryList(dynamic galleryData) {
    return ExploreUtils.getGalleryList(galleryData);
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
    return ExploreUtils.getMapValue(value);
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
        final score = RecommendationService().calculateCosineSimilarity(
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
      debugLog('Error calculating featured shop recommendations: $e');
      // Fallback to simple sorting
      return _sortFeaturedShops(shops);
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextWidget(
        text: title,
        fontSize: 18,
        color: Colors.white,
        fontFamily: 'Baloo2',
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
    required VoidCallback onBookmark,
    required String logo,
    List<String>? galleryImages,
    int? rank,
    bool isVerified = false,
    String submissionType = 'community',
  }) {
    return ExploreShopCard(
      id: id,
      name: name,
      city: city,
      hours: hours,
      ratingText: ratingText,
      isBookmarked: isBookmarked,
      icon: icon,
      onBookmark: onBookmark,
      logo: logo,
      galleryImages: galleryImages,
      rank: rank,
      isVerified: isVerified,
      submissionType: submissionType,
    );
  }

  Widget _buildGallerySlider({
    required List<String> galleryImages,
    required bool isBookmarked,
    required VoidCallback onBookmark,
  }) {
    return const SizedBox.shrink();
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
    return const ExploreEventsSection();
  }

  Widget _buildTagFilters() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _groupedFilters.values.expand((e) => e).length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final allTags = _groupedFilters.values.expand((e) => e).toList();
          final tag = allTags[i];
          final isSelected = _selectedFilters.contains(tag);
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
                  _selectedFilters.remove(tag);
                } else {
                  _selectedFilters.add(tag);
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
                      // Source filters
                      TextWidget(
                        text: 'Search Source',
                        fontSize: 14,
                        color: Colors.white70,
                        isBold: true,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ['All', 'Business', 'Community'].map((source) {
                          final isSelected = _sourceFilter == source;
                          return ChoiceChip(
                            label: TextWidget(
                              text: source == 'Community'
                                  ? 'Community Added'
                                  : source == 'Business'
                                      ? 'Business Verified'
                                      : source,
                              fontSize: 13,
                              color: Colors.white,
                              isBold: false,
                            ),
                            backgroundColor:
                                isSelected ? primary : const Color(0xFF333333),
                            selected: isSelected,
                            selectedColor: primary,
                            onSelected: (selected) {
                              if (selected) {
                                setBottomSheetState(() {
                                  _sourceFilter = source;
                                });
                                setState(() {});
                              }
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Grouped Filters
                      ..._groupedFilters.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextWidget(
                              text: entry.key,
                              fontSize: 14,
                              color: Colors.white70,
                              isBold: true,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((tag) {
                                final isSelected =
                                    _selectedFilters.contains(tag);
                                return FilterChip(
                                  label: TextWidget(
                                    text: tag,
                                    fontSize: 13,
                                    color: Colors.white,
                                    isBold: false,
                                  ),
                                  backgroundColor: isSelected
                                      ? primary
                                      : const Color(0xFF333333),
                                  selected: isSelected,
                                  selectedColor: primary,
                                  checkmarkColor: white,
                                  onSelected: (_) {
                                    setBottomSheetState(() {
                                      if (isSelected) {
                                        _selectedFilters.remove(tag);
                                      } else {
                                        _selectedFilters.add(tag);
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
                          ],
                        );
                      }),

                      GestureDetector(
                        onTap:
                            (_selectedFilters.isEmpty && _sourceFilter == 'All')
                                ? null
                                : () {
                                    setBottomSheetState(() {
                                      _selectedFilters.clear();
                                      _sourceFilter = 'All';
                                    });
                                    setState(() {});
                                  },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: TextWidget(
                            text: 'Clear all',
                            fontSize: 14,
                            color: (_selectedFilters.isEmpty &&
                                    _sourceFilter == 'All')
                                ? Colors.white30
                                : primary,
                            isBold: true,
                          ),
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
