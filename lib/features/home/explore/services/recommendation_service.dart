import 'package:cofi/utils/logger.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';

class RecommendationService {
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
    final Map<String, double> defaultVisitTagWeights = {
      'Study Session': 7.5 / 100.0, // Visit Data: 30% × 25% = 7.5 pp
      'Business Meeting': 7.5 / 100.0, // Visit Data: 30% × 25% = 7.5 pp
      'Chill / Hangout': 7.5 / 100.0, // Visit Data: 30% × 25% = 7.5 pp
      'Group Gathering': 7.5 / 100.0, // Visit Data: 30% × 25% = 7.5 pp
    };

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
    final Map<String, double> defaultAmenityTagWeights = {
      // --- Type of Drinks (total 20 pp) ---
      'Specialty Coffee': 6.0 / 100.0, // Drinks: dominant type
      'Espresso': 2.0 / 100.0,
      'Flat White': 2.0 / 100.0,
      'Spanish Latte': 2.0 / 100.0,
      'Vietnamese Coffee': 2.0 / 100.0,
      'Cold Brew': 2.0 / 100.0,
      'Pour Over': 2.0 / 100.0,
      'Matcha Drinks': 2.0 / 100.0,

      // --- Pastries (total 10 pp) ---
      'Pastries': 10.0 / 100.0,

      // --- Convenience (total 20 pp) ---
      'Work-Friendly (Wi-Fi + outlets)': 4.0 / 100.0,
      'Pet-Friendly': 4.0 / 100.0,
      'Parking Available': 4.0 / 100.0,
      'Artsy / Aesthetic': 2.0 / 100.0,
      'Instagrammable': 2.0 / 100.0,
      'Night Café (Open Late)': 2.0 / 100.0,
      'Family Friendly': 2.0 / 100.0,

      // --- Vibe (total 20 pp) ---
      'Minimalist / Modern': 5.0 / 100.0,
      'Rustic / Cozy': 5.0 / 100.0,
      'Outdoor / Garden': 5.0 / 100.0,
      'Seaside / Scenic': 5.0 / 100.0,
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

  /// Finds users similar to the current user using the Cosine Similarity algorithm.
  /// Used internally to derive shop recommendation scores.
  Future<List<Map<String, dynamic>>> _findSimilarUsers(User? user) async {
    if (user == null) return [];

    try {
      // STEP 1: Get current user's reviews AND visits
      // OPTIMIZATION: Only check top 30 most rated or popular shops to build the vector.
      // Checking ALL shops (thousands) is inefficient and costly.
      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .orderBy('ratings',
              descending: true) // Assuming 'ratings' stores average score
          .limit(30)
          .get();

      final currentUserReviews = <Map<String, dynamic>>[];
      final currentUserVisits = <Map<String, dynamic>>[];

      // Get reviews
      for (final shopDoc in shopsSnapshot.docs) {
        final reviewsSnapshot = await shopDoc.reference
            .collection('reviews')
            .where('userId', isEqualTo: user.uid)
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
            .where('userId', isEqualTo: user.uid)
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
          if (userId == null || userId == user.uid) continue;

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
          if (userId == null || userId == user.uid) continue;

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
      debugLog('❌ [ALGORITHM] Error in _findSimilarUsers: $e');
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

      final Map<String, double> scores = {};

      for (final shopDoc in shopsSnapshot.docs) {
        final shopId = shopDoc.id;

        // Skip shops user already knows
        if (currentShopSet.contains(shopId)) continue;

        // Optimization: Use a subcollection query limits
        final reviewsSnapshot =
            await shopDoc.reference.collection('reviews').limit(20).get();

        double score = 0.0;
        double totalSim = 0.0;

        for (final reviewDoc in reviewsSnapshot.docs) {
          final data = reviewDoc.data();
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
