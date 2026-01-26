import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/colors.dart';
import '../../widgets/text_widget.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail(BuildContext context, String subject,
      {String body = ''}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'cofidvo@gmail.com',
      queryParameters: {
        'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not open email client. Please ensure you have a mail app installed.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showBugReportDialog(BuildContext context) {
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Report a Bug',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please describe the issue you encountered:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the bug...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final body = '''
BUG REPORT - CoFi App
=====================

Description:
${descriptionController.text}

---
Device Info: (Please include your device model and OS version)
App Version: 1.0.0
Date: ${DateTime.now().toString().split('.')[0]}
''';
              _launchEmail(context, 'Bug Report - CoFi App', body: body);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showContentReportDialog(BuildContext context) {
    final descriptionController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Report Inappropriate Content',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please describe the content issue:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe the issue (include café name if applicable)...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final body = '''
CONTENT REPORT - CoFi App
=========================

Issue Description:
${descriptionController.text}

---
Report Type: Inappropriate Content
Date: ${DateTime.now().toString().split('.')[0]}
''';
              _launchEmail(context, 'Content Report - CoFi App', body: body);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showCafeInfoReportDialog(BuildContext context) {
    final cafeNameController = TextEditingController();
    final issueController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Report Café Information',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Café Name:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cafeNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter café name...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'What needs to be corrected?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: issueController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Wrong address, hours, closed permanently, etc.',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final body = '''
CAFÉ INFORMATION CORRECTION - CoFi App
======================================

Café Name: ${cafeNameController.text}

Issue:
${issueController.text}

---
Report Type: Incorrect Café Information
Date: ${DateTime.now().toString().split('.')[0]}
''';
              _launchEmail(context, 'Café Info Correction - CoFi App',
                  body: body);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.3),
                    primary.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a topic below or contact our support team',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contact Options
            TextWidget(
              text: 'Contact Us',
              fontSize: 18,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'cofidvo@gmail.com',
              description: 'Get a response within 24-48 hours',
              onTap: () => _launchEmail(context, 'CoFi App Support Request'),
            ),
            const SizedBox(height: 24),

            // FAQ Section
            TextWidget(
              text: 'Frequently Asked Questions',
              fontSize: 18,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 12),
            _buildFAQItem(
              question: 'How do I log a café visit?',
              answer:
                  'Navigate to a café\'s detail page and tap the "Log Visit" button. You can add notes and photos to remember your experience. Your visits are tracked in your profile under "Shops Visited."',
            ),
            _buildFAQItem(
              question: 'How do I write a review?',
              answer:
                  'Go to any café\'s detail page and tap "Write Review." Rate your experience (1-5 stars), add your comments, and submit. Your review helps other coffee lovers discover great cafés!',
            ),
            _buildFAQItem(
              question: 'How do I save/bookmark a café?',
              answer:
                  'Tap the bookmark icon on any café card or detail page. Saved cafés appear in your bookmarks for easy access later.',
            ),
            _buildFAQItem(
              question: 'How do I submit a new café?',
              answer:
                  'Go to your Profile tab and tap "Submit A Shop" under Contribute to Community. Fill in the café details, add photos, and submit for review. Our team will verify and approve within 3-5 business days.',
            ),
            _buildFAQItem(
              question: 'What is a Business Account?',
              answer:
                  'Business accounts are for café owners and managers. They provide access to analytics, customer insights, and the ability to respond to reviews. Contact us to upgrade your account.',
            ),
            _buildFAQItem(
              question: 'How do I delete my account?',
              answer:
                  'Go to Settings > Danger Zone > Delete Account. This action is permanent and will remove all your data including reviews, visits, and saved cafés.',
            ),
            _buildFAQItem(
              question: 'How do I change my display name?',
              answer:
                  'Go to Settings > Account > Edit Profile. You can update your display name from there.',
            ),
            _buildFAQItem(
              question: 'Why can\'t I see my review?',
              answer:
                  'Reviews may take a few minutes to appear. If it\'s been longer, your review might be under moderation. Check that your review complies with our community guidelines.',
            ),
            const SizedBox(height: 24),

            // Report Issue
            TextWidget(
              text: 'Report an Issue',
              fontSize: 18,
              color: Colors.white,
              isBold: true,
            ),
            const SizedBox(height: 12),
            _buildReportCard(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              description: 'Something not working correctly?',
              onTap: () => _showBugReportDialog(context),
            ),
            _buildReportCard(
              icon: Icons.flag_outlined,
              title: 'Report Inappropriate Content',
              description: 'Flag reviews or content that violates guidelines',
              onTap: () => _showContentReportDialog(context),
            ),
            _buildReportCard(
              icon: Icons.store_outlined,
              title: 'Report Incorrect Café Info',
              description: 'Wrong address, hours, or closed permanently?',
              onTap: () => _showCafeInfoReportDialog(context),
            ),
            const SizedBox(height: 24),

            // App Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Image.asset('assets/images/logo.png'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'CoFi v1.0.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Thank you for using CoFi! We\'re constantly improving the app based on your feedback.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: primary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        iconColor: Colors.white54,
        collapsedIconColor: Colors.white54,
        title: Text(
          question,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
