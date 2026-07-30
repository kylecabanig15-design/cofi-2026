import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cofi/models/notification_model.dart';
import 'package:cofi/utils/globals.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();
  static const String _unreadCountKey = 'unread_notifications_count';
  
  static const double _soundThreshold = 0.7;
  
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    await GetStorage.init();
    await initializeDateFormatting('en_PH', null);
    
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

    if (await Permission.notification.isDenied) {
      print('🔔 [NOTIFICATIONS] Requesting permission...');
      await Permission.notification.request();
    }
    
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

  // ========================================================================
  // SETTINGS CHECK (NEW)
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
          
          notifications.sort((a, b) {
            if (a.isAlert != b.isAlert) return a.isAlert ? -1 : 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          
          return notifications;
        });
  }

  Future<void> createEventNotification(
      String eventId, String eventTitle, String? imageUrl, Timestamp createdAt, String shopId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // This is for users. Should notify users that an event was created.
    // Wait, createEventNotification is called for EACH user. So recipientId is the argument we need!
  }
}
