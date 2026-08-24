import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared visibility rule for Community and Explore event feeds.
///
/// Production events are written with status 'pending' by default, so
/// filtering must be exclusion-based (not approved-only) or every feed would
/// be empty. An event is visible unless it was rejected, paused, archived,
/// or marked private.
bool isVisibleEvent(CafeEvent e) =>
    e.status != 'rejected' && !e.isPaused && !e.isArchived && !e.isPrivate;

class EventParticipant {
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final DateTime? joinedAt;

  EventParticipant({
    required this.userId,
    this.userName = 'User',
    this.userPhotoUrl = '',
    this.joinedAt,
  });

  factory EventParticipant.fromFirestore(Map<String, dynamic> data) {
    return EventParticipant(
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? 'User',
      userPhotoUrl: data['userPhotoUrl'] as String? ?? '',
      joinedAt: _parseJoinedAt(data['joinedAt']),
    );
  }

  /// Accepts Timestamp, ISO String or null so one malformed participant doc
  /// cannot break parsing.
  static DateTime? _parseJoinedAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        if (joinedAt != null) 'joinedAt': Timestamp.fromDate(joinedAt!),
      };
}

class CafeEvent {
  final String id;
  final String title;
  final String address;
  final DateTime? startDate;
  final DateTime? endDate;
  final String about;
  final String email;
  final String link;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;

  /// One of: pending, approved, rejected.
  final String status;
  final int participantsCount;
  final String shopId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Legacy attribution field; not written by current app versions.
  final String? userId;
  final bool isPaused;
  final bool isArchived;
  final bool isPrivate;

  CafeEvent({
    required this.id,
    this.title = 'Event',
    this.address = '',
    this.startDate,
    this.endDate,
    this.about = '',
    this.email = '',
    this.link = '',
    this.imageUrls = const [],
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.participantsCount = 0,
    this.shopId = '',
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.isPaused = false,
    this.isArchived = false,
    this.isPrivate = false,
  });

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  factory CafeEvent.fromFirestore(Map<String, dynamic> data, String id) {
    return CafeEvent(
      id: id,
      title: data['title'] as String? ?? 'Event',
      address: data['address'] as String? ?? 'Address not specified',
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
      about: data['about'] as String? ?? '',
      email: data['email'] as String? ?? '',
      link: data['link'] as String? ?? '',
      imageUrls: [
        ...(data['imageUrls'] as List? ?? const []).whereType<String>(),
        if ((data['imageUrls'] as List? ?? const []).isEmpty &&
            data['imageUrl'] is String)
          data['imageUrl'] as String,
      ],
      latitude: data['latitude'] is num
          ? (data['latitude'] as num).toDouble()
          : null,
      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : null,
      status: data['status'] as String? ?? 'pending',
      participantsCount: data['participantsCount'] is num
          ? (data['participantsCount'] as num).toInt()
          : 0,
      shopId: data['shopId'] as String? ?? '',
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
      userId: data['userId'] as String?,
      isPaused: data['isPaused'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
      isPrivate: data['isPrivate'] as bool? ?? false,
    );
  }

  /// Legacy single-image field kept in sync for older clients.
  Map<String, dynamic> toFirestore() => {
        'title': title,
        'address': address,
        if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
        if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
        'about': about,
        'email': email,
        'link': link,
        'imageUrls': imageUrls,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'status': status,
        'participantsCount': participantsCount,
        'shopId': shopId,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        'isPaused': isPaused,
        'isArchived': isArchived,
        'isPrivate': isPrivate,
      };
}
