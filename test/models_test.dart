import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cofi/models/event_model.dart';
import 'package:cofi/models/job_model.dart';
import 'package:cofi/models/review_model.dart';
import 'package:cofi/models/shop_model.dart';
import 'package:cofi/models/user_model.dart';

void main() {
  group('Shop model', () {
    test('parses all fields and defaults missing ones', () {
      final shop = Shop.fromFirestore({
        'name': 'Cafe A',
        'latitude': 7.07,
        'longitude': 125.6,
        'ratings': 4.5,
        'tags': ['Study Session'],
        'postedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, 'shop1');

      expect(shop.id, 'shop1');
      expect(shop.name, 'Cafe A');
      expect(shop.latitude, 7.07);
      expect(shop.ratings, 4.5);
      expect(shop.isVerified, false);
      expect(shop.submissionType, 'community');
      expect(shop.postedAt, DateTime(2026, 1, 1));
    });

    test('legacy postedBy map yields uid', () {
      expect(
        Shop.legacyPostedByUid({'postedBy': {'uid': 'u123'}}),
        'u123',
      );
      expect(Shop.legacyPostedByUid({'postedBy': 'u456'}), 'u456');
      expect(Shop.legacyPostedByUid({}), isNull);
    });
  });

  group('Job model alias chains', () {
    test('falls back shopName -> cafe -> name', () {
      expect(
        Job.fromFirestore({'cafe': 'Old Cafe'}, 'j1').shopName,
        'Old Cafe',
      );
      expect(
        Job.fromFirestore({'name': 'Newest'}, 'j2').shopName,
        'Newest',
      );
      expect(
        Job.fromFirestore({'shopName': 'Canonical'}, 'j3').shopName,
        'Canonical',
      );
    });

    test('falls back qualifications -> required', () {
      expect(
        Job.fromFirestore({'required': 'Experience'}, 'j1').qualifications,
        'Experience',
      );
    });

    test('accepts String or Timestamp dates', () {
      final fromString = Job.fromFirestore({'startDate': '2026-08-25'}, 'j1');
      final fromTs = Job.fromFirestore({
        'startDate': Timestamp.fromDate(DateTime(2026, 8, 25)),
      }, 'j2');
      expect(fromString.startDate, DateTime(2026, 8, 25));
      expect(fromTs.startDate, DateTime(2026, 8, 25));
    });

    test('parses embedded applications', () {
      final job = Job.fromFirestore({
        'applications': [
          {
            'id': 'app1',
            'applicantId': 'u1',
            'status': 'pending',
            'appliedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
          }
        ],
      }, 'j1');
      expect(job.applications.length, 1);
      expect(job.applications.first.applicantId, 'u1');
    });
  });

  group('Event model', () {
    test('imageUrls falls back to legacy imageUrl', () {
      final ev = CafeEvent.fromFirestore({'imageUrl': 'x.png'}, 'e1');
      expect(ev.imageUrls, ['x.png']);
    });

    test('toFirestore keeps legacy single-image field in sync', () {
      final ev = CafeEvent(id: 'e1', imageUrls: ['a.png', 'b.png']);
      final map = ev.toFirestore();
      expect(map['imageUrl'], 'a.png');
      expect(map['imageUrls'], ['a.png', 'b.png']);
    });
  });

  group('Review model aliases', () {
    test('authorName falls back to name, text falls back to comment', () {
      final r = Review.fromFirestore(
          {'name': 'Kyle', 'comment': 'Great coffee', 'rating': 5}, 'r1');
      expect(r.authorName, 'Kyle');
      expect(r.text, 'Great coffee');
    });

    test('parses authorPhotoUrl and response updatedAt', () {
      final r = Review.fromFirestore({
        'authorPhotoUrl': 'p.png',
        'responses': [
          {
            'id': 'resp1',
            'ownerName': 'Owner',
            'responseText': 'Thanks!',
            'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2026, 8, 2)),
          }
        ],
      }, 'r1');
      expect(r.authorPhotoUrl, 'p.png');
      expect(r.responses.first.updatedAt, DateTime(2026, 8, 2));
    });
  });

  group('AppUser model', () {
    test('displayName wins over legacy name; business detection works', () {
      final u = AppUser.fromFirestore({
        'displayName': 'Display',
        'name': 'Legacy',
        'accountType': 'business',
        'isAdmin': true,
      }, 'u1');
      expect(u.name, 'Display');
      expect(u.isBusiness, true);
      expect(u.isAdmin, true);
    });

    test('never parses isAdmin from arbitrary data as required', () {
      final u = AppUser.fromFirestore({'isAdmin': 'yes'}, 'u1');
      expect(u.isAdmin, false);
    });
  });
}
