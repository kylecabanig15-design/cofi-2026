import 'package:cloud_firestore/cloud_firestore.dart';

/// Accepts Timestamp, ISO String, DateTime or null (→ null).
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

class VisitLog {
  final String id;
  final String userId;
  final String userEmail;
  final String note;
  final List<String> tags;
  final DateTime createdAt;

  VisitLog({
    required this.id,
    required this.userId,
    this.userEmail = '',
    this.note = '',
    this.tags = const [],
    required this.createdAt,
  });

  factory VisitLog.fromFirestore(Map<String, dynamic> data, String id) {
    return VisitLog(
      id: id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      note: data['note'] as String? ?? '',
      tags: (data['tags'] as List?)?.cast<String>() ?? const [],
      createdAt: _parseDate(data['createdAt']) ??
          // Epoch placeholder so missing dates sort to the bottom instead
          // of being faked as "today"; never rendered directly in the UI.
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'userEmail': userEmail,
        'note': note,
        'tags': tags,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
