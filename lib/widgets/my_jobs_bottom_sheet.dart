import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/post_job_bottom_sheet.dart';
import 'package:cofi/features/jobs/job_details_screen.dart';
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';

class MyJobsBottomSheet extends StatelessWidget {
  const MyJobsBottomSheet({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.canvas,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            BusinessSheetHeader(
              title: 'Hiring board',
              subtitle: 'Open roles and approval status in one place',
              icon: Icons.work_outline_rounded,
              action: IconButton.filled(
                tooltip: 'Create job',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  PostJobBottomSheet.show(context, shopId: shopId);
                },
                icon: const Icon(Icons.add_rounded),
              ),
            ),

            // Jobs List
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .collection('jobs')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextWidget(
                          text: 'Failed to load jobs',
                          fontSize: 14,
                          color: Colors.red,
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];

                    // Sort by createdAt descending
                    docs.sort((a, b) {
                      final aDate =
                          (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                              DateTime(2000);
                      final bDate =
                          (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                              DateTime(2000);
                      return bDate.compareTo(aDate);
                    });

                    // Filter to only show non-archived jobs
                    final activeJobs = docs.where((doc) {
                      final job = doc.data();
                      return job['isArchived'] != true;
                    }).toList();

                    if (activeJobs.isEmpty) {
                      return const BusinessEmptyState(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'No roles are open',
                        message:
                            'When your team needs someone new, create a focused job post here.',
                      );
                    }
                    final pendingCount = activeJobs
                        .where((doc) =>
                            (doc.data()['status'] ?? 'pending') == 'pending')
                        .length;
                    final pausedCount = activeJobs
                        .where((doc) => doc.data()['isPaused'] == true)
                        .length;
                    return Column(
                      children: [
                        BusinessMetricsStrip(
                          items: [
                            BusinessMetricData(
                                '${activeJobs.length}', 'Open roles'),
                            BusinessMetricData('$pendingCount', 'In review'),
                            BusinessMetricData('$pausedCount', 'Paused'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            itemCount: activeJobs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final jobDoc = activeJobs[index];
                              final jobId = jobDoc.id;
                              final data = jobDoc.data();

                              // Get status directly from job data
                              String status =
                                  (data['status'] as String?) ?? 'pending';
                              final statusLower = status.toLowerCase();

                              final title =
                                  (data['title'] as String?) ?? 'Untitled';
                              final statusColor = statusLower == 'approved' ||
                                      statusLower == 'active'
                                  ? Colors.green
                                  : statusLower == 'closed'
                                      ? Colors.grey
                                      : statusLower == 'rejected'
                                          ? Colors.red
                                          : Colors.orange;

                              String displayStatus = statusLower == 'pending'
                                  ? 'Pending for approval'
                                  : statusLower == 'active'
                                      ? 'Active'
                                      : statusLower == 'closed'
                                          ? 'Closed'
                                          : status.isEmpty
                                              ? 'Unknown'
                                              : status[0].toUpperCase() +
                                                  status.substring(1);

                              return _buildJobItem(
                                context: context,
                                jobId: jobId,
                                jobData: data,
                                title: title,
                                status: displayStatus,
                                statusColor: statusColor,
                                isPaused: (data['isPaused'] as bool?) ?? false,
                                isPending: statusLower == 'pending',
                                isClosed: statusLower == 'closed',
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobItem({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> jobData,
    required String title,
    required String status,
    required Color statusColor,
    required bool isPaused,
    required bool isPending,
    required bool isClosed,
  }) {
    return GestureDetector(
      onTap: isPending
          ? null
          : () {
              // Navigate to job details screen
              final completeJobData = Map<String, dynamic>.from(jobData);
              completeJobData['id'] = jobId;
              completeJobData['shopId'] = shopId;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobDetailsScreen(
                    job: completeJobData,
                    shopId: shopId,
                  ),
                ),
              );
            },
      child: Opacity(
        opacity: isPending ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BusinessWorkspaceColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BusinessWorkspaceColors.line),
          ),
          child: Row(
            children: [
              // Job Icon
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 21,
                    ),
                  ),
                  // Paused badge
                  if (isPaused)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Job Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextWidget(
                            text: title,
                            fontSize: 16,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                        if (isClosed)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const TextWidget(
                              text: 'CLOSED',
                              fontSize: 10,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                        if (isPaused)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const TextWidget(
                              text: 'PAUSED',
                              fontSize: 10,
                              color: Colors.white,
                              isBold: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text: status,
                      fontSize: 14,
                      color: statusColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: BusinessWorkspaceColors.surfaceRaised,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending
                      ? Icons.hourglass_top_rounded
                      : Icons.arrow_forward_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void show(BuildContext context, {required String shopId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BusinessWorkspaceTheme(
        accentColor: Colors.tealAccent,
        child: MyJobsBottomSheet(shopId: shopId),
      ),
    );
  }
}
