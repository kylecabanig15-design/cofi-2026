import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';

class AdminStatSummary extends StatelessWidget {
  final String label;
  final dynamic status;
  final Color color;
  final IconData icon;

  const AdminStatSummary({
    super.key,
    required this.label,
    required this.status,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final collection = label == 'Shops' ? 'shops' : 'shop_claims';
    final field = label == 'Shops' ? 'approvalStatus' : 'status';
    Query query = FirebaseFirestore.instance.collection(collection);
    if (status is String) {
      query = query.where(field, isEqualTo: status);
    } else if (status is List)
      query = query.where(field, whereIn: status as List<Object?>);

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextWidget(
                    text: count.toString(),
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true),
                TextWidget(
                    text: 'Pending $label',
                    fontSize: 11,
                    color: Colors.white54),
              ]),
            ]),
          );
        },
      ),
    );
  }
}
