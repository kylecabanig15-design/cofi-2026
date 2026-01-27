import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cofi/models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();
  static const String _unreadCountKey = 'unread_notifications_count';
  
  // ========================================================================
  // AUDITORY ALERT CONFIGURATION (Panel Requirement)
  // ========================================================================
  // Sound triggers ONLY when similarity score exceeds this threshold.
  // This ensures alerts are preference-matched, not for every notification.
  static const double _soundThreshold = 0.7;
  
  // Flutter Local Notifications plugin for auditory alerts
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  // Initialize the service with local notifications and PH locale
  Future<void> init() async {
    if (_isInitialized) return;
    
    await GetStorage.init();
    await initializeDateFormatting('en_PH', null);
    
    // Initialize local notifications for auditory alerts
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    
    _isInitialized = true;
  }

  // Get notifications for the current user
  Stream<List<NotificationModel>> getUserNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Create a notification for a new event
  Future<void> createEventNotification(
      String eventId, String eventTitle, String? imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: 'New Event Posted',
      body: 'Check out the new event: $eventTitle',
      type: 'event',
      relatedId: eventId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
  }

  // Create a notification for a new job posting
  Future<void> createJobNotification(
      String jobId, String jobTitle, String shopName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: 'New Job Posted',
      body: '$shopName is hiring: $jobTitle',
      type: 'job',
      relatedId: jobId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
  }

  // Create a notification for a new shop submission
  Future<void> createShopNotification(
      String shopId, String shopName, String? imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: 'New Shop Submitted',
      body: 'Check out the new coffee shop: $shopName',
      type: 'shop',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
  }

  // Save notification to Firestore
  Future<void> _saveNotification(
      String userId, NotificationModel notification) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toFirestore());

      // Update unread count
      final currentCount = _storage.read(_unreadCountKey) ?? 0;
      _storage.write(_unreadCountKey, currentCount + 1);
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      // Update unread count
      final currentCount = _storage.read(_unreadCountKey) ?? 0;
      if (currentCount > 0) {
        _storage.write(_unreadCountKey, currentCount - 1);
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();

      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      // Reset unread count
      _storage.write(_unreadCountKey, 0);
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notifications count from local storage
  int getUnreadCount() {
    return _storage.read(_unreadCountKey) ?? 0;
  }

  // Reset unread count (call when user opens notifications screen)
  void resetUnreadCount() {
    _storage.write(_unreadCountKey, 0);
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final notificationDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .get();

      if (notificationDoc.exists) {
        final wasUnread = notificationDoc.data()?['isRead'] == false;

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .delete();

        // Update unread count if it was unread
        if (wasUnread) {
          final currentCount = _storage.read(_unreadCountKey) ?? 0;
          if (currentCount > 0) {
            _storage.write(_unreadCountKey, currentCount - 1);
          }
        }
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Check for new data in collections and create notifications
  Future<void> checkForNewData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get the last check time from storage
      final lastCheckKey = 'last_notification_check';
      final lastCheck = _storage.read(lastCheckKey);
      final now = DateTime.now();

      // Convert to Timestamp for Firestore query
      Timestamp? lastCheckTimestamp;
      if (lastCheck != null) {
        lastCheckTimestamp =
            Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(lastCheck));
      }

      // Check for new events
      await _checkForNewEvents(user.uid, lastCheckTimestamp);

      // Check for new jobs
      await _checkForNewJobs(user.uid, lastCheckTimestamp);

      // Check for new jobs
      await _checkForNewJobs(user.uid, lastCheckTimestamp);

      // Check for new job applications
      await _checkForNewJobApplications(user.uid, lastCheckTimestamp);

      // Check for new shops
      await _checkForNewShops(user.uid, lastCheckTimestamp);

      // Update the last check time
      _storage.write(lastCheckKey, now.millisecondsSinceEpoch);
    } catch (e) {
      print('Error checking for new data: $e');
    }
  }

  // Check for new events and create notifications
  Future<void> _checkForNewEvents(String userId, Timestamp? lastCheck) async {
    try {
      // First get all shops to check their events subcollections
      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final isVerified = (shopData['isVerified'] as bool?) ?? false;
        if (!isVerified) continue;

        final shopId = shopDoc.id;
        Query eventsQuery = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events');

        if (lastCheck != null) {
          eventsQuery =
              eventsQuery.where('createdAt', isGreaterThan: lastCheck);
        }

        final eventsSnapshot = await eventsQuery.get();

        for (final eventDoc in eventsSnapshot.docs) {
          final eventData = eventDoc.data() as Map<String, dynamic>?;
          if (eventData == null) continue;
          final eventId = eventDoc.id;
          final eventTitle = eventData['title'] ?? 'New Event';
          final imageUrl = eventData['imageUrl'];

          // Check if notification already exists for this event
          final existingNotification = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('type', isEqualTo: 'event')
              .where('relatedId', isEqualTo: eventId)
              .get();

          if (existingNotification.docs.isEmpty) {
            await createEventNotification(eventId, eventTitle, imageUrl);
          }
        }
      }
    } catch (e) {
      print('Error checking for new events: $e');
    }
  }

  // Check for new jobs and create notifications
  Future<void> _checkForNewJobs(String userId, Timestamp? lastCheck) async {
    try {
      // First get all shops to check their jobs subcollections
      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final isVerified = (shopData['isVerified'] as bool?) ?? false;
        if (!isVerified) continue;

        final shopId = shopDoc.id;
        Query jobsQuery = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('jobs');

        if (lastCheck != null) {
          jobsQuery = jobsQuery.where('createdAt', isGreaterThan: lastCheck);
        }

        final jobsSnapshot = await jobsQuery.get();

        for (final jobDoc in jobsSnapshot.docs) {
          final jobData = jobDoc.data() as Map<String, dynamic>?;
          if (jobData == null) continue;
          final jobId = jobDoc.id;
          final jobTitle = jobData['title'] ?? 'New Job';
          final shopName =
              jobData['shopName'] ?? jobData['cafe'] ?? 'Coffee Shop';

          // Check if notification already exists for this job
          final existingNotification = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('type', isEqualTo: 'job')
              .where('relatedId', isEqualTo: jobId)
              .get();

          if (existingNotification.docs.isEmpty) {
            await createJobNotification(jobId, jobTitle, shopName);
          }
        }
      }
    } catch (e) {
      print('Error checking for new jobs: $e');
    }
  }

  // Check for new job applications and create notifications
  Future<void> _checkForNewJobApplications(
      String userId, Timestamp? lastCheck) async {
    try {
      // Get all shops to check their jobs subcollections for applications
      final shopsSnapshot =
          await FirebaseFirestore.instance.collection('shops').get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data();
        final isVerified = (shopData['isVerified'] as bool?) ?? false;
        if (!isVerified) continue;
        
        final shopId = shopDoc.id;
        Query jobsQuery = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('jobs');

        if (lastCheck != null) {
          jobsQuery = jobsQuery.where('createdAt', isGreaterThan: lastCheck);
        }

        final jobsSnapshot = await jobsQuery.get();

        for (final jobDoc in jobsSnapshot.docs) {
          final jobData = jobDoc.data() as Map<String, dynamic>?;
          if (jobData == null) continue;
          final jobId = jobDoc.id;

          // Check if this job has applications from the current user
          if (jobData.containsKey('applications')) {
            final applications = jobData['applications'] as List<dynamic>?;
            if (applications != null) {
              for (final application in applications) {
                if (application is Map<String, dynamic> &&
                    application['applicantId'] == userId) {
                  final applicationId = application['id'] ?? '';
                  final applicantName =
                      application['applicantName'] ?? 'Applicant';
                  final status = application['status'] ?? 'pending';
                  final appliedAt = application['appliedAt'] as Timestamp?;

                  // Check if notification already exists for this application
                  final existingNotification = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('notifications')
                      .where('type', isEqualTo: 'job_application')
                      .where('relatedId', isEqualTo: applicationId)
                      .get();

                  if (existingNotification.docs.isEmpty) {
                    await _createJobApplicationNotification(
                        applicationId,
                        applicantName,
                        status,
                        appliedAt,
                        jobId,
                        jobData['title'] ?? 'New Job',
                        jobData['shopName'] ??
                            jobData['cafe'] ??
                            'Coffee Shop');
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking for new job applications: $e');
    }
  }

  // Create a notification for a new job application
  Future<void> _createJobApplicationNotification(
      String applicationId,
      String applicantName,
      String status,
      Timestamp? appliedAt,
      String jobId,
      String jobTitle,
      String shopName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String statusText = 'Pending';
    if (status == 'accepted') {
      statusText = 'Accepted';
    } else if (status == 'rejected') {
      statusText = 'Rejected';
    }

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: 'Job Application Update',
      body:
          '$applicantName\'s application for $jobTitle at $shopName is $statusText',
      type: 'job_application',
      relatedId: applicationId,
      createdAt: appliedAt?.toDate() ?? DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
  }

  // Create a notification for recommendation-based café suggestions
  // ========================================================================
  // PREFERENCE-MATCHED AUDITORY ALERTS (Panel Requirement)
  // ========================================================================
  // Sound triggers ONLY if the similarity score exceeds _soundThreshold (0.7).
  // This ensures users are only alerted for high-relevance recommendations.
  Future<void> createRecommendationNotification(
    String shopId,
    String shopName,
    double recommendationScore,
    String? imageUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only create notification if recommendation score is high enough (> 0.5)
    if (recommendationScore <= 0.5) return;

    // Format timestamp in Philippines (PH) locale
    final formattedTime = formatPhilippinesDate(DateTime.now());
    
    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: 'Recommended Café',
      body: 'We think you\'ll love $shopName based on your preferences',
      type: 'recommendation',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
    
    // ========================================================================
    // AUDITORY ALERT: Only trigger sound if preference match is high (≥ 0.7)
    // ========================================================================
    if (recommendationScore >= _soundThreshold) {
      await _showLocalNotificationWithSound(
        title: '🎯 Perfect Match Found!',
        body: '$shopName matches ${(recommendationScore * 100).toInt()}% of your preferences • $formattedTime',
      );
    }
  }
  
  // ========================================================================
  // LOCAL NOTIFICATION WITH SOUND
  // ========================================================================
  // Uses the default system notification sound for maximum compatibility.
  // Custom sounds can be added to res/raw (Android) and Runner (iOS).
  Future<void> _showLocalNotificationWithSound({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'cofi_high_importance',
      'CoFi High Importance',
      channelDescription: 'High priority notifications for preference-matched recommendations',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Uses default system sound for compatibility
      // To use custom sound: sound: RawResourceAndroidNotificationSound('notification_sound'),
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
      // Uses default system sound for compatibility
      // To use custom sound: sound: 'notification_sound.aiff',
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
  
  // ========================================================================
  // PHILIPPINES DATE FORMATTING (Panel Requirement)
  // ========================================================================
  // All timestamps must follow PH format: "January 27, 2026 3:00 PM"
  String formatPhilippinesDate(DateTime dateTime) {
    final formatter = DateFormat('MMMM d, y h:mm a', 'en_PH');
    return formatter.format(dateTime);
  }


  // Check for and create recommendation notifications based on user interests
  Future<void> createRecommendationsBasedOnInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get user's interests and visited shops
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final userInterests =
          (userData?['interests'] as List?)?.cast<String>() ?? [];
      final visitedShops =
          (userData?['visited'] as List?)?.cast<String>() ?? [];
      final recommendedShops =
          (userData?['recommendedShops'] as List?)?.cast<String>() ?? [];

      if (userInterests.isEmpty) return;

      // Query shops that match user interests and haven't been visited or recommended yet
      final shopsSnapshot = await _firestore
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .where('tags', arrayContainsAny: userInterests)
          .limit(10)
          .get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopId = shopDoc.id;

        // Skip if already visited or already recommended
        if (visitedShops.contains(shopId) ||
            recommendedShops.contains(shopId)) {
          continue;
        }

        // Check if notification already exists for this recommendation
        final existingNotification = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('type', isEqualTo: 'recommendation')
            .where('relatedId', isEqualTo: shopId)
            .get();

        if (existingNotification.docs.isNotEmpty) continue;

        final shopData = shopDoc.data();
        final shopName = (shopData['name'] as String?) ?? 'Café';
        final imageUrl = (shopData['logoUrl'] as String?);

        // Calculate a simple recommendation score based on rating and reviews
        final ratings = (shopData['ratings'] as num?)?.toDouble() ?? 0.0;
        final reviewCount = ((shopData['reviews'] as List?)?.length ?? 0);
        final recommendationScore =
            ratings / 5.0 * (1 + (reviewCount / 100).clamp(0, 1));

        await createRecommendationNotification(
          shopId,
          shopName,
          recommendationScore,
          imageUrl,
        );
      }

      // Update user's recommended shops list
      if (shopsSnapshot.docs.isNotEmpty) {
        final newRecommendedShops = shopsSnapshot.docs
            .map((doc) => doc.id)
            .where((id) => !recommendedShops.contains(id))
            .toList();

        if (newRecommendedShops.isNotEmpty) {
          await _firestore.collection('users').doc(user.uid).update({
            'recommendedShops': FieldValue.arrayUnion(newRecommendedShops),
          });
        }
      }
    } catch (e) {
      print('Error creating recommendation notifications: $e');
    }
  }

  // Check for new shops and create notifications
  Future<void> _checkForNewShops(String userId, Timestamp? lastCheck) async {
    try {
      Query shopsQuery = FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true);

      if (lastCheck != null) {
        shopsQuery = shopsQuery.where('postedAt', isGreaterThan: lastCheck);
      }

      final shopsSnapshot = await shopsQuery.get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data() as Map<String, dynamic>?;
        if (shopData == null) continue;
        final shopId = shopDoc.id;
        final shopName = shopData['name'] ?? 'New Coffee Shop';
        final imageUrl = shopData['logoUrl'];

        // Check if notification already exists for this shop
        final existingNotification = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('type', isEqualTo: 'shop')
            .where('relatedId', isEqualTo: shopId)
            .get();

        if (existingNotification.docs.isEmpty) {
          await createShopNotification(shopId, shopName, imageUrl);
        }
      }
    } catch (e) {
      print('Error checking for new shops: $e');
    }
  }
}
