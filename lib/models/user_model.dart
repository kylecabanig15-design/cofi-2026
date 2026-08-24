import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  final bool emailNotifications;
  final bool eventNotifications;
  final bool jobNotifications;
  final bool promoNotifications;

  const NotificationPreferences({
    this.emailNotifications = true,
    this.eventNotifications = true,
    this.jobNotifications = true,
    this.promoNotifications = true,
  });

  factory NotificationPreferences.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const NotificationPreferences();
    return NotificationPreferences(
      emailNotifications: data['emailNotifications'] as bool? ?? true,
      eventNotifications: data['eventNotifications'] as bool? ?? true,
      jobNotifications: data['jobNotifications'] as bool? ?? true,
      promoNotifications: data['promoNotifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'emailNotifications': emailNotifications,
        'eventNotifications': eventNotifications,
        'jobNotifications': jobNotifications,
        'promoNotifications': promoNotifications,
      };
}

/// Firestore `users` document. Named AppUser to avoid clashing with
/// FirebaseAuth's User.
class AppUser {
  final String uid;

  /// Reads displayName with fallback to legacy `name`.
  final String name;
  final String birthday;
  final String? photoUrl;
  final String email;
  final String accountType;
  final bool isAdmin;
  final bool commitment;
  final List<String> interests;
  final List<String> bookmarks;
  final List<String> visited;
  final String address;
  final NotificationPreferences notificationPreferences;
  final bool notificationsEnabled;
  final bool applicantAlertsEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  AppUser({
    required this.uid,
    required this.name,
    this.birthday = '',
    this.photoUrl,
    this.email = '',
    this.accountType = 'user',
    this.isAdmin = false,
    this.commitment = false,
    this.interests = const [],
    this.bookmarks = const [],
    this.visited = const [],
    this.address = '',
    this.notificationPreferences = const NotificationPreferences(),
    this.notificationsEnabled = true,
    this.applicantAlertsEnabled = true,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  bool get isBusiness => accountType == 'business';

  static bool _asBool(dynamic value, [bool fallback = false]) =>
      value is bool ? value : fallback;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: data['uid'] as String? ?? uid,
      name: data['displayName'] as String? ?? data['name'] as String? ?? '',
      birthday: data['birthday'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      email: data['email'] as String? ?? '',
      accountType: data['accountType'] as String? ?? 'user',
      isAdmin: _asBool(data['isAdmin']),
      commitment: _asBool(data['commitment']),
      interests: (data['interests'] as List?)?.cast<String>() ?? const [],
      bookmarks: (data['bookmarks'] as List?)?.cast<String>() ?? const [],
      visited: (data['visited'] as List?)?.cast<String>() ?? const [],
      address: data['address'] as String? ?? '',
      notificationPreferences: NotificationPreferences.fromFirestore(
          data['notificationPreferences'] as Map<String, dynamic>?),
      notificationsEnabled: _asBool(data['notificationsEnabled'], true),
      applicantAlertsEnabled:
          _asBool(data['applicantAlertsEnabled'], true),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'displayName': name,
        'name': name,
        'birthday': birthday,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'email': email,
        'accountType': accountType,
        'isAdmin': isAdmin,
        'commitment': commitment,
        'interests': interests,
        'bookmarks': bookmarks,
        'visited': visited,
        'address': address,
        'notificationPreferences': notificationPreferences.toFirestore(),
        'notificationsEnabled': notificationsEnabled,
        'applicantAlertsEnabled': applicantAlertsEnabled,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        if (lastLoginAt != null)
          'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
      };
}
