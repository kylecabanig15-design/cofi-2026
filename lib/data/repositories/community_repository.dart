import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cofi/models/event_model.dart';
import 'package:cofi/models/job_model.dart';

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
  /// Explore carousel.
  Stream<List<CafeEvent>> watchUpcomingEvents() {
    return _firestore
        .collectionGroup('events')
        .where('startDate',
            isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('startDate')
        .limit(_upcomingLimit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CafeEvent.fromFirestore(d.data(), d.id)).toList());
  }

  /// Latest events for the Community tab. Client code filters paused,
  /// archived and non-active statuses because status values are mixed in
  /// existing documents.
  Stream<List<CafeEvent>> watchRecentEvents() {
    return _firestore
        .collectionGroup('events')
        .orderBy('createdAt', descending: true)
        .limit(_communityLimit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => CafeEvent.fromFirestore(d.data(), d.id)).toList());
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
        .map((s) => s.docs
            .map((d) => EventParticipant.fromFirestore(d.data()))
            .toList());
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
        .map((s) =>
            s.docs.map((d) => Job.fromFirestore(d.data(), d.id)).toList());
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
