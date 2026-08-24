import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:math' as dart_math;
import 'package:permission_handler/permission_handler.dart';
import 'package:cofi/models/notification_model.dart';
import 'package:cofi/utils/globals.dart';
import 'dart:convert';
import 'dart:async';

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
  String? _activeChatId;
  
  // Track which chat is currently open to suppress banners
  void setActiveChat(String? chatId) {
    _activeChatId = chatId;
  }
  
  String? get activeChatId => _activeChatId;
  
  // Stream for in-app banners
  final StreamController<NotificationModel> _inAppBannerController = StreamController<NotificationModel>.broadcast();
  Stream<NotificationModel> get inAppBannerStream => _inAppBannerController.stream;

  final DateTime _listenerStartTime = DateTime.now();

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
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          try {
            final payloadData = jsonDecode(response.payload!);
            if (payloadData['type'] == 'chat') {
              Globals.navigatorKey.currentState?.pushNamed('/jobChat', arguments: payloadData['args']);
            }
          } catch (e) {
            print('Error parsing payload: $e');
          }
        }
      },
    );

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
    _setupNotificationListener();
  }

  /// Requests the notification permission. Called AFTER first frame
  /// (deferred out of main() so cold start is never blocked by the OS dialog).
  Future<void> requestPermissionIfNeeded() async {
    if (await Permission.notification.isDenied) {
      print('🔔 [NOTIFICATIONS] Requesting permission...');
      await Permission.notification.request();
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  StreamSubscription<User?>? _authSub;

  void _setupNotificationListener() {
    // Cancel previous subscriptions so repeated auth events never leak
    // nested Firestore listeners (pre-existing leak).
    _authSub?.cancel();
    _notifSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _notifSub = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .snapshots()
            .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data == null) continue;
              final notification = NotificationModel.fromFirestore(data, change.doc.id);
              
              // Skip if it's for the currently active chat
              if (notification.type == 'chat' && _activeChatId == notification.relatedId) {
                // Automatically mark as read
                markAsRead(notification.id);
                continue;
              }

              // Only trigger in-app banners/alerts for TRULY new notifications
              // (created after the listener initialized, minus a small 5-second buffer)
              if (notification.createdAt.isBefore(_listenerStartTime.subtract(const Duration(seconds: 5)))) {
                continue;
              }

              // Broadcast to in-app banners
              _inAppBannerController.add(notification);

              // Only show local push for alerts
              if (notification.isAlert) {
                String? payload;
                if (notification.type == 'chat' && notification.metadata != null) {
                  payload = jsonEncode({
                    'type': 'chat',
                    'args': notification.metadata,
                  });
                }
                
                await _showLocalNotificationWithSound(
                  title: notification.title,
                  body: notification.body,
                  payload: payload,
                );
              }
            }
          }
        });
      }
    });
  }

  // Get notifications for the current user and their active role
  // PRIORITY SORTING: Alerts first, then by creation date
  Stream<List<NotificationModel>> getUserNotifications({required String role}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc.data(), doc.id))
              .where((n) => n.recipientRole == role)
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
      String userId, String eventId, String eventTitle, String? imageUrl, Timestamp originalTimestamp) async {
    final notification = NotificationModel(
      id: 'event_$eventId',
      title: '🎉 Happening Soon in Davao',
      body: '$eventTitle is now live! Don\'t miss out on this exciting café experience.',
      type: 'event',
      relatedId: eventId,
      imageUrl: imageUrl,
      createdAt: originalTimestamp.toDate(),
      isRead: false,
      recipientRole: 'user',
    );

    await _saveNotification(userId, notification);
  }

  // Create a notification for a new job posting
  Future<void> createJobNotification(
      String userId, String jobId, String jobTitle, String shopName, Timestamp originalTimestamp) async {
    final notification = NotificationModel(
      id: 'job_$jobId',
      title: '💼 Career Opportunity Available',
      body: '$shopName is looking for a $jobTitle. Join their team and brew your future!',
      type: 'job',
      relatedId: jobId,
      createdAt: originalTimestamp.toDate(),
      isRead: false,
      recipientRole: 'user',
    );

    await _saveNotification(userId, notification);
  }

  // Create a notification for a new shop submission
  Future<void> createShopNotification(
      String userId, String shopId, String shopName, String? imageUrl, Timestamp originalTimestamp, {bool isAlert = false}) async {
    final notification = NotificationModel(
      id: 'shop_$shopId',
      title: isAlert ? '🎯 Taste Match Discovery!' : '☕ New Discovery in Davao',
      body: isAlert 
          ? 'We found a new café that matches your interests: $shopName! Check it out.'
          : '$shopName has joined the CoFi community. Be among the first to explore their unique brew!',
      type: 'shop',
      relatedId: shopId,
      imageUrl: imageUrl,
      createdAt: originalTimestamp.toDate(),
      isRead: false,
      isAlert: isAlert,
      priority: isAlert ? 'high' : 'low',
      recipientRole: 'user',
    );

    await _saveNotification(userId, notification);

    if (isAlert) {
      final formattedTime = formatPhilippinesDate(DateTime.now());
      await _showLocalNotificationWithSound(
        title: '🎯 Taste Match Discovery!',
        body: '$shopName perfectly matches your coffee interests • $formattedTime',
      );
    }
  }

  // ========================================================================
  // SETTINGS CHECK
  // ========================================================================
  Future<bool> _isNotificationTypeEnabled(String userId, String type) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return true; // Default to true if user doc missing
      final data = doc.data()!;
      final masterToggle = data['notificationsEnabled'] ?? true;
      if (!masterToggle) return false;

      switch (type) {
        case 'chat': return data['chatsEnabled'] ?? true;
        case 'job':
        case 'job_application':
        case 'business_application':
          return data['jobUpdatesEnabled'] ?? true;
        case 'review': return data['reviewsEnabled'] ?? true;
        case 'event': return data['cafeEventsEnabled'] ?? true;
        case 'event_participation': return data['eventParticipationEnabled'] ?? true;
        case 'recommendation': return data['tasteTwinsEnabled'] ?? true;
        case 'shop': return data['communityActivityEnabled'] ?? true;
        default: return true;
      }
    } catch (e) {
      return true; // Default true on error
    }
  }

  // Helper method to save notification to Firestore
  // Uses deterministic checking to prevent recreating old read notifications
  Future<void> _saveNotification(
      String userId, NotificationModel notification) async {
    try {
      // Check user preferences
      if (!await _isNotificationTypeEnabled(userId, notification.type)) return;

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notification.id);

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        // Do not overwrite existing notification read-state or readAt timestamps!
        return;
      }

      await docRef.set(notification.toFirestore());

      // Update unread count
      final currentCount = _storage.read(_unreadCountKey) ?? 0;
      _storage.write(_unreadCountKey, currentCount + 1);
    } catch (e) {
      print('Error saving notification: $e');
    }
  }

  // Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });

      // Update unread count
      final currentCount = _storage.read(_unreadCountKey) ?? 0;
      if (currentCount > 0) {
        _storage.write(_unreadCountKey, currentCount - 1);
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read for the current role
  Future<void> markAllAsRead({required String role}) async {
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
        final data = doc.data();
        final docRole = data['recipientRole'] ?? 'user';
        
        if (docRole == role) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
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
      // DEFAULT: Set to 'now' if no previous check exists (e.g. new account)
      // This ensures users only receive notifications for events/cafes posted AFTER they created their account
      Timestamp lastCheckTimestamp = lastCheck != null
          ? Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(lastCheck))
          : Timestamp.fromDate(now);

      // Check for new data with a SINGLE shared shops fetch (previously the
      // full shops collection was downloaded once per check — 3x+ reads).
      final verifiedShops = await _firestore
          .collection('shops')
          .where('isVerified', isEqualTo: true)
          .get();

      // Check for new jobs
      await _checkForNewJobs(user.uid, lastCheckTimestamp, verifiedShops);

      // Check for new job applications
      await _checkForNewJobApplications(
          user.uid, lastCheckTimestamp, verifiedShops);

      // Check for new shops
      await _checkForNewShops(user.uid, lastCheckTimestamp);

      // Check for new events
      await _checkForNewEvents(user.uid, lastCheckTimestamp, verifiedShops);

    // FIRST TIME / STARTUP RECOMMENDATIONS: 
    // This ensures new accounts see recommendations even if no shops were "just posted"
    await createRecommendationsBasedOnInterests();

      // Update the last check time
      _storage.write(lastCheckKey, now.millisecondsSinceEpoch);
    } catch (e) {
      print('Error checking for new data: $e');
    }
  }

  // Check for new jobs and create notifications
  Future<void> _checkForNewJobs(String userId, Timestamp? lastCheck,
      QuerySnapshot<Map<String, dynamic>> verifiedShops) async {
    try {
      for (final shopDoc in verifiedShops.docs) {
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

          final createdAt = jobData['createdAt'] as Timestamp? ?? Timestamp.now();
          // Check if notification already exists for this job
          final existingNotification = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('type', isEqualTo: 'job')
              .where('relatedId', isEqualTo: jobId)
              .get();

          if (existingNotification.docs.isEmpty) {
            await createJobNotification(userId, jobId, jobTitle, shopName, createdAt);
          }
        }
      }
    } catch (e) {
      print('Error checking for new jobs: $e');
    }
  }

  // Check for new job applications and create notifications
  Future<void> _checkForNewJobApplications(String userId, Timestamp? lastCheck,
      QuerySnapshot<Map<String, dynamic>> verifiedShops) async {
    try {
      for (final shopDoc in verifiedShops.docs) {
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
                    await createJobApplicationNotification(
                        userId,
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
  Future<void> createJobApplicationNotification(
      String userId,
      String applicationId,
      String applicantName,
      String status,
      Timestamp? appliedAt,
      String jobId,
      String jobTitle,
      String shopName) async {
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
      id: 'job_app_status_${applicationId}_${status}',
      title: statusTitle,
      body: statusBody,
      type: 'job_application',
      relatedId: applicationId,
      createdAt: appliedAt?.toDate() ?? DateTime.now(),
      isRead: false,
      recipientRole: 'user',
    );

    await _saveNotification(userId, notification);
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
      id: 'rec_$shopId',
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
      recipientRole: 'user',
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
    String? payload,
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
      payload: payload,
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
      // Check randomized interval state
      final prefs = await SharedPreferences.getInstance();
      final nextGenKey = 'next_taste_twins_gen_${user.uid}';
      final nextGenTime = prefs.getInt(nextGenKey);
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      if (nextGenTime != null && nowMs < nextGenTime) {
        // It is not time yet to generate a new Taste Twins match
        return;
      }

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

      // Set the next generation time (random interval between 12 and 48 hours)
      final random = dart_math.Random();
      final randomHours = 12 + random.nextInt(37); // 12 to 48 hours
      final nextTime = nowMs + (randomHours * 3600 * 1000);
      await prefs.setInt(nextGenKey, nextTime);

    } catch (e) {
      print('Error creating recommendation notifications: $e');
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

        final createdAt = shopData['postedAt'] as Timestamp? ?? Timestamp.now();
        // Check if notification already exists for this shop
        final existingNotification = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('type', isEqualTo: 'shop')
            .where('relatedId', isEqualTo: shopId)
            .get();

        if (existingNotification.docs.isEmpty) {
          await createShopNotification(userId, shopId, shopName, imageUrl, createdAt, isAlert: isTasteMatch);
        }
      }
    } catch (e) {
      print('Error checking for new shops: $e');
    }
  }

  // Check for new events and create notifications
  // Check for new events and create notifications
  Future<void> _checkForNewEvents(String userId, Timestamp? lastCheck,
      QuerySnapshot<Map<String, dynamic>> verifiedShops) async {
    try {
      for (final shopDoc in verifiedShops.docs) {
        final shopId = shopDoc.id;
        final shopName = shopDoc.data()['name'] ?? 'Café';
        final shopImageUrl = shopDoc.data()['logoUrl'];

        Query eventsQuery = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('events')
            .where('status', isEqualTo: 'approved')
            .where('createdAt', isGreaterThan: lastCheck);

        final eventsSnapshot = await eventsQuery.get();

        for (final eventDoc in eventsSnapshot.docs) {
          final eventData = eventDoc.data() as Map<String, dynamic>?;
          if (eventData == null) continue;
          final eventId = eventDoc.id;
          final eventTitle = eventData['title'] ?? 'New Event';
          final imageUrl = eventData['imageUrl'] ?? shopImageUrl;
          final createdAt = eventData['createdAt'] as Timestamp? ?? Timestamp.now();

          // Check if notification already exists
          final existingNotification = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('type', isEqualTo: 'event')
              .where('relatedId', isEqualTo: eventId)
              .get();

          if (existingNotification.docs.isEmpty) {
            await createEventNotification(userId, eventId, eventTitle, imageUrl, createdAt);
          }
        }
      }
    } catch (e) {
      print('Error checking for new events: $e');
    }
  }

  // Create a notification for a business owner when a user applies for a job
  Future<void> createApplicationNotificationForBusiness(
      String businessId,
      String applicationId,
      String applicantName,
      String jobId,
      String jobTitle,
      Timestamp appliedAt,
      String shopId) async {
    
    final notification = NotificationModel(
      id: 'job_app_business_$applicationId',
      title: 'New Job Application!',
      body: '$applicantName just applied for $jobTitle. Tap to view their application.',
      type: 'business_application',
      relatedId: applicationId,
      createdAt: appliedAt.toDate(),
      isRead: false,
      recipientRole: 'business',
      metadata: {
        'businessId': businessId,
        'jobId': jobId,
        'applicationId': applicationId,
        'shopId': shopId,
      },
    );

    await _saveNotification(businessId, notification);
  }

  // Create a notification for a new chat message
  Future<void> createChatNotification(
      String recipientId,
      String senderName,
      String messageText,
      String chatId,
      String jobId,
      String jobTitle,
      String shopId,
      String posterId,
      String applicantId,
      String applicationId,
      String messageId,
      Timestamp sentAt,
      {required String recipientRole}) async {

    final displayBody = messageText.length > 60 
        ? '${messageText.substring(0, 57)}...' 
        : messageText;
        
    final notification = NotificationModel(
      id: 'chat_msg_$messageId',
      title: 'New Message from $senderName',
      body: displayBody,
      type: 'chat',
      relatedId: chatId,
      createdAt: sentAt.toDate(),
      isRead: false,
      isAlert: true,
      priority: 'high',
      recipientRole: recipientRole,
      metadata: {
        'userId': recipientId,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'shopId': shopId,
        'posterId': posterId,
        'applicantId': applicantId,
        'applicationId': applicationId,
        'conversationId': chatId,
        'messageId': messageId,
      },
    );

    await _saveNotification(recipientId, notification);
  }

  // Create a notification for a new review
  Future<void> createReviewNotification(
    String ownerId,
    String reviewId,
    String shopId,
    String shopName,
    String reviewerName,
    String reviewText,
    double rating,
    String? imageUrl,
    Timestamp createdAt,
  ) async {
    // Truncate review text for the body
    final displayBody = reviewText.length > 60 
        ? '${reviewText.substring(0, 57)}...' 
        : reviewText;

    final notification = NotificationModel(
      id: 'review_${reviewId}_$ownerId',
      title: '⭐ New Review for $shopName',
      body: '$reviewerName left a review: "$displayBody"',
      type: 'review',
      relatedId: shopId, // Route back to the cafe
      imageUrl: imageUrl,
      createdAt: createdAt.toDate(),
      isRead: false,
      recipientRole: 'business',
      metadata: {
        'reviewId': reviewId,
        'shopId': shopId,
        'rating': rating,
      },
    );

    await _saveNotification(ownerId, notification);
  }

  // Create a notification for a business owner when someone joins their event
  Future<void> createEventParticipationNotification(
      String ownerId,
      String eventId,
      String eventTitle,
      String shopId,
      String participantName,
      String participantId,
      Timestamp joinedAt) async {
    
    final notification = NotificationModel(
      id: 'event_join_${eventId}_$participantId',
      title: '🎉 New Participant!',
      body: '$participantName is going to $eventTitle',
      type: 'event_participation',
      relatedId: eventId,
      createdAt: joinedAt.toDate(),
      isRead: false,
      recipientRole: 'business',
      metadata: {
        'ownerId': ownerId,
        'eventId': eventId,
        'shopId': shopId,
        'participantId': participantId,
      },
    );

    await _saveNotification(ownerId, notification);
  }
}
