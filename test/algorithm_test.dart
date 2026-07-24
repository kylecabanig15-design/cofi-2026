
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';

/// Reproduction of the CoFi Recommendation Algorithm for verification.
/// This includes Weight Derivation + Cosine Similarity Index calculation.
void main() {
  group('CoFi Algorithm Full Simulation (Weighting + Similarity)', () {
    
    // 1. Survey Source Data (Respondents %)
    final Map<String, double> surveyVisitData = {
      'Study Session': 50.0,
      'Business Meeting': 39.0,
      'Chill / Hangout': 39.0,
      'Group Gathering': 31.0,
    };

    final Map<String, double> surveyAmenityData = {
      // Drink Types
      'Specialty Coffee': 83.0,
      'Espresso': 70.0, 
      'Spanish Latte': 75.0,
      'Pour Over': 80.0,
      'Flat White': 65.0,
      'Vietnamese Coffee': 60.0,
      'Cold Brew': 60.0,
      'Matcha Drinks': 55.0,

      // Food
      'Pastries': 45.0,

      // Use Case
      'Work-Friendly (Wi-Fi + outlets)': 53.0,
      'Study Sessions': 53.0,
      'Artsy / Aesthetic': 58.0,
      'Instagrammable': 55.0,
      'Night Café (Open Late)': 40.0,
      'Family Friendly': 35.0,

      // Convenience
      'Pet-Friendly': 19.0,
      'Parking Available': 30.0,

      // Vibe
      'Minimalist / Modern': 50.0,
      'Rustic / Cozy': 50.0,
      'Outdoor / Garden': 45.0,
      'Seaside / Scenic': 45.0,
    };

    // 2. Helper: Formula-Driven Weight Generator
    Map<String, double> deriveWeights(Map<String, double> data) {
      return data.map((k, v) => MapEntry(k, v / 100.0));
    }

    final visitWeights = deriveWeights(surveyVisitData);
    final amenityWeights = deriveWeights(surveyAmenityData);

    // 3. Helper: Simulated Cosine Similarity Logic (matches explore_tab.dart)
    double calculateSimilarity({
      required List<Map<String, dynamic>> user1Reviews,
      required List<Map<String, dynamic>> user2Reviews,
      required Map<String, List<String>> shopAmenities,
    }) {
      // Build maps
      final u1Map = {for (var r in user1Reviews) r['shopId'] as String: r};
      final u2Map = {for (var r in user2Reviews) r['shopId'] as String: r};
      final commonShops = u1Map.keys.where((id) => u2Map.containsKey(id)).toSet();

      if (commonShops.isEmpty) return 0.0;

      double numerator = 0.0;
      double sumU1Sq = 0.0;
      double sumU2Sq = 0.0;

      for (var shopId in commonShops) {
        final r1 = u1Map[shopId]!;
        final r2 = u2Map[shopId]!;
        final amenities = shopAmenities[shopId] ?? [];

        // Xp, Yp (Ratings)
        double xp = (r1['rating'] as num).toDouble();
        double yp = (r2['rating'] as num).toDouble();

        // Tp (Visit Tags)
        double tp = 0.0;
        final tags1 = (r1['tags'] as List).cast<String>();
        final tags2 = (r2['tags'] as List).cast<String>();
        for (var t in tags1) {
          if (tags2.contains(t)) tp += visitWeights[t] ?? 0.5;
        }

        // Ap (Amenity Weights)
        double ap = 0.0;
        for (var a in amenities) {
          ap += amenityWeights[a] ?? 0.3;
        }

        final score1 = xp + tp + ap;
        final score2 = yp + tp + ap;

        numerator += score1 * score2;
        sumU1Sq += score1 * score1;
        sumU2Sq += score2 * score2;
      }

      double denominator = sqrt(sumU1Sq) * sqrt(sumU2Sq);
      return denominator == 0 ? 0.0 : numerator / denominator;
    }

    test('Weight Integrity: Study Session should be 0.5 and Specialty Coffee 0.83', () {
      expect(visitWeights['Study Session'], 0.50);
      expect(amenityWeights['Specialty Coffee'], 0.83);
    });

    test('Similarity: Identical users should have 1.0 (100% match)', () {
      final reviews = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']}
      ];
      final Map<String, List<String>> amenities = {'cafe_1': ['Specialty Coffee']};

      final score = calculateSimilarity(
        user1Reviews: reviews,
        user2Reviews: reviews,
        shopAmenities: amenities,
      );
      expect(score, closeTo(1.0, 0.01));
    });

    test('Similarity: High match for "Taste Twins" (Similar ratings and tags)', () {
      final user1 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']}
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 4, 'tags': ['Study Session']}
      ];
      final Map<String, List<String>> amenities = {'cafe_1': ['Specialty Coffee', 'Artsy / Aesthetic']};

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );
      
      // Should be very high (>0.9) because ratings are close (5 vs 4) 
      // and context (Study Session) + amenities match perfectly
      expect(score, greaterThan(0.95)); 
    });

    test('Similarity: Low match for dissimilar ratings across multiple shops', () {
       final user1 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 1, 'tags': []}
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 1, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 5, 'tags': []}
      ];
      final Map<String, List<String>> amenities = {'cafe_1': [], 'cafe_2': []};

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );
      
      // Ratings [5,1] vs [1,5] should result in low similarity (~0.38)
      expect(score, lessThan(0.5));
    });

    test('Similarity: Zero match when no common shops', () {
      final score = calculateSimilarity(
        user1Reviews: [{'shopId': 'A', 'rating': 5, 'tags': []}],
        user2Reviews: [{'shopId': 'B', 'rating': 5, 'tags': []}],
        shopAmenities: <String, List<String>>{},
      );
      expect(score, 0.0);
    });

    test('CF-07: Multi-Café Similarity (3+ common cafés with varying ratings)', () {
      final user1 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']},
        {'shopId': 'cafe_2', 'rating': 4, 'tags': ['Business Meeting']},
        {'shopId': 'cafe_3', 'rating': 3, 'tags': ['Chill / Hangout']},
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']},
        {'shopId': 'cafe_2', 'rating': 4, 'tags': ['Business Meeting']},
        {'shopId': 'cafe_3', 'rating': 3, 'tags': ['Chill / Hangout']},
      ];
      final Map<String, List<String>> amenities = {
        'cafe_1': ['Specialty Coffee', 'Work-Friendly (Wi-Fi + outlets)'],
        'cafe_2': ['Espresso', 'Parking Available'],
        'cafe_3': ['Matcha Drinks', 'Artsy / Aesthetic'],
      };

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );

      // Identical reviews across 3 cafés should yield perfect similarity
      expect(score, closeTo(1.0, 0.01));
    });

    test('CF-08: Rating-Only Similarity (no tags or amenities)', () {
      final user1 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 4, 'tags': []},
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 4, 'tags': []},
      ];
      final Map<String, List<String>> amenities = {
        'cafe_1': [],
        'cafe_2': [],
      };

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );

      // With identical ratings and no tags/amenities, similarity should be 1.0
      expect(score, closeTo(1.0, 0.01));
    });

    test('CF-09: Edge Case - All 1-Star Ratings (identical low preference)', () {
      final user1 = [
        {'shopId': 'cafe_1', 'rating': 1, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 1, 'tags': []},
        {'shopId': 'cafe_3', 'rating': 1, 'tags': []},
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 1, 'tags': []},
        {'shopId': 'cafe_2', 'rating': 1, 'tags': []},
        {'shopId': 'cafe_3', 'rating': 1, 'tags': []},
      ];
      final Map<String, List<String>> amenities = {
        'cafe_1': [],
        'cafe_2': [],
        'cafe_3': [],
      };

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );

      // Both users dislike the same cafés equally - perfect similarity
      expect(score, closeTo(1.0, 0.01));
    });

    test('CF-10: Edge Case - All 5-Star Ratings (identical high preference)', () {
      final user1 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']},
        {'shopId': 'cafe_2', 'rating': 5, 'tags': ['Business Meeting']},
        {'shopId': 'cafe_3', 'rating': 5, 'tags': ['Chill / Hangout']},
      ];
      final user2 = [
        {'shopId': 'cafe_1', 'rating': 5, 'tags': ['Study Session']},
        {'shopId': 'cafe_2', 'rating': 5, 'tags': ['Business Meeting']},
        {'shopId': 'cafe_3', 'rating': 5, 'tags': ['Chill / Hangout']},
      ];
      final Map<String, List<String>> amenities = {
        'cafe_1': ['Specialty Coffee', 'Artsy / Aesthetic'],
        'cafe_2': ['Espresso', 'Work-Friendly (Wi-Fi + outlets)'],
        'cafe_3': ['Matcha Drinks', 'Outdoor / Garden'],
      };

      final score = calculateSimilarity(
        user1Reviews: user1,
        user2Reviews: user2,
        shopAmenities: amenities,
      );

      // Both users love the same cafés with same tags - perfect similarity
      expect(score, closeTo(1.0, 0.01));
    });
  });
}
