import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cofi/features/jobs/job_chat_screen.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'dart:ui';

class JobApplicationsBottomSheet extends StatefulWidget {
  final String shopId;
  const JobApplicationsBottomSheet({super.key, required this.shopId});

  @override
  State<JobApplicationsBottomSheet> createState() => _JobApplicationsBottomSheetState();
}

class _JobApplicationsBottomSheetState extends State<JobApplicationsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.work_history_rounded, color: primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    TextWidget(
                      text: 'Applications',
                      fontSize: 24,
                      color: Colors.white,
                      isBold: true,
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white12, height: 1),

          // Applications list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(widget.shopId)
                  .collection('jobs')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: TextWidget(
                      text: 'Error loading applications',
                      fontSize: 16,
                      color: Colors.redAccent,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                bool hasAnyApplication = false;
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  if ((data['applications'] as List?)?.isNotEmpty ?? false) {
                    hasAnyApplication = true;
                    break;
                  }
                }

                if (!hasAnyApplication) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final jobDoc = snapshot.data!.docs[index];
                    final jobData = jobDoc.data() as Map<String, dynamic>;
                    final applications = jobData['applications'] as List? ?? [];

                    if (applications.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Job title Badge
                        Container(
                          margin: EdgeInsets.only(bottom: 16, top: index == 0 ? 0 : 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: TextWidget(
                            text: jobData['title'] ?? 'Job Position',
                            fontSize: 14,
                            color: Colors.white70,
                            isBold: true,
                          ),
                        ),
                        ...applications.map((application) {
                          return _buildApplicationCard(application as Map<String, dynamic>, jobDoc.id, jobData['title'] ?? '', applications);
                        }),
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          TextWidget(
            text: 'No Applications Yet',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
          const SizedBox(height: 12),
          TextWidget(
            text: 'When candidates apply to your jobs,\nthey will appear here.',
            fontSize: 14,
            color: Colors.grey[500],
            align: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application, String jobId, String jobTitle, List<dynamic> allApplications) {
    final appliedAt = application['appliedAt'] as Timestamp?;
    final date = appliedAt != null
        ? DateFormat('MMM dd, yyyy').format(appliedAt.toDate())
        : 'Unknown date';
    final status = application['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: application['applicantName'] ?? 'Unknown Applicant',
                            fontSize: 18,
                            color: Colors.white,
                            isBold: true,
                          ),
                          const SizedBox(height: 4),
                          TextWidget(
                            text: 'Applied $date',
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),

                const SizedBox(height: 20),

                // Contact Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildContactRow(Icons.email_outlined, application['applicantEmail'] ?? 'No email'),
                      const SizedBox(height: 8),
                      _buildContactRow(Icons.phone_outlined, application['applicantPhone'] ?? 'No phone'),
                    ],
                  ),
                ),

                // Cover Letter Preview
                if (application['coverLetter'] != null && application['coverLetter'].toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextWidget(
                    text: 'Cover Letter',
                    fontSize: 12,
                    color: Colors.white54,
                    isBold: true,
                  ),
                  const SizedBox(height: 6),
                  TextWidget(
                    text: application['coverLetter'],
                    fontSize: 14,
                    color: Colors.white70,
                    maxLines: 3,
                  ),
                ],

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.description_outlined,
                        label: 'Resume',
                        color: Colors.grey[800]!,
                        onTap: () => _viewResume(application['resumeUrl']),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChatButton(application, jobId, jobTitle),
                    ),
                  ],
                ),
                
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.check_circle_outline,
                          label: 'Accept',
                          color: const Color(0xFF2E7D32),
                          onTap: () => _updateApplicationStatus(jobId, application['applicantId'], 'accepted', allApplications),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.cancel_outlined,
                          label: 'Reject',
                          color: const Color(0xFFC62828),
                          onTap: () => _updateApplicationStatus(jobId, application['applicantId'], 'rejected', allApplications),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'accepted':
      case 'approved':
        bgColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.greenAccent;
        text = 'ACCEPTED';
        break;
      case 'rejected':
        bgColor = Colors.red.withValues(alpha: 0.2);
        textColor = Colors.redAccent;
        text = 'REJECTED';
        break;
      default:
        bgColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orangeAccent;
        text = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: TextWidget(
        text: text,
        fontSize: 10,
        color: textColor,
        isBold: true,
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: TextWidget(
            text: text,
            fontSize: 13,
            color: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              TextWidget(
                text: label,
                fontSize: 13,
                color: Colors.white,
                isBold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildChatButton(Map<String, dynamic> application, String jobId, String jobTitle) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    
    // Create chatId exactly like JobChatScreen
    final List<String> userIds = [currentUser.uid, application['applicantId']];
    userIds.sort();
    final chatId = '${userIds[0]}_${userIds[1]}_$jobId';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('job_chats')
          .doc(chatId)
          .collection('messages')
          .where('isRead', isEqualTo: false)
          .where('senderId', isNotEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openChat(application, jobId, jobTitle),
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primary, Color(0xFF6B9F71)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  TextWidget(
                    text: 'Message',
                    fontSize: 13,
                    color: Colors.white,
                    isBold: true,
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: TextWidget(
                        text: unreadCount.toString(),
                        fontSize: 10,
                        color: Colors.white,
                        isBold: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateApplicationStatus(
      String jobId, String applicantId, String newStatus, List<dynamic> currentApplications) async {
    try {
      final updatedApplications = currentApplications.map((app) {
        if (app['applicantId'] == applicantId) {
          return {
            ...app as Map<String, dynamic>,
            'status': newStatus,
          };
        }
        return app;
      }).toList();

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('jobs')
          .doc(jobId)
          .update({'applications': updatedApplications});

      if (mounted) {
        CustomToast.showSuccess(context, 'Application $newStatus successfully');
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showError(context, 'Failed to update status: $e');
      }
    }
  }

  Future<void> _viewResume(String? resumeUrl) async {
    Navigator.pop(context);
    if (resumeUrl != null && resumeUrl.isNotEmpty) {
      final uri = Uri.parse(resumeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        CustomToast.showError(context, 'Could not open resume');
      }
    }
  }

  Future<void> _openChat(Map<String, dynamic> application, String jobId, String jobTitle) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobChatScreen(
          jobId: jobId,
          jobTitle: jobTitle,
          shopId: widget.shopId,
          posterId: currentUser.uid,
          applicantId: application['applicantId'] ?? '',
          applicationId: application['id'] ?? '',
        ),
      ),
    );
  }
}
