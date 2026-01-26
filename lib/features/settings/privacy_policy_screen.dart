import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'CoFi ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application ("App"). By using CoFi, you consent to the practices described in this policy.',
            ),
            _buildSection(
              '1. Information We Collect',
              '''We collect information to provide and improve our services:

Personal Information:
• Name and display name
• Email address
• Profile photo (optional)
• Location data (when permitted)

Usage Information:
• Café visits and check-ins
• Reviews and ratings
• Saved/bookmarked cafés
• Search history within the App

Device Information:
• Device type and operating system
• Unique device identifiers
• IP address
• App usage analytics''',
            ),
            _buildSection(
              '2. How We Use Your Information',
              '''We use collected information for:

• Providing personalized café recommendations
• Enabling café discovery and reviews
• Processing and displaying your reviews
• Sending relevant notifications (with your consent)
• Improving our services and user experience
• Ensuring security and preventing fraud
• Communicating updates and promotional content
• Analytics and performance monitoring''',
            ),
            _buildSection(
              '3. Information Sharing',
              '''We may share your information with:

Public Information:
• Your reviews and ratings are visible to other users
• Your display name associated with reviews

Service Providers:
• Firebase (authentication and database)
• Google Cloud Platform (hosting)
• Analytics providers

We DO NOT sell your personal information to third parties.''',
            ),
            _buildSection(
              '4. Data Storage and Security',
              '''Your data is stored securely using:

• Firebase Cloud Firestore (encrypted at rest)
• Secure HTTPS connections
• Industry-standard security measures

We retain your data for as long as your account is active or as needed to provide services. You may request deletion at any time through the App settings.''',
            ),
            _buildSection(
              '5. Your Rights and Choices',
              '''You have the right to:

• Access your personal data
• Correct inaccurate information
• Delete your account and associated data
• Opt-out of marketing communications
• Control location sharing permissions
• Export your data upon request

To exercise these rights, use the Settings page or contact us.''',
            ),
            _buildSection(
              '6. Location Services',
              '''CoFi uses location services to:

• Show nearby cafés
• Enable location-based search
• Record café visit check-ins

You can enable/disable location access in your device settings. Some features may be limited without location access.''',
            ),
            _buildSection(
              '7. Children\'s Privacy',
              'CoFi is not intended for users under 13 years of age. We do not knowingly collect information from children under 13. If we discover such data has been collected, we will delete it promptly.',
            ),
            _buildSection(
              '8. Third-Party Links',
              'Our App may contain links to third-party websites or services. We are not responsible for the privacy practices of these external sites. We encourage you to review their privacy policies.',
            ),
            _buildSection(
              '9. Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of significant changes through the App or via email. Continued use of CoFi after changes constitutes acceptance of the updated policy.',
            ),
            _buildSection(
              '10. Contact Us',
              '''If you have questions about this Privacy Policy or our data practices, contact us at:

Email: cofidvo@gmail.com

We will respond to your inquiry within 30 days.''',
            ),
            const SizedBox(height: 40),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Last Updated: January 26, 2026',
        style: TextStyle(
          color: primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Text(
            'CoFi - Café Discovery App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '© 2026 CoFi. All rights reserved.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
