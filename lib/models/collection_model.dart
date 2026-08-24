import 'package:cloud_firestore/cloud_firestore.dart';

class CollectionItem {
  final String id;

  /// Item document ids are the shopId in most write paths.
  final String shopId;
  final DateTime? addedAt;

  CollectionItem({
    required this.id,
    this.shopId = '',
    this.addedAt,
  });

  factory CollectionItem.fromFirestore(Map<String, dynamic> data, String id) {
    return CollectionItem(
      id: id,
      shopId: data['shopId'] as String? ?? id,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'shopId': shopId,
        if (addedAt != null) 'addedAt': Timestamp.fromDate(addedAt!),
      };
}

class CafeCollection {
  final String id;
  final String userId;

  /// Firestore stores `name`; some readers fall back to legacy `title`.
  final String name;
  final String description;

  /// One of: custom, filter.
  final String type;

  /// Filter-type collections match shops whose tags include any of these.
  final List<String> filterTags;

  /// True when the list is only visible to its owner. Note: the
  /// sharedCollections mirror intentionally stores the inverted value.
  final bool isPrivate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CafeCollection({
    required this.id,
    this.userId = '',
    this.name = '',
    this.description = '',
    this.type = 'custom',
    this.filterTags = const [],
    this.isPrivate = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CafeCollection.fromFirestore(Map<String, dynamic> data, String id) {
    final filters = data['filters'] as Map<String, dynamic>?;
    return CafeCollection(
      id: id,
      userId: data['userId'] as String? ?? '',
      name: data['name'] as String? ?? data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: data['type'] as String? ?? 'filter',
      filterTags:
          ((filters?['tags'] as List?) ?? const []).whereType<String>().toList(),
      isPrivate: data['isPrivate'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        if (userId.isNotEmpty) 'userId': userId,
        'name': name,
        'description': description,
        'type': type,
        if (type == 'filter') 'filters': {'tags': filterTags},
        'isPrivate': isPrivate,
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}

class SharedCollection {
  final String id;
  final String userId;
  final String listId;
  final String title;
  final String sharedBy;
  final DateTime? sharedAt;
  final int shopCount;
  final bool isPrivate;
  final List<String> previewLogos;

  SharedCollection({
    required this.id,
    this.userId = '',
    this.listId = '',
    this.title = '',
    this.sharedBy = '',
    this.sharedAt,
    this.shopCount = 0,
    this.isPrivate = false,
    this.previewLogos = const [],
  });

  factory SharedCollection.fromFirestore(
      Map<String, dynamic> data, String id) {
    return SharedCollection(
      id: id,
      userId: data['userId'] as String? ?? '',
      listId: data['listId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      sharedBy: data['sharedBy'] as String? ?? '',
      sharedAt: (data['sharedAt'] as Timestamp?)?.toDate(),
      shopCount: data['shopCount'] as int? ?? 0,
      isPrivate: data['isPrivate'] as bool? ?? false,
      previewLogos:
          (data['previewLogos'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        if (userId.isNotEmpty) 'userId': userId,
        if (listId.isNotEmpty) 'listId': listId,
        'title': title,
        'sharedBy': sharedBy,
        if (sharedAt != null) 'sharedAt': Timestamp.fromDate(sharedAt!),
        'shopCount': shopCount,
        'isPrivate': isPrivate,
        'previewLogos': previewLogos,
      };
}
