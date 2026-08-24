import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cofi/models/event_model.dart';
import 'package:cofi/models/job_model.dart';
import 'package:cofi/utils/logger.dart';

/// Parses docs defensively: one malformed document must never fail the
/// whole list stream.
List<T> _parseAll<T>(QuerySnapshot<Map<String, dynamic>> s, T Function(Map<String, dynamic>, String) ctor) {
  final out = <T>[];
  for (final d in s.docs) {
    try {
      out.add(ctor(d.data(), d.id));
    } catch (e) {
      debugLog('Skipping unparseable doc ${d.id}: $e');
    }
  }
  return out;
}

/// Read/write access for events and their participants.
///
/// All Firestore queries for events live here so index requirements and
/// filtering rules have a single home.
class EventRepository {
  EventRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _upcomingLimit = 20;
  static const int _communityLimit = 10;

  /// Bounded, server-filtered stream of future public events for the
  /// Explore carousel. Cutoff is the start of today so events that already
  /// began today (ongoing) still surface; finished same-day events are
  /// removed client-side by endDate checks.
  ///
  /// Visibility filtering happens post-parse because status values are
  /// mixed/legacy in existing documents. Note: the server limit may include
  /// hidden events that are then filtered out, so fewer than [limit] items
  /// can be returned — acceptable for now.
  Stream<List<CafeEvent>> watchUpcomingEvents() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return _firestore
        .collectionGroup('events')
        .where('startDate', isGreaterThan: Timestamp.fromDate(startOfToday))
        .orderBy('startDate')
        .limit(_upcomingLimit)
        .snapshots()
        .map((s) => _parseAll(s, CafeEvent.fromFirestore)
            .where(isVisibleEvent)
            .toList());
  }

  /// Latest events for the Community tab. Visibility filtering (rejected,
  /// paused, archived, private) happens post-parse because status values
  /// are mixed in existing documents. Server limit may include hidden
  /// events; acceptable for now.
  Stream<List<CafeEvent>> watchRecentEvents() {
    return _firestore
        .collectionGroup('events')
        .orderBy('createdAt', descending: true)
        .limit(_communityLimit)
        .snapshots()
        .map((s) => _parseAll(s, CafeEvent.fromFirestore)
            .where(isVisibleEvent)
            .toList());
  }

  Future<CafeEvent?> getEvent(String shopId, String eventId) async {
    final doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId)
        .get();
    if (!doc.exists) return null;
    return CafeEvent.fromFirestore(doc.data()!, doc.id);
  }

  Stream<List<EventParticipant>> watchParticipants(
      String shopId, String eventId) {
    return _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .snapshots()
        .map((s) {
      final out = <EventParticipant>[];
      for (final d in s.docs) {
        try {
          out.add(EventParticipant.fromFirestore(d.data()));
        } catch (e) {
          debugLog('Skipping unparseable participant ${d.id}: $e');
        }
      }
      return out;
    });
  }

  /// Joins [userId] to the event and bumps the participant counter inside a
  /// transaction. Throws when already participating.
  Future<void> rsvp({
    required String shopId,
    required String eventId,
    required String userId,
    required String userName,
    required String userPhotoUrl,
  }) async {
    final participantRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .doc(userId);

    final eventRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(participantRef);
      if (existing.exists) {
        throw StateError('Already participating');
      }
      tx.set(participantRef, {
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {
        'participantsCount': FieldValue.increment(1),
      });
    });
  }

  Future<void> cancelRsvp({
    required String shopId,
    required String eventId,
    required String userId,
  }) async {
    final participantRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .doc(userId);

    final eventRef = _firestore
        .collection('shops')
        .doc(shopId)
        .collection('events')
        .doc(eventId);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(participantRef);
      if (!existing.exists) {
        // Already cancelled (double-tap): abort without decrementing so
        // participantsCount can never go negative.
        return;
      }
      tx.delete(participantRef);
      tx.update(eventRef, {
        'participantsCount': FieldValue.increment(-1),
      });
    });
  }
}

/// Read/write access for jobs across shops/{id}/jobs, allJobs and
/// pendingJobs mirrors.
class JobRepository {
  JobRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int _communityLimit = 50;

  /// Latest jobs for the Community tab list.
  Stream<List<Job>> watchRecentJobs() {
    return _firestore
        .collectionGroup('jobs')
        .orderBy('createdAt', descending: true)
        .limit(_communityLimit)
        .snapshots()
        .map((s) => _parseAll(s, Job.fromFirestore));
  }

  /// One-shot fetch of all jobs containing this user's application. The
  /// applications array is embedded per job document, so this cannot be
  /// narrowed server-side until Phase 3's schema migration.
  Future<List<Job>> fetchJobsWithApplication(String applicantId) async {
    final snap = await _firestore.collectionGroup('jobs').get();
    return snap.docs
        .map((d) => Job.fromFirestore(d.data(), d.id))
        .where((job) => job.applications
            .any((app) => app.applicantId == applicantId))
        .toList();
  }

  Future<Job?> getJob(String shopId, String jobId) async {
    final doc = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('jobs')
        .doc(jobId)
        .get();
    if (!doc.exists) return null;
    return Job.fromFirestore(doc.data()!, doc.id);
  }
}
