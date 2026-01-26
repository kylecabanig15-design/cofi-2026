import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/post_job_bottom_sheet.dart';
import 'package:cofi/features/jobs/job_details_screen.dart';

class MyJobsBottomSheet extends StatelessWidget {
  const MyJobsBottomSheet({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextWidget(
                    text: 'My Jobs',
                    fontSize: 18,
                    color: Colors.white,
                    isBold: true,
                  ),
                  Expanded(child: const SizedBox(width: 16)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      PostJobBottomSheet.show(context, shopId: shopId);
                    },
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
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
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextWidget(
                              text: 'No active jobs',
                              fontSize: 16,
                              color: Colors.white,
                              isBold: true,
                            ),
                            const SizedBox(height: 8),
                            TextWidget(
                              text: 'Tap + to post your first job',
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: activeJobs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final jobDoc = activeJobs[index];
                        final jobId = jobDoc.id;
                        final data = jobDoc.data();

                        // Get status directly from job data
                        String status =
                            (data['status'] as String?) ?? 'pending';
                        final statusLower = status.toLowerCase();

                        final title = (data['title'] as String?) ?? 'Untitled';
                        final statusColor =
                            statusLower == 'approved' || statusLower == 'active'
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
            color: isPending ? Colors.grey[900] : Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Job Icon
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_cafe,
                          color: Colors.red,
                          size: 12,
                        ),
                      ),
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
      builder: (context) => MyJobsBottomSheet(shopId: shopId),
    );
  }
}
