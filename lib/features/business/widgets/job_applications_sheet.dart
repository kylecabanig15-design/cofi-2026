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
import 'package:cofi/features/business/widgets/business_workspace_ui.dart';

class JobApplicationsBottomSheet extends StatefulWidget {
  final String shopId;
  const JobApplicationsBottomSheet({super.key, required this.shopId});

  @override
  State<JobApplicationsBottomSheet> createState() =>
      _JobApplicationsBottomSheetState();
}

class _JobApplicationsBottomSheetState
    extends State<JobApplicationsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return BusinessSheetShell(
      accentColor: Colors.indigoAccent,
      child: Column(
        children: [
          const BusinessSheetHeader(
            title: 'Candidate inbox',
            subtitle: 'Review applicants and continue the conversation',
            icon: Icons.people_alt_outlined,
          ),

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

                final allApplications = snapshot.data!.docs
                    .expand((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['applications'] as List? ?? const [];
                    })
                    .whereType<Map>()
                    .map((item) => item.cast<String, dynamic>())
                    .toList(growable: false);
                final pending = allApplications
                    .where((item) => (item['status'] ?? 'pending') == 'pending')
                    .length;
                final accepted = allApplications
                    .where((item) =>
                        item['status'] == 'accepted' ||
                        item['status'] == 'approved')
                    .length;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    children: [
                      BusinessMetricsStrip(
                        items: [
                          BusinessMetricData(
                              '${allApplications.length}', 'Candidates'),
                          BusinessMetricData('$pending', 'To review'),
                          BusinessMetricData('$accepted', 'Accepted'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final jobDoc = snapshot.data!.docs[index];
                            final jobData =
                                jobDoc.data() as Map<String, dynamic>;
                            final applications =
                                jobData['applications'] as List? ?? [];

                            if (applications.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Job title Badge
                                Container(
                                  margin: EdgeInsets.only(
                                      bottom: 16, top: index == 0 ? 0 : 24),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
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
                                  return _buildApplicationCard(
                                      application as Map<String, dynamic>,
                                      jobDoc.id,
                                      jobData['title'] ?? '',
                                      applications);
                                }),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const BusinessEmptyState(
      icon: Icons.inbox_outlined,
      title: 'Your candidate inbox is quiet',
      message:
          'Applications will arrive here, grouped by the role they applied for.',
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application, String jobId,
      String jobTitle, List<dynamic> allApplications) {
    final appliedAt = application['appliedAt'] as Timestamp?;
    final date = appliedAt != null
        ? DateFormat('MMM dd, yyyy').format(appliedAt.toDate())
        : 'Unknown date';
    final status = application['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: BusinessWorkspaceColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BusinessWorkspaceColors.line),
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
                            text: application['applicantName'] ??
                                'Unknown Applicant',
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
                      _buildContactRow(Icons.email_outlined,
                          application['applicantEmail'] ?? 'No email'),
                      const SizedBox(height: 8),
                      _buildContactRow(Icons.phone_outlined,
                          application['applicantPhone'] ?? 'No phone'),
                    ],
                  ),
                ),

                // Cover Letter Preview
                if (application['coverLetter'] != null &&
                    application['coverLetter'].toString().isNotEmpty) ...[
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
                          onTap: () => _updateApplicationStatus(
                              jobId,
                              application['applicantId'],
                              'accepted',
                              allApplications),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.cancel_outlined,
                          label: 'Reject',
                          color: const Color(0xFFC62828),
                          onTap: () => _updateApplicationStatus(
                              jobId,
                              application['applicantId'],
                              'rejected',
                              allApplications),
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

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    final foreground = color == Colors.grey[800] ? Colors.white70 : color;
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: foreground.withValues(alpha: .08),
        side: BorderSide(color: foreground.withValues(alpha: .25)),
        minimumSize: const Size(40, 46),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _buildChatButton(
      Map<String, dynamic> application, String jobId, String jobTitle) {
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

        return FilledButton.icon(
          onPressed: () => _openChat(application, jobId, jobTitle),
          style: FilledButton.styleFrom(minimumSize: const Size(40, 46)),
          icon: const Icon(Icons.chat_bubble_outline, size: 16),
          label: Text(unreadCount > 0 ? 'Message · $unreadCount' : 'Message'),
        );
      },
    );
  }

  Future<void> _updateApplicationStatus(String jobId, String applicantId,
      String newStatus, List<dynamic> currentApplications) async {
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
        CustomToast.showSuccess(
          context,
          'The candidate will see the updated application status.',
          title: 'Application ${newStatus.toLowerCase()}',
        );
      }
    } catch (_) {
      if (mounted) {
        CustomToast.showError(
          context,
          'We could not update the application. Please try again.',
          title: 'Status not updated',
        );
      }
    }
  }

  Future<void> _viewResume(String? resumeUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (resumeUrl == null || resumeUrl.isEmpty) {
      CustomToast.showFromMessenger(
        messenger,
        'This candidate did not provide an accessible résumé link.',
        type: ToastType.warning,
        title: 'Résumé unavailable',
      );
      return;
    }
    try {
      final uri = Uri.parse(resumeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        CustomToast.showFromMessenger(
          messenger,
          'The résumé link could not be opened on this device.',
          type: ToastType.error,
          title: 'Résumé unavailable',
        );
      }
    } catch (_) {
      CustomToast.showFromMessenger(
        messenger,
        'The résumé link could not be opened on this device.',
        type: ToastType.error,
        title: 'Résumé unavailable',
      );
    }
  }

  Future<void> _openChat(
      Map<String, dynamic> application, String jobId, String jobTitle) async {
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
