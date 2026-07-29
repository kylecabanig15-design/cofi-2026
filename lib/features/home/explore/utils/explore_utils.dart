import 'package:flutter/material.dart';

class ExploreUtils {
  static String ratingText(dynamic ratings, dynamic ratingCount) {
    final num r = (ratings is num) ? ratings : 0;
    final num c = (ratingCount is num) ? ratingCount : 0;
    final display = (c > 0) ? (r.toDouble()).toStringAsFixed(1) : '0.0';
    return '$display (${c.toInt()})';
  }

  static String hoursFromSchedule(Map<String, dynamic> schedule) {
    final key = weekdayKey(DateTime.now().weekday);
    final day = getMapValue(schedule[key] ?? {});
    final isOpen = (day['isOpen'] ?? false) == true;
    final open = (day['open'] ?? '') as String?;
    final close = (day['close'] ?? '') as String?;
    if (isOpen && (open?.isNotEmpty ?? false) && (close?.isNotEmpty ?? false)) {
      return '${to12h(open ?? '')} - ${to12h(close ?? '')}';
    }
    return 'Closed today';
  }

  static bool isOpenTodayFromSchedule(Map<String, dynamic> schedule) {
    final key = weekdayKey(DateTime.now().weekday);
    final dayObj = schedule[key];
    final day = (dayObj is Map) ? Map<String, dynamic>.from(dayObj) : <String, dynamic>{};
    return (day['isOpen'] ?? false) == true;
  }

  static bool isOpenNowFromSchedule(Map<String, dynamic> schedule) {
    final key = weekdayKey(DateTime.now().weekday);
    final dayObj = schedule[key];
    final day = (dayObj is Map) ? Map<String, dynamic>.from(dayObj) : <String, dynamic>{};
    if ((day['isOpen'] ?? false) != true) return false;
    final open = (day['open'] ?? '') as String;
    final close = (day['close'] ?? '') as String;
    if (open.isEmpty || close.isEmpty) return false;
    int om = _toMinutes(open);
    int cm = _toMinutes(close);
    final now = DateTime.now();
    int nm = now.hour * 60 + now.minute;
    if (cm <= om) {
      return nm >= om || nm < cm;
    }
    return nm >= om && nm < cm;
  }

  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String to12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    int h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final mm = m.toString().padLeft(2, '0');
    return '$h:$mm $suffix';
  }

  static String weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'monday';
      case DateTime.tuesday: return 'tuesday';
      case DateTime.wednesday: return 'wednesday';
      case DateTime.thursday: return 'thursday';
      case DateTime.friday: return 'friday';
      case DateTime.saturday: return 'saturday';
      case DateTime.sunday:
      default: return 'sunday';
    }
  }

  static String getAddressAsString(dynamic addressData) {
    if (addressData == null) return '';
    if (addressData is String) return addressData;
    if (addressData is Map) {
      final map = addressData as Map<String, dynamic>;
      return (map['city'] as String?) ?? (map['address'] as String?) ?? '';
    }
    return '';
  }

  static List<String> getGalleryList(dynamic galleryData) {
    if (galleryData is List) {
      return galleryData.map((e) => e.toString()).toList();
    }
    return [];
  }

  static Map<String, dynamic> getMapValue(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
  
  static Map<String, dynamic> getScheduleAsMap(dynamic scheduleData) {
    if (scheduleData is Map) {
      return Map<String, dynamic>.from(scheduleData);
    }
    return {};
  }
}
