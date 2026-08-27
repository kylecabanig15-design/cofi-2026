import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/post_promotion_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';

class MyPromotionsBottomSheet extends StatelessWidget {
  const MyPromotionsBottomSheet({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  static Future<void> show(BuildContext context,
      {required String shopId, required String shopName}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MyPromotionsBottomSheet(
        shopId: shopId,
        shopName: shopName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BusinessSheetShell(
      accentColor: Colors.deepOrangeAccent,
      heightFactor: .9,
      child: Column(
        children: [
          BusinessSheetHeader(
            title: 'Offer shelf',
            subtitle: 'Draft, publish, or pause reasons to visit',
            icon: Icons.local_offer_outlined,
            action: IconButton.filled(
              tooltip: 'Create offer',
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
              ),
              onPressed: () => PostPromotionBottomSheet.show(context,
                  shopId: shopId, shopName: shopName),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .collection('promotions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primary));
                }
                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return BusinessEmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'Your offer shelf is empty',
                    message:
                        'Create one clear, time-limited reason for customers to stop by.',
                    action: FilledButton.icon(
                      onPressed: () => PostPromotionBottomSheet.show(context,
                          shopId: shopId, shopName: shopName),
                      icon: const Icon(Icons.add),
                      label: const Text('Create offer'),
                    ),
                  );
                }
                final published = docs
                    .where((doc) => doc.data()['status'] == 'published')
                    .length;
                final drafts =
                    docs.where((doc) => doc.data()['status'] == 'draft').length;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: docs.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return BusinessMetricsStrip(
                        items: [
                          BusinessMetricData('${docs.length}', 'All offers'),
                          BusinessMetricData('$published', 'Published'),
                          BusinessMetricData('$drafts', 'Drafts'),
                        ],
                      );
                    }
                    final doc = docs[index - 1];
                    final data = doc.data();
                    return _PromotionManagementCard(
                      data: data,
                      onEdit: () => PostPromotionBottomSheet.show(context,
                          shopId: shopId,
                          shopName: shopName,
                          promotionId: doc.id,
                          initialData: data),
                      onToggle: () => doc.reference.update({
                        'status': data['status'] == 'published'
                            ? 'paused'
                            : 'published',
                        'updatedAt': FieldValue.serverTimestamp(),
                      }),
                      onDelete: () => _delete(context, doc.reference),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, DocumentReference<Map<String, dynamic>> ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Delete offer?',
      message:
          'This offer will be permanently removed from your shelf and Community.',
      confirmText: 'Delete offer',
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.delete();
      CustomToast.showFromMessenger(
        messenger,
        'The offer was permanently removed.',
        type: ToastType.success,
        title: 'Offer deleted',
      );
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'We could not delete the offer. Please try again.',
        type: ToastType.error,
        title: 'Delete failed',
      );
    }
  }
}

class _PromotionManagementCard extends StatelessWidget {
  const _PromotionManagementCard({
    required this.data,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'draft').toString();
    final end = data['endDate'] is Timestamp
        ? (data['endDate'] as Timestamp).toDate()
        : null;
    final expired = end != null && !end.isAfter(DateTime.now());
    final displayStatus = expired ? 'expired' : status;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((data['title'] ?? 'Offer').toString(),
                    style: const TextStyle(
                        color: BusinessWorkspaceColors.paper,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              Text(displayStatus.toUpperCase(),
                  style: TextStyle(
                      color: displayStatus == 'published'
                          ? Colors.greenAccent
                          : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text((data['offer'] ?? '').toString(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700)),
          if (end != null) ...[
            const SizedBox(height: 5),
            Text('Ends ${DateFormat('MMM d, y').format(end)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                ),
              ),
              if (!expired) const SizedBox(width: 10),
              if (!expired)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onToggle,
                    icon: Icon(
                        status == 'published'
                            ? Icons.pause_rounded
                            : Icons.publish_rounded,
                        size: 17),
                    label: Text(status == 'published' ? 'Pause' : 'Publish'),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                  tooltip: 'Delete offer',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 20)),
            ],
          ),
        ],
      ),
    );
  }
}
