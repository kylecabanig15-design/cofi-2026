import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

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
          'Terms of Service',
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
              'Agreement to Terms',
              'By accessing or using the CoFi mobile application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, you may not access or use the App. These Terms constitute a legally binding agreement between you and CoFi.',
            ),
            _buildSection(
              '1. Eligibility',
              '''To use CoFi, you must:

• Be at least 13 years of age
• Have the legal capacity to enter into a binding agreement
• Not be prohibited from using the App under applicable laws
• Provide accurate and complete registration information

If you are using the App on behalf of a business, you represent that you have authority to bind that entity to these Terms.''',
            ),
            _buildSection(
              '2. Account Registration',
              '''When creating an account, you agree to:

• Provide accurate, current, and complete information
• Maintain and update your information as needed
• Keep your login credentials secure and confidential
• Notify us immediately of unauthorized account access
• Accept responsibility for all activities under your account

We reserve the right to suspend or terminate accounts that violate these Terms.''',
            ),
            _buildSection(
              '3. Acceptable Use',
              '''You agree NOT to:

• Post false, misleading, or fraudulent reviews
• Harass, threaten, or intimidate other users
• Impersonate any person or entity
• Upload malicious code or attempt to hack the App
• Use the App for any illegal purpose
• Scrape or collect data without authorization
• Interfere with the App's operation or security
• Violate any applicable laws or regulations
• Post content that is defamatory, obscene, or harmful
• Spam or engage in unsolicited advertising''',
            ),
            _buildSection(
              '4. User Content',
              '''By submitting content (reviews, photos, ratings), you:

• Grant CoFi a non-exclusive, royalty-free, worldwide license to use, display, and distribute your content
• Confirm you own or have rights to the content
• Agree your content may be visible to other users
• Accept that we may moderate or remove content at our discretion

You retain ownership of your content but grant us the right to use it for App functionality and promotion.''',
            ),
            _buildSection(
              '5. Reviews and Ratings',
              '''When posting reviews, you agree to:

• Provide honest and accurate assessments
• Base reviews on genuine personal experiences
• Not accept compensation for reviews without disclosure
• Respect the intellectual property of café owners
• Not post reviews for businesses you own or are affiliated with

We reserve the right to remove reviews that violate these guidelines or our content policies.''',
            ),
            _buildSection(
              '6. Business Accounts',
              '''If you operate a business account:

• You confirm you are authorized to represent the business
• You agree to respond professionally to customer reviews
• You will not manipulate reviews or ratings
• You accept responsibility for maintaining accurate business information
• You agree to our Business Terms (available upon request)''',
            ),
            _buildSection(
              '7. Intellectual Property',
              '''All App content, features, and functionality are owned by CoFi and protected by:

• Copyright laws
• Trademark laws
• Other intellectual property rights

You may not copy, modify, distribute, or reverse engineer any part of the App without our written permission. The CoFi name, logo, and all related marks are our trademarks.''',
            ),
            _buildSection(
              '8. Third-Party Services',
              '''The App integrates with third-party services including:

• Google Maps (for location services)
• Firebase (for authentication and data storage)

Your use of these services is subject to their respective terms and privacy policies. We are not responsible for third-party service availability or actions.''',
            ),
            _buildSection(
              '9. Disclaimers',
              '''THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND.

We do not guarantee:
• Accuracy of café information or reviews
• Continuous, uninterrupted service
• That the App will meet your specific requirements
• That errors will be corrected

We are not responsible for decisions made based on App information.''',
            ),
            _buildSection(
              '10. Limitation of Liability',
              '''TO THE MAXIMUM EXTENT PERMITTED BY LAW:

CoFi shall not be liable for:
• Indirect, incidental, or consequential damages
• Loss of profits, data, or business opportunities
• Damages arising from user content or third-party actions
• Any amount exceeding the fees you paid to us (if any)

Some jurisdictions do not allow limitation of liability, so these limits may not apply to you.''',
            ),
            _buildSection(
              '11. Indemnification',
              'You agree to indemnify and hold harmless CoFi, its officers, directors, employees, and agents from any claims, damages, losses, or expenses (including legal fees) arising from your use of the App, violation of these Terms, or infringement of any third-party rights.',
            ),
            _buildSection(
              '12. Termination',
              '''We may terminate or suspend your account at any time for:

• Violation of these Terms
• Fraudulent or illegal activity
• Extended periods of inactivity
• Upon your request

Upon termination, your right to use the App ceases immediately. Provisions that by their nature should survive (indemnification, limitation of liability) will remain in effect.''',
            ),
            _buildSection(
              '13. Modifications',
              'We reserve the right to modify these Terms at any time. We will notify users of material changes through the App or via email. Your continued use of the App after changes constitutes acceptance of the modified Terms.',
            ),
            _buildSection(
              '14. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of the Republic of the Philippines, without regard to conflict of law principles. Any disputes shall be resolved in the courts of Cebu City, Philippines.',
            ),
            _buildSection(
              '15. Contact Information',
              '''For questions about these Terms, contact us at:

Email: cofidvo@gmail.com

We will respond to your inquiry within 30 business days.''',
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
        'Effective Date: January 26, 2026',
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
