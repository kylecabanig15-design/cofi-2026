import 'package:cofi/features/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/button_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Discover Cafes',
      description:
          'Find the best coffee shops in your area with personalized recommendations based on your preferences.',
      imagePath: 'assets/images/cofi_discover.png',
      icon: Icons.search,
    ),
    OnboardingPage(
      title: 'Share Reviews',
      description:
          'Rate and review coffee shops to help the community make informed decisions about where to go.',
      imagePath: 'assets/images/cofi_review.png',
      icon: Icons.star,
    ),
    OnboardingPage(
      title: 'Join Community',
      description:
          'Connect with fellow coffee enthusiasts, discover events, and find job opportunities in local cafes.',
      imagePath: 'assets/images/cofi_community.png',
      icon: Icons.people,
    ),
    OnboardingPage(
      title: 'Create Collections',
      description:
          'Organize your favorite cafes into custom lists and share them with friends and the community.',
      imagePath: 'assets/images/cofi_collections.png',
      icon: Icons.bookmark,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _completeOnboarding() async {
    // Save onboarding status
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasSeenOnboarding', true);
    } catch (e) {
      // If there's an error, continue anyway
      print('Error saving onboarding status: $e');
    }

    // Show location permission dialog before navigating
    _showLocationPermissionDialog();
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    size: 40,
                    color: primary,
                  ),
                ),

                const SizedBox(height: 24),

                // Title
                TextWidget(
                  text: 'Enable Location',
                  fontSize: 24,
                  color: Colors.white,
                  isBold: true,
                  align: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Description
                TextWidget(
                  text:
                      'Cofi needs location access to find coffee shops near you and provide personalized recommendations.',
                  fontSize: 16,
                  color: Colors.white70,
                  align: TextAlign.center,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // Microtips
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildMicrotip(
                        icon: Icons.search,
                        text: 'Discover cafes near your location',
                      ),
                      const SizedBox(height: 12),
                      _buildMicrotip(
                        icon: Icons.map,
                        text: 'Get directions to coffee shops',
                      ),
                      const SizedBox(height: 12),
                      _buildMicrotip(
                        icon: Icons.star,
                        text: 'See reviews from your area',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _navigateToLandingScreen();
                        },
                        child: TextWidget(
                          text: 'Not Now',
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ButtonWidget(
                        label: 'Enable',
                        fontSize: 16,
                        color: primary,
                        textColor: Colors.white,
                        radius: 30,
                        onPressed: () {
                          Navigator.of(context).pop();
                          _requestLocationPermission();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicrotip({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextWidget(
            text: text,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to enable location services
        _showLocationServicesDialog();
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied, navigate to landing screen
          _navigateToLandingScreen();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permission permanently denied, show dialog
        _showLocationPermanentlyDeniedDialog();
        return;
      }

      // Permission granted, navigate to landing screen
      _navigateToLandingScreen();
    } catch (e) {
      print('Error requesting location permission: $e');
      _navigateToLandingScreen();
    }
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: TextWidget(
            text: 'Location Services Disabled',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
          content: TextWidget(
            text:
                'Please enable location services in your device settings to use location features in Cofi.',
            fontSize: 16,
            color: Colors.white70,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLandingScreen();
              },
              child: TextWidget(
                text: 'Cancel',
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open device settings to enable location services
                await Geolocator.openLocationSettings();
                // After user returns from settings, navigate to landing screen
                _navigateToLandingScreen();
              },
              child: TextWidget(
                text: 'Settings',
                fontSize: 16,
                color: primary,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: TextWidget(
            text: 'Location Permission Required',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
          content: TextWidget(
            text:
                'Location permission was permanently denied. Please enable it in your device settings to use location features in Cofi.',
            fontSize: 16,
            color: Colors.white70,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLandingScreen();
              },
              child: TextWidget(
                text: 'Not Now',
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Open app settings to enable location permission
                await openAppSettings();
                // After user returns from settings, navigate to landing screen
                _navigateToLandingScreen();
              },
              child: TextWidget(
                text: 'Settings',
                fontSize: 16,
                color: primary,
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToLandingScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: TextWidget(
                    text: 'Skip',
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicators
            _buildPageIndicator(),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous button (hidden on first page)
                  _currentPage > 0
                      ? Expanded(
                          child: TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: TextWidget(
                              text: 'Previous',
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : const Expanded(child: SizedBox()),

                  // Next/Get Started button
                  Expanded(
                    child: ButtonWidget(
                      label: _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      fontSize: 16,
                      color: primary,
                      textColor: Colors.white,
                      radius: 30,
                      onPressed: _nextPage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon or image
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 100,
              color: primary,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          TextWidget(
            text: page.title,
            fontSize: 32,
            color: Colors.white,
            isBold: true,
            align: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          TextWidget(
            text: page.description,
            fontSize: 16,
            color: Colors.white70,
            align: TextAlign.center,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: _currentPage == index ? 24 : 8,
            decoration: BoxDecoration(
              color: _currentPage == index ? primary : Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
  });
}
