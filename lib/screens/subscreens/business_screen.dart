import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../widgets/text_widget.dart';

class BusinessScreen extends StatelessWidget {
  const BusinessScreen({super.key});

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
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Business Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextWidget(
                  text: 'Business',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                ),
              ),
              const SizedBox(height: 24),

              // Switch to Business
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/businessProfile');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextWidget(
                                  text: 'Switch to Business',
                                  fontSize: 16,
                                  color: Colors.white,
                                  isBold: true,
                                ),
                                const SizedBox(height: 4),
                                TextWidget(
                                  maxLines: 5,
                                  text:
                                      'It\'s simple to get set up and start earning.',
                                  fontSize: 14,
                                  color: Colors.grey[400]!,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.local_cafe,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildMenuItem('Claim shop', Icons.chevron_right),
                    _buildClickableMenuItem(
                      'Post a job',
                      Icons.chevron_right,
                      () => Navigator.pushNamed(context, '/businessProfile'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Divider
              Divider(color: Colors.grey[800], thickness: 1),

              const SizedBox(height: 32),

              // Contribute Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextWidget(
                  text: 'Contribute',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, '/submitShop'),
                        child: _buildMenuItem(
                            'Submit a shop', Icons.chevron_right)),
                    _buildClickableMenuItem(
                      'Post an event',
                      Icons.chevron_right,
                      () => Navigator.pushNamed(context, '/businessProfile'),
                    ),
                    _buildMenuItem(
                        'Suggest app functionality', Icons.chevron_right),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Divider
              Divider(color: Colors.grey[800], thickness: 1),

              const SizedBox(height: 32),

              // Settings Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextWidget(
                  text: 'Settings',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/submitShop'),
                    child: _buildMenuItem(
                        'Personal information', Icons.chevron_right)),
              ),

              const SizedBox(height: 32),

              // Divider
              Divider(color: Colors.grey[800], thickness: 1),

              const SizedBox(height: 32),

              // Support Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextWidget(
                  text: 'Support',
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildMenuItem('Donations', Icons.chevron_right),
                    _buildMenuItem('How CoFi works', Icons.chevron_right),
                    _buildMenuItem('Give us feedback', Icons.chevron_right),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Divider
              Divider(color: Colors.grey[800], thickness: 1),

              const SizedBox(height: 24),

              // Log out
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: TextWidget(
                  text: 'Log out',
                  fontSize: 16,
                  color: Colors.grey[400]!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextWidget(
            text: title,
            fontSize: 16,
            color: Colors.white,
          ),
          Icon(
            icon,
            color: Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildClickableMenuItem(
      String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextWidget(
              text: title,
              fontSize: 16,
              color: Colors.white,
            ),
            Icon(
              icon,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
