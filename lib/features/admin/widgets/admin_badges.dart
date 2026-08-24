import 'package:flutter/material.dart';

Widget buildAdminSourceBadge(Map<String, dynamic> data) {
  final submissionType = data['submissionType'] as String? ?? 'community';
  final ownerId = data['ownerId'] as String?;
  final isBusiness =
      submissionType == 'business' || (ownerId != null && ownerId.isNotEmpty);

  final color = isBusiness ? Colors.blue : Colors.amber;
  final label = isBusiness ? 'BUSINESS CLAIMED' : 'COMMUNITY ADDED';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
      ),
    ),
  );
}

Widget buildAdminVisibilityBadge(bool isHidden, String approvalStatus) {
  if (approvalStatus != 'approved') return const SizedBox.shrink();

  final color = isHidden ? Colors.orange : Colors.green;
  final label = isHidden ? 'UNPUBLISHED' : 'PUBLISHED';
  final icon =
      isHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget buildAdminStatusIndicator(String status, bool isVerified) {
  Color color = status == 'approved' ? Colors.green : Colors.redAccent;
  IconData icon =
      status == 'approved' ? Icons.check_circle_rounded : Icons.block_flipped;

  return Row(
    children: [
      const SizedBox(width: 8),
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(
        status == 'approved' ? 'APPROVED' : status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    ],
  );
}

Widget buildAdminClaimStatusBadge(String status) {
  Color color;
  switch (status) {
    case 'approved':
      color = Colors.green;
      break;
    case 'rejected':
      color = Colors.redAccent;
      break;
    case 'awaiting_verification':
      color = Colors.blueAccent;
      break;
    default:
      color = Colors.orange;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );
}
