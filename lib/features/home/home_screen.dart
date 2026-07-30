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
import 'package:cofi/features/cafe/cafe_details_screen.dart';

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
  final GlobalKey _firstCafeKey = GlobalKey();

  // Custom Tab Keys
  final GlobalKey _exploreTabKey = GlobalKey();
  final GlobalKey _communityTabKey = GlobalKey();
  final GlobalKey _collectionsTabKey = GlobalKey();
  final GlobalKey _profileTabKey = GlobalKey();
  TutorialCoachMark? _tutorialCoachMark;
  
  // State Key for ExploreTab to trigger programmatic taps
  final GlobalKey<ExploreTabState> _exploreTabStateKey = GlobalKey<ExploreTabState>();

  // Scroll controller passed to ExploreTab for animated focus
  final ScrollController _exploreScrollController = ScrollController();
  // Flag: tour is pausing to go into a cafe
  bool _isTourGoingToCafe = false;
  // Flag: Phase 1 tour is actively running
  bool _isTourActive = false;

  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _tabs = [
      ExploreTab(
        key: _exploreTabStateKey,
        searchKey: _searchKey,
        filterKey: _filterKey,
        firstCafeKey: _firstCafeKey,
        scrollController: _exploreScrollController,
        onFirstCafeTap: _handleTourCafeTap,
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
                  key: _exploreTabStateKey,
                  searchKey: _searchKey,
                  filterKey: _filterKey,
                  firstCafeKey: _firstCafeKey,
                  scrollController: _exploreScrollController,
                  onFirstCafeTap: _handleTourCafeTap,
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
      int waitCount = 0;
      while (_firstCafeKey.currentContext == null && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (mounted) {
        _showTutorial();
      }
    }
  }

  void _showTutorial() {
    _isTourActive = true;
    // Phase 1: search, filter, map, firstCafe
    // No filtering — _checkTutorial already waited for firstCafeKey to mount
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createPhase1Targets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: true,
      onFinish: () {
        // Phase 1 never shows the completion dialog.
        // If user reached here naturally (tapped cafe), _handleTourCafeTap
        // already took over. If they somehow skipped steps, Phase 2 handles it.
        // Do nothing — cafe details tutorial and Phase 2 handle the rest.
      },
      onClickTarget: (target) {
        if (target.identify == "mapBtnKey") {
          // Bounce-scroll to focus the cafe list
          _scrollBounceForCafeFocus();
        } else if (target.identify == "firstCafeKey") {
          // Programmatically click the first cafe so it acts like a single click
          _exploreTabStateKey.currentState?.openFirstCafe();
        }
      },
      onClickOverlay: (target) {},
      onSkip: () {
        // User chose to skip entirely — show completion and mark seen
        _isTourActive = false;
        _isTourGoingToCafe = false;
        _markTutorialSeen();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showTourCompleteDialog();
        });
        return true;
      },
    )..show(context: context);
  }

  /// Bounce-scroll the cafe list down then back to a mid-screen position.
  void _scrollBounceForCafeFocus() {
    if (!_exploreScrollController.hasClients) return;
    // Scroll down to 400 to show context, then snap back to 220 (mid-screen)
    _exploreScrollController
        .animateTo(
          400,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        )
        .then((_) {
      _exploreScrollController.animateTo(
        220,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Called when the user taps the first cafe card.
  void _handleTourCafeTap(String shopId, Map<String, dynamic> data) {
    if (!_isTourActive) {
      // Normal tap, tour is not active
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CafeDetailsScreen(
            shopId: shopId,
            shop: data,
          ),
        ),
      );
      return;
    }

    // Tour is active
    _isTourActive = false;
    _isTourGoingToCafe = true;
    _tutorialCoachMark?.finish();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CafeDetailsScreen(
          shopId: shopId,
          shop: data,
          isTourMode: true,
          onTourComplete: () {
            // Small delay so pop completes first
            Future.delayed(const Duration(milliseconds: 350), () {
              if (mounted) _startPhase2Tutorial();
            });
          },
        ),
      ),
    );
  }

  /// Phase 2 of the tour: Community, Collections, Profile tabs.
  void _startPhase2Tutorial() {
    final phase2Targets = _createPhase2Targets()
        .where((t) => t.keyTarget == null || t.keyTarget!.currentContext != null)
        .toList();
    _tutorialCoachMark = TutorialCoachMark(
      targets: phase2Targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      hideSkip: true,
      onFinish: () {
        _isTourGoingToCafe = false;
        _markTutorialSeen();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showTourCompleteDialog();
        });
      },
      onClickTarget: (target) {
        if (target.identify == "communityTabKey") {
          setState(() => _currentIndex = 1);
        } else if (target.identify == "collectionsTabKey") {
          setState(() => _currentIndex = 2);
        } else if (target.identify == "profileTabKey") {
          setState(() => _currentIndex = 3);
        }
      },
      onClickOverlay: (target) {},
      onSkip: () {
        _isTourGoingToCafe = false;
        _markTutorialSeen();
        return true;
      },
    )..show(context: context);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenExploreTutorial', true);
  }

  void _showTourCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF0D0D0D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated emoji badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('☕', style: TextStyle(fontSize: 42)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "You're All Set!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Welcome to CoFi! You now know how to explore cafes, log visits, and connect with the community. Time to find your next favourite cup ☕",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 15,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Divider with sparkle
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('✨', style: TextStyle(fontSize: 16)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() => _currentIndex = 0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Start Exploring  🚀',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<TargetFocus> _createPhase1Targets() {
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
                title: "Find Cafes",
                description:
                    "Looking for a specific spot? Tap here to search by name or vibe.",
                actionText: "Tap here or Next to continue",
                controller: controller,
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
                controller: controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "mapBtnKey",
        keyTarget: _mapBtnKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.map,
                title: "Map View",
                description:
                    "See cafes near you on the interactive map to easily plan your coffee run.",
                actionText: "Tap Next to see the cafe list",
                controller: controller,
                onNext: _scrollBounceForCafeFocus,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "firstCafeKey",
        keyTarget: _firstCafeKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildPremiumTutorialCard(
                icon: Icons.coffee,
                title: "Try It Now!",
                description:
                    "Tap this cafe to see its details and log a visit!",
                actionText: "👆 Tap the card to continue",
                controller: controller,
                isActionTap: true,
              );
            },
          ),
        ],
      ),
    ];
  }

  List<TargetFocus> _createPhase2Targets() {
    return [
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
                controller: controller,
                isActionTap: true,
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
                controller: controller,
                isActionTap: true,
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
                title: "Your Profile",
                description:
                    "Manage your preferences, view your cafe history, and customize your CoFi experience. You're all set — enjoy your coffee journey!",
                actionText: "Tap Profile to finish the tour",
                controller: controller,
                isActionTap: true,
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
    TutorialCoachMarkController? controller,
    bool isActionTap = false,
    VoidCallback? onNext,
  }) {
    void handleNext() {
      if (onNext != null) {
        onNext();
        // Wait for animation (scroll bounce = 350+500ms) to complete before advancing
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!isActionTap && controller != null) {
            controller.next();
          }
        });
      } else {
        if (!isActionTap && controller != null) {
          controller.next();
        }
      }
    }
    return GestureDetector(
      onTap: () {
        if (!isActionTap) handleNext();
      },
      child: Container(
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
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  controller?.skip();
                  _markTutorialSeen();
                },
                child: const Text('SKIP', style: TextStyle(color: Colors.white54)),
              ),
              if (!isActionTap)
                ElevatedButton(
                  onPressed: () => handleNext(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('NEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
      ),
    ));
  }
}
