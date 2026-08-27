import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';

class JobArchivesScreen extends StatefulWidget {
  final String shopId;

  const JobArchivesScreen({required this.shopId, super.key});

  @override
  State<JobArchivesScreen> createState() => _JobArchivesScreenState();
}

class _JobArchivesScreenState extends State<JobArchivesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BusinessWorkspaceColors.canvas,
      appBar: AppBar(
        backgroundColor: BusinessWorkspaceColors.canvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Past openings',
          fontSize: 18,
          color: BusinessWorkspaceColors.paper,
          isBold: true,
        ),
      ),
      body: BusinessWorkspaceTheme(
        accentColor: Colors.blueGrey,
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(widget.shopId)
                .collection('jobs')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: TextWidget(
                    text: 'Error loading archives',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                );
              }

              final allJobs = snapshot.data?.docs ?? [];

              // Filter to only show archived jobs
              final archivedJobs = allJobs.where((doc) {
                final job = doc.data();
                return job['isArchived'] == true;
              }).toList();

              if (archivedJobs.isEmpty) {
                return const BusinessEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No past openings',
                  message:
                      'Closed and archived roles will stay here for your records.',
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: archivedJobs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const BusinessPageIntro(
                      eyebrow: 'Hiring ledger',
                      title: 'Past openings',
                      description:
                          'A tidy record of roles your café has already closed.',
                      icon: Icons.work_history_rounded,
                    );
                  }
                  final jobDoc = archivedJobs[index - 1];
                  final jobId = jobDoc.id;
                  final job = jobDoc.data();
                  return _buildArchivedJobCard(
                    jobId: jobId,
                    job: job,
                    onDelete: () => _deleteJob(jobId),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedJobCard({
    required String jobId,
    required Map<String, dynamic> job,
    required VoidCallback onDelete,
  }) {
    // Legacy docs may hold non-string values here — coerce safely instead
    // of hard-casting, which would throw.
    String asString(dynamic v, String fallback) =>
        v == null ? fallback : v.toString();
    final title = asString(job['title'], 'Job');
    final type = asString(job['type'], '');
    final rate = asString(job['rate'], 'TBD');
    final paymentType = asString(job['paymentType'], 'Per Hour');

    return Container(
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessWorkspaceColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text: type,
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextWidget(
                  text: 'Archived',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Rate and Payment Type
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: 'Rate',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    TextWidget(
                      text: '₱ $rate',
                      fontSize: 14,
                      color: Colors.white,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: 'Payment Type',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    TextWidget(
                      text: paymentType,
                      fontSize: 14,
                      color: Colors.white,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Delete Button (only button in archives)
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side:
                    BorderSide(color: Colors.redAccent.withValues(alpha: .35)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete permanently'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJob(String jobId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await CustomDialog.confirm(
      context: context,
      title: 'Delete archived job?',
      message: 'This permanently removes the opening and its archive record.',
      confirmText: 'Delete job',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('jobs')
          .doc(jobId)
          .delete();

      CustomToast.showFromMessenger(
        messenger,
        'The archived job was permanently removed.',
        type: ToastType.success,
        title: 'Job deleted',
      );
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'We could not delete the job. Please try again.',
        type: ToastType.error,
        title: 'Delete failed',
      );
    }
  }
}
