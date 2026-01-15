import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/text_widget.dart';

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: TextWidget(
          text: 'Job Archives',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
      ),
      body: SafeArea(
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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.archive, color: Colors.grey, size: 48),
                    const SizedBox(height: 16),
                    TextWidget(
                      text: 'No archived jobs',
                      fontSize: 16,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    TextWidget(
                      text: 'Archived jobs will appear here',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: archivedJobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final jobDoc = archivedJobs[index];
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
    );
  }

  Widget _buildArchivedJobCard({
    required String jobId,
    required Map<String, dynamic> job,
    required VoidCallback onDelete,
  }) {
    final title = (job['title'] ?? 'Job') as String;
    final type = (job['type'] ?? '') as String;
    final rate = (job['rate'] ?? 'TBD') as String;
    final paymentType = (job['paymentType'] ?? 'Per Hour') as String;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
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
            child: ElevatedButton.icon(
              onPressed: onDelete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.delete, size: 18),
              label: TextWidget(
                text: 'Delete',
                fontSize: 14,
                color: Colors.white,
                isBold: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteJob(String jobId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Job', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to permanently delete this job?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('jobs')
          .doc(jobId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
