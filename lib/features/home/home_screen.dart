import 'package:cofi/features/home/collections_tab.dart';
import 'package:cofi/features/home/profile_tab.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:ui';
import 'explore_tab.dart';
import 'community_tab.dart';
import 'collections_tab.dart';
import 'profile_tab.dart';
import 'package:cofi/features/networking/notification_screen.dart';
import 'package:cofi/widgets/premium_background.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;
  String _accountType = 'user'; // Defaults to user

  // Tutorial Keys
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _mapBtnKey = GlobalKey();

  // Custom Tab Keys
  final GlobalKey _exploreTabKey = GlobalKey();
  final GlobalKey _communityTabKey = GlobalKey();
  final GlobalKey _collectionsTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;

  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _tabs = [
      ExploreTab(
        searchKey: _searchKey,
        filterKey: _filterKey,
        onOpenCommunity: () {
          setState(() {
            _currentIndex = 1; // Community tab index
          });
        },
      ),
      const CommunityTab(),
      // Placeholder widgets for Collections and Profile
      if (_accountType != 'business') const CollectionsTab(),
      ProfileTab(
        onOpenExplore: () {
          setState(() {
            _currentIndex = 0; // Explore tab index
          });
        },
        onOpenCommunity: () {
          setState(() {
            _currentIndex = 1; // Community tab index
          });
        },
      ),
    ];

    // Initialize notification service and get unread count
    _notificationService.init().then((_) {
      if (mounted) {
        setState(() {
          _unreadCount = _notificationService.getUnreadCount();
        });

        // AUTOMATED DISCOVERY: Check for new recommendations on startup
        // This ensures "Taste matches" pop up in the top right after logging in
        _notificationService.checkForNewData();
      }
    });

    // TEMPORARY: Fix pending jobs
    FirebaseFirestore.instance.collection('allJobs').where('status', isEqualTo: 'pending').get().then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'status': 'active'});
        final shopId = doc.data()['shopId'];
        if (shopId != null) {
          FirebaseFirestore.instance.collection('shops').doc(shopId).collection('jobs').doc(doc.id).update({'status': 'active'}).catchError((_) {});
        }
      }
    });

    // Fetch account type
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (mounted && doc.exists) {
          final accType = doc.data()?['accountType'] as String? ?? 'user';
          if (accType != _accountType) {
            setState(() {
              _accountType = accType;
              // Rebuild tabs list to remove collections if needed
              _tabs = [
                ExploreTab(
                  searchKey: _searchKey,
                  filterKey: _filterKey,
                  onOpenCommunity: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
                const CommunityTab(),
                if (_accountType != 'business') const CollectionsTab(),
                ProfileTab(
                  onOpenExplore: () {
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                  onOpenCommunity: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
              ];
            });
          }
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        appBar: _currentIndex == 0
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                title: Image.asset(
                  'assets/images/logo.png',
                  height: 25,
                ),
                actions: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationScreen(),
                            ),
                          ).then((_) {
                            // Refresh unread count when returning from notification screen
                            setState(() {
                              _unreadCount =
                                  _notificationService.getUnreadCount();
                            });
                          });
                        },
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              _unreadCount > 99
                                  ? '99+'
                                  : _unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
              )
            : null,
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: _buildBottomNavBar(),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
            if (_currentIndex == 0)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 95,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    key: _mapBtnKey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: primary,
                    onPressed: () {
                      Navigator.pushNamed(context, '/mapView');
                    },
                    label: TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/mapView');
                      },
                      label: TextWidget(
                          text: 'Nearby Cafes',
                          fontSize: 16,
                          color: white,
                          isBold: true),
                      icon: Icon(
                        FontAwesomeIcons.map,
                        color: white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: 40,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 20,
            right: 20,
          ),
          child: Container(
            height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.search, 'Explore', _exploreTabKey),
              _buildNavItem(1, Icons.people, 'Community', _communityTabKey),
              if (_accountType != 'business')
                _buildNavItem(2, Icons.bookmark, 'Collections', _collectionsTabKey),
              _buildNavItem(
                _accountType != 'business' ? 3 : 2, 
                Icons.person, 
                'Profile', 
                _profileTabKey
              ),
            ],
          ),
        ),
      ),
      ),
      ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, GlobalKey key) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        key: key,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.redAccent : Colors.white54,
                size: isSelected ? 24 : 22,
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? Colors.redAccent : Colors.white54,
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                width: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenExploreTutorial') ?? false;
    if (!hasSeen) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () => _markTutorialSeen(),
      onClickTarget: (target) {
        if (target.identify == "communityTabKey") {
          setState(() => _currentIndex = 1);
        } else if (target.identify == "collectionsTabKey") {
          setState(() => _currentIndex = 2);
        } else if (target.identify == "profileTabKey") {
          setState(() => _currentIndex = 3);
        } else if (target.identify == "exploreTabKey") {
          setState(() => _currentIndex = 0);
        }
      },
      onClickOverlay: (target) {},
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenExploreTutorial', true);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "searchKey",
        keyTarget: _searchKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.search,
                title: "Search Cafes",
                description:
                    "Find exactly what you're looking for by searching for cafe names, specific features, or even vibes.",
                actionText: "Tap anywhere to continue",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "filterKey",
        keyTarget: _filterKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.tune,
                title: "Refine Results",
                description:
                    "Filter cafes by amenities, vibe, rating, and distance to discover the perfect spot for any occasion.",
                actionText: "Tap anywhere to continue",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "mapBtnKey",
        keyTarget: _mapBtnKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.map,
                title: "Map View",
                description:
                    "See cafes near you on the interactive map to easily plan your coffee run.",
                actionText: "Tap anywhere to continue",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "communityTabKey",
        keyTarget: _communityTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.people,
                title: "Community",
                description:
                    "Connect with other coffee lovers, share your experiences, and read real reviews from cafe hoppers just like you.",
                actionText: "Tap the Community icon below to continue",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "collectionsTabKey",
        keyTarget: _collectionsTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.bookmark,
                title: "Collections",
                description:
                    "Save your favorite spots, organize them into personalized lists, and plan your ultimate cafe hopping itinerary.",
                actionText: "Tap the Collections icon below to continue",
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "profileTabKey",
        keyTarget: _profileTabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.person,
                title: "Profile",
                description:
                    "Manage your unique preferences, view your review history, and completely customize your CoFi experience.",
                actionText: "Tap the Profile icon to finish the tour",
              );
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildPremiumTutorialCard({
    required IconData icon,
    required String title,
    required String description,
    required String actionText,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A1A).withOpacity(0.95),
            const Color(0xFF111111).withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent, Colors.red[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (actionText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      actionText,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
