import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
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

    // Request runtime permission for Android 13+
    if (await Permission.notification.isDenied) {
      print('🔔 [NOTIFICATIONS] Requesting permission...');
      await Permission.notification.request();
    }
    
    // Create high importance channel for Android to ensure sound and importance are locked in
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
        'cofi_high_importance',
        'CoFi High Importance',
        description: 'High priority notifications for preference-matched recommendations',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      ));
    }
    
    _isInitialized = true;
  }

  // Get notifications for the current user
  // PRIORITY SORTING: Alerts first, then by creation date
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
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
              .toList();
          
          // Sort: Alerts first, then by creation date
          notifications.sort((a, b) {
            // Alerts come first
            if (a.isAlert != b.isAlert) {
              return a.isAlert ? -1 : 1;
            }
            // Within same alert status, newer first
            return b.createdAt.compareTo(a.createdAt);
          });
          
          return notifications;
        });
  }

  // Create a notification for a new event
  Future<void> createEventNotification(
      String eventId, String eventTitle, String? imageUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: '🎉 Happening Soon in Davao',
      body: '$eventTitle is now live! Don\'t miss out on this exciting café experience.',
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
      title: '💼 Career Opportunity Available',
      body: '$shopName is looking for a $jobTitle. Join their team and brew your future!',
      type: 'job',
      relatedId: jobId,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await _saveNotification(user.uid, notification);
  }

  // Create a notification for a new shop submission
  Future<void> createShopNotification(
      String shopId, String shopName, String? imageUrl, {bool isAlert = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: isAlert ? '🎯 Taste Match Discovery!' : '☕ New Discovery in Davao',
      body: isAlert 
          ? 'We found a new café that matches your interests: $shopName! Check it out.'
          : '$shopName has joined the CoFi community. Be among the first to explore their unique brew!',
      type: 'shop',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
      isAlert: isAlert,
      priority: isAlert ? 'high' : 'low',
    );

    await _saveNotification(user.uid, notification);

    if (isAlert) {
      final formattedTime = formatPhilippinesDate(DateTime.now());
      await _showLocalNotificationWithSound(
        title: '🎯 Taste Match Discovery!',
        body: '$shopName perfectly matches your coffee interests • $formattedTime',
      );
    }
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

  // Delete all notifications for the current user
  Future<void> deleteAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      // Reset unread count
      _storage.write(_unreadCountKey, 0);
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  // Check for new data in collections and create notifications
  Future<void> checkForNewData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get the last check time from storage (USER SPECIFIC)
    final lastCheckKey = 'last_notification_check_${user.uid}';
      final lastCheck = _storage.read(lastCheckKey);
      final now = DateTime.now();

      // Convert to Timestamp for Firestore query
      // DEFAULT: Only check last 24 hours if no previous check exists
      // This prevents 'old' data from spamming the user on first launch
      final oneDayAgo = now.subtract(const Duration(hours: 24));
      Timestamp lastCheckTimestamp = lastCheck != null
          ? Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(lastCheck))
          : Timestamp.fromDate(oneDayAgo);

      // Check for new events
      await _checkForNewEvents(user.uid, lastCheckTimestamp);

      // Check for new jobs
      await _checkForNewJobs(user.uid, lastCheckTimestamp);

      // Check for new job applications
      await _checkForNewJobApplications(user.uid, lastCheckTimestamp);

      // Check for new shops
      await _checkForNewShops(user.uid, lastCheckTimestamp);

      // Check for new reviews on recommended/visited shops
    await _checkForNewReviews(user.uid, lastCheckTimestamp);

    // FIRST TIME / STARTUP RECOMMENDATIONS: 
    // This ensures new accounts see recommendations even if no shops were "just posted"
    await createRecommendationsBasedOnInterests();

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
            .collection('events')
            .where('createdAt', isGreaterThan: lastCheck);

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
            .collection('jobs')
            .where('createdAt', isGreaterThan: lastCheck);

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
            .collection('jobs')
            .where('createdAt', isGreaterThan: lastCheck);

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

    String statusTitle = 'Job Application Update';
    String statusBody = '$applicantName\'s application for $jobTitle at $shopName is $statusText';

    if (status == 'accepted') {
      statusTitle = '🎊 Application Accepted!';
      statusBody = 'Congratulations! Your application for $jobTitle at $shopName has been accepted. Check your email for next steps!';
    } else if (status == 'rejected') {
      statusTitle = '📋 Application Status Update';
      statusBody = 'Your application for $jobTitle at $shopName has been reviewed. Thank you for your interest in joining the community.';
    }

    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: statusTitle,
      body: statusBody,
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
    print('🚀 [NOTIFICATIONS] Creating recommendation notification: $shopName (Score: $recommendationScore)');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Only create notification if recommendation score is high enough (> 0.5)
    if (recommendationScore <= 0.5) return;

    // Format timestamp in Philippines (PH) locale
    final formattedTime = formatPhilippinesDate(DateTime.now());
    
    // Determine if this is an ALERT (sound-enabled) based on score
    final isAlert = recommendationScore >= _soundThreshold; // 0.7 or higher
    
    if (isAlert) {
      print('🎯 [NOTIFICATION LOGIC] PERFECT MATCH: $recommendationScore >= 0.7');
    } else {
      print('⚖️ [NOTIFICATION LOGIC] STANDARD: $recommendationScore < 0.7');
    }
    
    final priority = isAlert ? 'high' : 'medium';
    
    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: isAlert ? '🎯 Perfect Match Found!' : 'Recommended Café',
      body: isAlert 
          ? 'We think you\'ll love $shopName! ${(recommendationScore * 100).toInt()}% match'
          : 'We think you\'ll love $shopName based on your preferences',
      type: 'recommendation',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
      isAlert: isAlert, // TRUE if score >= 0.7 (triggers sound)
      priority: priority,
    );

    await _saveNotification(user.uid, notification);
    
    // ========================================================================
    // AUDITORY ALERT: Only trigger sound if preference match is high (>= 0.7)
    // ========================================================================
    if (isAlert) {
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
    print('🔔 [NOTIFICATIONS] Showing notification: $title');
    final androidDetails = AndroidNotificationDetails(
      'cofi_high_importance',
      'CoFi High Importance',
      channelDescription: 'High priority notifications for preference-matched recommendations',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
    );
    
    final iosDetails = DarwinNotificationDetails(
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
      NotificationDetails(android: androidDetails, iOS: iosDetails),
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

  // Check for new reviews on recommended and visited shops
  Future<void> _checkForNewReviews(String userId, Timestamp? lastCheck) async {
    try {
      // Only check reviews for shops the current user OWNS (Business Owners only)
    final shopsOwnedSnapshot = await _firestore
        .collection('shops')
        .where('ownerId', isEqualTo: userId)
        .get();

    final relevantShops = shopsOwnedSnapshot.docs.map((doc) => doc.id).toList();

    if (relevantShops.isEmpty) return;

      for (final shopId in relevantShops) {
        Query reviewsQuery = _firestore
            .collection('shops')
            .doc(shopId)
            .collection('reviews')
            .orderBy('createdAt', descending: true); // Get newest first

        if (lastCheck != null) {
          reviewsQuery = reviewsQuery.where('createdAt', isGreaterThan: lastCheck);
        }

        // ANTI-SPAM: Only check for the most recent high-rated review per shop
        final reviewsSnapshot = await reviewsQuery.limit(1).get();
        if (reviewsSnapshot.docs.isEmpty) continue;

        // Get shop name for the notification
        final shopDoc = await _firestore.collection('shops').doc(shopId).get();
        final shopName = shopDoc.data()?['name'] ?? 'a café you like';

        final reviewDoc = reviewsSnapshot.docs.first;
        final reviewData = reviewDoc.data() as Map<String, dynamic>;
        if (reviewData['userId'] == userId) continue; // Skip own reviews

        final reviewerName = reviewData['authorName'] ?? 'A user';
        final reviewText = reviewData['text'] ?? '';
        final rating = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
        final imageUrl = reviewData['authorPhotoUrl'];

        // Only create notification if it's high-rated (Professional quality control)
        if (rating >= 4.0) {
          await createReviewNotification(
            reviewDoc.id,
            shopId,
            shopName,
            reviewerName,
            reviewText,
            rating,
            imageUrl,
          );
        }
      }
    } catch (e) {
      print('Error checking for new reviews: $e');
    }
  }

  // Create a notification for a new review
  Future<void> createReviewNotification(
    String reviewId,
    String shopId,
    String shopName,
    String reviewerName,
    String reviewText,
    double rating,
    String? imageUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Truncate review text for the body
    final displayBody = reviewText.length > 60 
        ? '${reviewText.substring(0, 57)}...' 
        : reviewText;

    // Determine if this is an ALERT (sound-enabled) based on rating
    final isAlert = rating >= 4.0;
    
    final notification = NotificationModel(
      id: _firestore.collection('users').doc().id,
      title: '⭐ New Review for $shopName',
      body: '$reviewerName left a review: "$displayBody"',
      type: 'review',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isRead: false,
      isAlert: isAlert,
      priority: isAlert ? 'high' : 'medium',
    );

    await _saveNotification(user.uid, notification);

    if (isAlert) {
      await _showLocalNotificationWithSound(
        title: '⭐ Top Rated Review on $shopName!',
        body: '$reviewerName gave your shop a high rating. Check it out!',
      );
    }
  }

  // Check for new shops and create notifications
  Future<void> _checkForNewShops(String userId, Timestamp? lastCheck) async {
    try {
      // Get user interests for taste matching
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userInterests = (userDoc.data()?['interests'] as List? ?? []).cast<String>();

      Query shopsQuery = FirebaseFirestore.instance
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .where('postedAt', isGreaterThan: lastCheck);

      final shopsSnapshot = await shopsQuery.get();

      for (final shopDoc in shopsSnapshot.docs) {
        final shopData = shopDoc.data() as Map<String, dynamic>?;
        if (shopData == null) continue;
        final shopId = shopDoc.id;
        final shopName = shopData['name'] ?? 'New Coffee Shop';
        final imageUrl = shopData['logoUrl'];
        final shopTags = (shopData['tags'] as List? ?? []).cast<String>();

        // TASTE MATCH CHECK: Trigger sound alert if tags match user interests
      final isTasteMatch = shopTags.any((tag) => userInterests.contains(tag));
      
      if (isTasteMatch) {
        print('🎯 [DISCOVERY LOGIC] NEW SHOP INTEREST MATCH: $shopName matches interests');
      } else {
        print('☕ [DISCOVERY LOGIC] NEW SHOP DISCOVERY: $shopName');
      }

        // Check if notification already exists for this shop
        final existingNotification = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('type', isEqualTo: 'shop')
            .where('relatedId', isEqualTo: shopId)
            .get();

        if (existingNotification.docs.isEmpty) {
          await createShopNotification(shopId, shopName, imageUrl, isAlert: isTasteMatch);
        }
      }
    } catch (e) {
      print('Error checking for new shops: $e');
    }
  }
}
