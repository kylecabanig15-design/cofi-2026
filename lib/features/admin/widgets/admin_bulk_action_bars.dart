import 'package:flutter/material.dart';

class AdminBulkActionBar extends StatelessWidget {
  final int totalCount;
  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final VoidCallback onAction;
  final String actionLabel;
  final IconData actionIcon;
  final Color actionColor;

  const AdminBulkActionBar({
    super.key,
    required this.totalCount,
    required this.selectedCount,
    required this.isAllSelected,
    required this.onSelectAll,
    required this.onCancel,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: actionColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: actionColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          GestureDetector(
            onTap: onSelectAll,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isAllSelected ? actionColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAllSelected ? actionColor : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: isAllSelected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select All',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Count Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$selectedCount selected',
              style: TextStyle(
                color: actionColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Cancel Button
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
          // Action Button
          ElevatedButton.icon(
            onPressed: selectedCount > 0 ? onAction : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedCount > 0 ? actionColor : Colors.grey[800],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
            ),
            icon: Icon(actionIcon, size: 14),
            label: Text(
              actionLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDualActionBar extends StatelessWidget {
  final int totalCount;
  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onCancel;
  final String action1Label;
  final IconData action1Icon;
  final Color action1Color;
  final VoidCallback onAction1;
  final String action2Label;
  final IconData action2Icon;
  final Color action2Color;
  final VoidCallback onAction2;

  const AdminDualActionBar({
    super.key,
    required this.totalCount,
    required this.selectedCount,
    required this.isAllSelected,
    required this.onSelectAll,
    required this.onCancel,
    required this.action1Label,
    required this.action1Icon,
    required this.action1Color,
    required this.onAction1,
    required this.action2Label,
    required this.action2Icon,
    required this.action2Color,
    required this.onAction2,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Select All Checkbox
          GestureDetector(
            onTap: onSelectAll,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isAllSelected ? Colors.white54 : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAllSelected ? Colors.white54 : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: isAllSelected
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  '$selectedCount / $totalCount',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Cancel Button
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          // Action 1 Button
          ElevatedButton.icon(
            onPressed: selectedCount > 0 ? onAction1 : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedCount > 0 ? action1Color : Colors.grey[800],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
            ),
            icon: Icon(action1Icon, size: 13),
            label: Text(action1Label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          // Action 2 Button
          ElevatedButton.icon(
            onPressed: selectedCount > 0 ? onAction2 : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedCount > 0 ? action2Color : Colors.grey[800],
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
            ),
            icon: Icon(action2Icon, size: 13),
            label: Text(action2Label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
