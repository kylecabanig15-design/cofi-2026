import 'package:cofi/utils/logger.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

class RecommendationService {
  static Future<void> invalidateCache(GetStorage box, String userId) async {
    await Future.wait([
      box.remove('shop_recommendations_$userId'),
      box.remove('shop_rec_timestamp_$userId'),
    ]);
  }

  static const Map<String, double> defaultVisitTagWeights = {
    'Study Session': 0.075,
    'Business Meeting': 0.075,
    'Chill / Hangout': 0.075,
    'Group Gathering': 0.075,
  };

  static const Map<String, double> defaultAmenityTagWeights = {
    'Specialty Coffee': 0.06,
    'Espresso': 0.02,
    'Flat White': 0.02,
    'Spanish Latte': 0.02,
    'Vietnamese Coffee': 0.02,
    'Cold Brew': 0.02,
    'Pour Over': 0.02,
    'Matcha Drinks': 0.02,
    'Pastries': 0.10,
    'Work-Friendly (Wi-Fi + outlets)': 0.04,
    'Pet-Friendly': 0.04,
    'Parking Available': 0.04,
    'Artsy / Aesthetic': 0.02,
    'Instagrammable': 0.02,
    'Night Café (Open Late)': 0.02,
    'Family Friendly': 0.02,
    'Minimalist / Modern': 0.05,
    'Rustic / Cozy': 0.05,
    'Outdoor / Garden': 0.05,
    'Seaside / Scenic': 0.05,
  };

  /// Adds visit context to rated cafés without turning an unrated visit into
  /// a zero-star rating. Reviews remain the primary recommendation signal.
  static List<Map<String, dynamic>> mergeReviewAndVisitSignals({
    required List<Map<String, dynamic>> reviews,
    required List<Map<String, dynamic>> visits,
  }) {
    final merged = <String, Map<String, dynamic>>{};

    for (final review in reviews) {
      final shopId = review['shopId'] as String?;
      if (shopId == null || review['rating'] is! num) continue;
      merged[shopId] = {
        ...review,
        'tags': <String>{
          ...((review['tags'] as List?)?.whereType<String>() ?? const []),
        }.toList(),
      };
    }

    for (final visit in visits) {
      final shopId = visit['shopId'] as String?;
      final ratedCafe = shopId == null ? null : merged[shopId];
      if (ratedCafe == null) continue;
      final tags = <String>{
        ...((ratedCafe['tags'] as List?)?.whereType<String>() ?? const []),
        ...((visit['tags'] as List?)?.whereType<String>() ?? const []),
      };
      ratedCafe['tags'] = tags.toList();
    }

    return merged.values.toList();
  }

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
    //
    // Professor's weighting system — Visit Data = 30% total.
    // Four tags share that 30% equally: 30 × 25/100 = 7.5 each.
    // Stored as percentage points; divided by 100.0 at point of use.
    //
    // Visit Data subtotal: 7.5 + 7.5 + 7.5 + 7.5 = 30.0 pp
    // Amenity tags represent the features/characteristics of a café.
    //
    // Professor's weighting system — amenity subtotals:
    //   Type of Drinks  = 20 pp
    //   Pastries        = 10 pp
    //   Convenience     = 20 pp
    //   Vibe            = 20 pp
    //   Grand total     = 70 pp
    //
    // NOTE: 'Study Sessions' is an alias for the visit tag 'Study Session'
    // and is intentionally NOT weighted here to avoid double-counting.
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

  /// Finds users similar to the current user using the Cosine Similarity algorithm.
  /// Used internally to derive shop recommendation scores.
  Future<List<Map<String, dynamic>>> _findSimilarUsers(User? user) async {
    if (user == null) return [];

    // The caller can retain a User briefly while an auth-state transition is
    // already in progress. Firestore then receives an unauthenticated request
    // even though this method's argument is non-null.
    final activeUser = FirebaseAuth.instance.currentUser;
    if (activeUser == null || activeUser.uid != user.uid) {
      debugLog(
          '⚠️ [ALGORITHM] Similar-user lookup skipped: auth state changed.');
      return [];
    }

    var queryStage = 'refreshing authentication';

    try {
      // Ensure Firebase Auth has supplied a usable ID token before issuing the
      // series of authenticated Firestore reads.
      await activeUser.getIdToken();

      // STEP 1: Get current user's reviews AND visits
      // OPTIMIZATION: Only check top 30 most rated or popular shops to build the vector.
      // Checking ALL shops (thousands) is inefficient and costly.
      queryStage = 'loading ranked shops';
      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .orderBy('ratings',
              descending: true) // Assuming 'ratings' stores average score
          .limit(30)
          .get();

      final topShopIds = shopsSnapshot.docs.map((doc) => doc.id).toSet();
      queryStage = 'loading review and visit signals';
      final signalSnapshots = await Future.wait([
        FirebaseFirestore.instance.collectionGroup('reviews').get(),
        FirebaseFirestore.instance.collectionGroup('visits').get(),
      ]);
      final reviewDocs = signalSnapshots[0].docs;
      final visitDocs = signalSnapshots[1].docs;

      String? parentShopId(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
        return doc.reference.parent.parent?.id;
      }

      final currentUserReviews = <Map<String, dynamic>>[];
      final currentUserVisits = <Map<String, dynamic>>[];
      final allUsersCombined = <String, List<Map<String, dynamic>>>{};

      for (final reviewDoc in reviewDocs) {
        final shopId = parentShopId(reviewDoc);
        if (shopId == null || !topShopIds.contains(shopId)) continue;
        final reviewData = reviewDoc.data();
        final reviewUserId = reviewData['userId'] as String?;
        if (reviewUserId == null) continue;
        final signal = <String, dynamic>{
          'shopId': shopId,
          'rating': reviewData['rating'],
          'tags': (reviewData['tags'] as List?)?.whereType<String>().toList() ??
              const <String>[],
        };
        if (reviewUserId == activeUser.uid) {
          currentUserReviews.add(signal);
        } else {
          allUsersCombined.putIfAbsent(reviewUserId, () => []).add(signal);
        }
      }

      for (final visitDoc in visitDocs) {
        final shopId = parentShopId(visitDoc);
        if (shopId == null || !topShopIds.contains(shopId)) continue;
        final visitData = visitDoc.data();
        final visitUserId = visitData['userId'] as String?;
        if (visitUserId == null) continue;
        final signal = <String, dynamic>{
          'shopId': shopId,
          'tags': (visitData['tags'] as List?)?.whereType<String>().toList() ??
              const <String>[],
        };
        if (visitUserId == activeUser.uid) {
          currentUserVisits.add(signal);
        } else {
          allUsersCombined.putIfAbsent(visitUserId, () => []).add(signal);
        }
      }

      // Combine reviews and visits into one signal
      final currentUserCombined = mergeReviewAndVisitSignals(
        reviews: currentUserReviews,
        visits: currentUserVisits,
      );

      // If current user has no reviews or visits, return empty list
      if (currentUserCombined.isEmpty) return [];

      // STEP 3: Get shop amenities for all shops
      final shopAmenities = <String, List<String>>{};
      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final tags = (shopData['tags'] as List?)?.cast<String>() ?? [];
        shopAmenities[shopDoc.id] = tags;
      }

      // STEP 4: Calculate similarity for each user using the Cosine Similarity algorithm
      final similarityCandidates = <Map<String, dynamic>>[];

      for (final entry in allUsersCombined.entries) {
        final otherUserId = entry.key;
        final otherSignals = entry.value;
        final otherUserCombined = mergeReviewAndVisitSignals(
          reviews:
              otherSignals.where((signal) => signal['rating'] is num).toList(),
          visits:
              otherSignals.where((signal) => signal['rating'] is! num).toList(),
        );

        // Calculate cosine similarity using our implemented algorithm
        final similarity = calculateCosineSimilarity(
          user1Reviews: currentUserCombined,
          user2Reviews: otherUserCombined,
          shopAmenities: shopAmenities,
        );
        // Only include users with meaningful similarity (> 0.1)
        if (similarity > 0.1) {
          // Calculate common shops count
          final currentUserShops =
              currentUserCombined.map((r) => r['shopId'] as String).toSet();
          final otherUserShops =
              otherUserCombined.map((r) => r['shopId'] as String).toSet();
          final commonShops =
              currentUserShops.intersection(otherUserShops).length;

          similarityCandidates.add({
            'userId': otherUserId,
            'similarity': similarity,
            'commonShops': commonShops,
          });
        }
      }

      // STEP 5: Sort by similarity (highest first) and return top 5
      similarityCandidates.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));
      final topCandidates = similarityCandidates.take(5).toList();
      queryStage = 'loading similar-user profiles';
      final profileDocs = await Future.wait(topCandidates.map((candidate) =>
          FirebaseFirestore.instance
              .collection('users')
              .doc(candidate['userId'] as String)
              .get()));
      for (var index = 0; index < topCandidates.length; index++) {
        final profile = profileDocs[index].data();
        topCandidates[index]['userName'] =
            profile?['name'] ?? profile?['displayName'] ?? 'User';
      }
      return topCandidates;
    } on FirebaseException catch (e) {
      debugLog(
          '❌ [ALGORITHM] Firestore error while $queryStage: ${e.code} ${e.message ?? ''}');
      return [];
    } catch (e) {
      debugLog('❌ [ALGORITHM] Error while $queryStage: $e');
      return [];
    }
  }

  /// Calculates shop recommendation scores based on similar users.
  /// includes Caching (24h) and optimizations.
  Future<Map<String, double>> loadRecommendationScores({
    required User? user,
    required GetStorage box,
    bool forceRefresh = false,
  }) async {
    if (user == null) return {};

    final String recCacheKey = 'shop_recommendations_${user.uid}';
    final String recTimeKey = 'shop_rec_timestamp_${user.uid}';

    // 1. Check Cache first
    if (!forceRefresh) {
      final int? timestamp = box.read(recTimeKey);
      final Map<String, dynamic>? cachedScores = box.read(recCacheKey);

      if (timestamp != null && cachedScores != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final diff = DateTime.now().difference(date);

        // Cache is valid for 24 hours
        if (diff.inHours < 24) {
          debugLog(
              '✅ [ALGORITHM] Loading weighted scores from CACHE (Valid for 24h)');
          debugLog('   Timestamp: $date');
          return Map<String, double>.from(cachedScores);
        }
      }
    }

    debugLog(
        '🔄 [ALGORITHM] Recalculating Cosine Similarity & Weighted Scores...');

    try {
      final similarUsers = await _findSimilarUsers(user);
      if (similarUsers.isEmpty) {
        debugLog('⚠️ [ALGORITHM] No similar users found. Logic skipped.');
        // Cache the valid empty result too. Otherwise cold-start users with
        // sparse data repeat the full collaborative query on every visit.
        await box.write(recCacheKey, <String, double>{});
        await box.write(recTimeKey, DateTime.now().millisecondsSinceEpoch);
        return {};
      }

      debugLog(
          '👥 [ALGORITHM] Found ${similarUsers.length} similar users for collaborative filtering.');
      for (final twin in similarUsers) {
        debugLog(
            '   👯 TASTE TWIN: ${twin['userName']} | Similarity: ${(twin['similarity'] as double).toStringAsFixed(2)} | Common Shops: ${twin['commonShops']}');
      }

      final Map<String, double> userSimilarity = {
        for (final u in similarUsers)
          u['userId'] as String: (u['similarity'] as double),
      };

      // OPTIMIZATION: Only fetch popular/verified shops for recommendation candidates
      // Instead of all shops (which could be thousands), limit to top 50 active ones
      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .orderBy('ratings', descending: true)
          .limit(100)
          .get();

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final currentData = currentUserDoc.data() ?? {};
      final currentBookmarks =
          (currentData['bookmarks'] as List?)?.cast<String>() ?? [];
      final currentVisited =
          (currentData['visited'] as List?)?.cast<String>() ?? [];
      final currentShopSet = <String>{...currentBookmarks, ...currentVisited};
      final candidateShopIds = shopsSnapshot.docs.map((doc) => doc.id).toSet();
      final candidateReviews = <String, List<Map<String, dynamic>>>{};
      final reviewsSnapshot =
          await FirebaseFirestore.instance.collectionGroup('reviews').get();
      for (final reviewDoc in reviewsSnapshot.docs) {
        final shopId = reviewDoc.reference.parent.parent?.id;
        if (shopId == null || !candidateShopIds.contains(shopId)) continue;
        candidateReviews.putIfAbsent(shopId, () => []).add(reviewDoc.data());
      }

      final Map<String, double> scores = {};

      for (final shopDoc in shopsSnapshot.docs) {
        final shopId = shopDoc.id;

        // Skip shops user already knows
        if (currentShopSet.contains(shopId)) continue;

        double score = 0.0;
        double totalSim = 0.0;

        for (final data in candidateReviews[shopId] ?? const []) {
          final userId = data['userId'] as String?;
          if (userId == null) continue;

          final sim = userSimilarity[userId];
          if (sim == null || sim <= 0) continue;

          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          // Weighted scoring: similarity * rating
          score += sim * rating;
          totalSim += sim;
        }

        if (totalSim > 0.0) {
          // Normalize: weighted average
          final finalScore = (score / totalSim).clamp(0.0, 5.0);
          scores[shopId] = finalScore;
          debugLog(
              '✨ [ALGORITHM] Recommendation Found: ${shopDoc.data()['name']} -> Score: ${finalScore.toStringAsFixed(2)}');
        }
      }

      // Save to Cache
      await box.write(recCacheKey, scores);
      await box.write(recTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugLog('💾 [ALGORITHM] Scores saved to local cache.');

      return scores;
    } catch (e) {
      debugLog('❌ [ALGORITHM] Error calculating scores: $e');
      return {};
    }
  }
}
