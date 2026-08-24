import 'package:cloud_firestore/cloud_firestore.dart';

class ShopContacts {
  final String instagram;
  final String facebook;
  final String tiktok;
  final String email;
  final String website;
  final String phone;

  const ShopContacts({
    this.instagram = '',
    this.facebook = '',
    this.tiktok = '',
    this.email = '',
    this.website = '',
    this.phone = '',
  });

  factory ShopContacts.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ShopContacts();
    return ShopContacts(
      instagram: data['instagram'] as String? ?? '',
      facebook: data['facebook'] as String? ?? '',
      tiktok: data['tiktok'] as String? ?? '',
      email: data['email'] as String? ?? '',
      website: data['website'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'instagram': instagram,
        'facebook': facebook,
        'tiktok': tiktok,
        'email': email,
        'website': website,
        'phone': phone,
      };
}

class ShopScheduleDay {
  final bool isOpen;
  final String open;
  final String close;

  const ShopScheduleDay({
    this.isOpen = false,
    this.open = '',
    this.close = '',
  });

  factory ShopScheduleDay.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return const ShopScheduleDay();
    return ShopScheduleDay(
      isOpen: data['isOpen'] as bool? ?? false,
      open: data['open'] as String? ?? '',
      close: data['close'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() =>
      {'isOpen': isOpen, 'open': open, 'close': close};
}

class Shop {
  final String id;
  final String name;
  final String address;
  final String about;
  final ShopContacts contacts;
  final Map<String, ShopScheduleDay> schedule;
  final String? logoUrl;
  final List<String> gallery;
  final List<String> menuPricePhotos;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final String? posterId;
  final DateTime postedAt;
  final num ratings;
  final int ratingCount;
  final bool isVerified;
  final String submissionType;

  /// One of: pending_approval, awaiting_verification, approved, rejected,
  /// archived.
  final String approvalStatus;
  final String? ownerId;
  final bool isHidden;

  Shop({
    required this.id,
    required this.name,
    this.address = '',
    this.about = '',
    this.contacts = const ShopContacts(),
    this.schedule = const {},
    this.logoUrl,
    this.gallery = const [],
    this.menuPricePhotos = const [],
    this.tags = const [],
    this.latitude,
    this.longitude,
    this.posterId,
    DateTime? postedAt,
    this.ratings = 0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.submissionType = 'community',
    this.approvalStatus = 'pending_approval',
    this.ownerId,
    this.isHidden = false,
  }) : postedAt = postedAt ?? DateTime(2000);

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return DateTime(2000);
  }

  factory Shop.fromFirestore(Map<String, dynamic> data, String id) {
    final lat = data['latitude'];
    final lng = data['longitude'];
    return Shop(
      id: id,
      name: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      about: data['about'] as String? ?? '',
      contacts:
          ShopContacts.fromFirestore(data['contacts'] as Map<String, dynamic>?),
      schedule: ((data['schedule'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(
              k, ShopScheduleDay.fromFirestore(v as Map<String, dynamic>?))),
      logoUrl: data['logoUrl'] as String?,
      gallery:
          (data['gallery'] as List?)?.cast<String>() ?? const [],
      menuPricePhotos:
          (data['menuPricePhotos'] as List?)?.cast<String>() ?? const [],
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      posterId: data['posterId'] is String ? data['posterId'] as String : null,
      postedAt: _parseDate(data['postedAt']),
      ratings: data['ratings'] as num? ?? 0,
      ratingCount: data['ratingCount'] as int? ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      submissionType: data['submissionType'] as String? ?? 'community',
      approvalStatus: data['approvalStatus'] as String? ?? 'pending_approval',
      ownerId: data['ownerId'] is String ? data['ownerId'] as String : null,
      isHidden: data['isHidden'] as bool? ?? false,
    );
  }

  /// Legacy attribution field written by older app versions.
  static String? legacyPostedByUid(Map<String, dynamic> data) {
    final postedBy = data['postedBy'];
    if (postedBy is String) return postedBy;
    if (postedBy is Map) return postedBy['uid'] as String?;
    return null;
  }

  /// Day keys as written by submit_shop_screen.dart: lowercase full names.
  static const List<String> _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  bool get isOpenNow {
    final now = DateTime.now();
    final dayKey = _dayKeys[now.weekday - 1];
    final day = schedule[dayKey] ?? schedule[dayKey.substring(0, 3)];
    if (day == null || !day.isOpen) return false;
    int toMinutes(String hhmm) {
      final parts = hhmm.split(':');
      if (parts.length != 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    final om = toMinutes(day.open.isEmpty ? '00:00' : day.open);
    // Empty close time means end of day.
    final cm = toMinutes(day.close.isEmpty ? '23:59' : day.close);
    final nm = now.hour * 60 + now.minute;
    // Overnight hours (close < open, e.g. 18:00–01:00): the café is open
    // when "now" is after open OR before close on the next calendar day.
    if (cm <= om) {
      return nm >= om || nm < cm;
    }
    return nm >= om && nm < cm;
  }

  bool get isOwnedByBusiness => ownerId != null && ownerId!.isNotEmpty;

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'address': address,
        'about': about,
        'contacts': contacts.toFirestore(),
        'schedule':
            schedule.map((k, v) => MapEntry(k, v.toFirestore())),
        if (logoUrl != null) 'logoUrl': logoUrl,
        'gallery': gallery,
        'menuPricePhotos': menuPricePhotos,
        'tags': tags,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (posterId != null) 'posterId': posterId,
        'ratings': ratings,
        'ratingCount': ratingCount,
        'isVerified': isVerified,
        'submissionType': submissionType,
        'approvalStatus': approvalStatus,
        if (ownerId != null) 'ownerId': ownerId,
        'isHidden': isHidden,
      };
}
