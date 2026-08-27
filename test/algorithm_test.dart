import 'package:cofi/features/home/explore/services/recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = RecommendationService();

  group('documented recommendation algorithm', () {
    test('uses the normalized weights published in the documentation', () {
      expect(
          RecommendationService.defaultVisitTagWeights.values
              .reduce((a, b) => a + b),
          closeTo(0.30, 1e-10));
      expect(
          RecommendationService.defaultAmenityTagWeights.values
              .reduce((a, b) => a + b),
          closeTo(0.70, 1e-10));
      expect(
          RecommendationService.defaultVisitTagWeights['Study Session'], 0.075);
      expect(RecommendationService.defaultAmenityTagWeights['Specialty Coffee'],
          0.06);
    });

    test('reproduces the documented worked example', () {
      final similarity = service.calculateCosineSimilarity(
        user1Reviews: const [
          {
            'shopId': 'a',
            'rating': 4.0,
            'tags': ['Chill / Hangout']
          },
          {
            'shopId': 'b',
            'rating': 5.0,
            'tags': ['Study Session']
          },
          {
            'shopId': 'c',
            'rating': 3.0,
            'tags': ['Study Session']
          },
        ],
        user2Reviews: const [
          {
            'shopId': 'a',
            'rating': 4.0,
            'tags': ['Chill / Hangout']
          },
          {
            'shopId': 'b',
            'rating': 4.0,
            'tags': ['Business Meeting']
          },
          {
            'shopId': 'c',
            'rating': 5.0,
            'tags': ['Business Meeting']
          },
        ],
        shopAmenities: const {
          'a': ['Work-Friendly (Wi-Fi + outlets)'],
          'b': ['Work-Friendly (Wi-Fi + outlets)', 'Minimalist / Modern'],
          'c': ['Parking Available'],
        },
      );

      expect(similarity, closeTo(0.957, 0.001));
    });

    test('returns one for identical rated preferences', () {
      final similarity = service.calculateCosineSimilarity(
        user1Reviews: const [
          {
            'shopId': 'a',
            'rating': 5,
            'tags': ['Study Session']
          },
          {
            'shopId': 'b',
            'rating': 2,
            'tags': ['Chill / Hangout']
          },
        ],
        user2Reviews: const [
          {
            'shopId': 'a',
            'rating': 5,
            'tags': ['Study Session']
          },
          {
            'shopId': 'b',
            'rating': 2,
            'tags': ['Chill / Hangout']
          },
        ],
        shopAmenities: const {
          'a': ['Specialty Coffee'],
          'b': ['Outdoor / Garden'],
        },
      );

      expect(similarity, closeTo(1.0, 1e-10));
    });

    test('returns zero when users have no commonly rated café', () {
      final similarity = service.calculateCosineSimilarity(
        user1Reviews: const [
          {'shopId': 'a', 'rating': 5, 'tags': <String>[]}
        ],
        user2Reviews: const [
          {'shopId': 'b', 'rating': 5, 'tags': <String>[]}
        ],
        shopAmenities: const {},
      );

      expect(similarity, 0.0);
    });
  });

  group('review and visit signal merging', () {
    test('preserves rating and combines unique visit tags', () {
      final merged = RecommendationService.mergeReviewAndVisitSignals(
        reviews: const [
          {
            'shopId': 'a',
            'rating': 4,
            'tags': ['Study Session']
          },
        ],
        visits: const [
          {
            'shopId': 'a',
            'tags': ['Study Session', 'Business Meeting']
          },
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single['rating'], 4);
      expect((merged.single['tags'] as List<String>).toSet(),
          {'Study Session', 'Business Meeting'});
    });

    test('does not convert a standalone visit into a zero-star review', () {
      final merged = RecommendationService.mergeReviewAndVisitSignals(
        reviews: const [],
        visits: const [
          {
            'shopId': 'a',
            'tags': ['Study Session']
          }
        ],
      );

      expect(merged, isEmpty);
    });
  });

  group('recommendation cache policy', () {
    final now = DateTime(2026, 8, 28, 12);
    final freshTimestamp =
        now.subtract(const Duration(hours: 23)).millisecondsSinceEpoch;
    final expiredTimestamp =
        now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

    test('keeps a compatible unchanged cache for less than 24 hours', () {
      expect(
        RecommendationService.cacheNeedsRevalidation(
          hasScores: true,
          generatedAtMilliseconds: freshTimestamp,
          isDirty: false,
          cachedAlgorithmVersion:
              RecommendationService.recommendationAlgorithmVersion,
          now: now,
        ),
        isFalse,
      );
    });

    test('revalidates dirty, expired, missing, or old-formula caches', () {
      bool shouldRefresh({
        bool hasScores = true,
        int? timestamp,
        bool dirty = false,
        int? algorithmVersion,
      }) {
        return RecommendationService.cacheNeedsRevalidation(
          hasScores: hasScores,
          generatedAtMilliseconds: timestamp ?? freshTimestamp,
          isDirty: dirty,
          cachedAlgorithmVersion: algorithmVersion ??
              RecommendationService.recommendationAlgorithmVersion,
          now: now,
        );
      }

      expect(shouldRefresh(dirty: true), isTrue);
      expect(shouldRefresh(timestamp: expiredTimestamp), isTrue);
      expect(shouldRefresh(hasScores: false), isTrue);
      expect(shouldRefresh(algorithmVersion: 1), isTrue);
    });
  });
}
