import 'package:cofi/features/home/collections_tab.dart';
import 'package:cofi/features/home/profile_tab.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'explore_tab.dart';
import 'community_tab.dart';
import 'package:cofi/features/networking/notification_screen.dart';

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

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
    _tabs = [
      ExploreTab(
        onOpenCommunity: () {
          setState(() {
            _currentIndex = 1; // Community tab index
          });
        },
      ),
      const CommunityTab(),
      // Placeholder widgets for Collections and Profile
      const CollectionsTab(),
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
      setState(() {
        _unreadCount = _notificationService.getUnreadCount();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              backgroundColor: Colors.black,
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
                      icon:
                          const Icon(Icons.notifications, color: Colors.white),
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
                            _unreadCount > 99 ? '99+' : _unreadCount.toString(),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _currentIndex != 0
          ? null
          : FloatingActionButton.extended(
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
      backgroundColor: Colors.black,
      bottomNavigationBar: _buildBottomNavBar(),
      body: SafeArea(
        child: _tabs[_currentIndex],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      backgroundColor: Colors.black,
      selectedItemColor: Colors.red[700],
      unselectedItemColor: Colors.white70,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Explore',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Community',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'Collections',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      currentIndex: _currentIndex,
      onTap: (i) {
        setState(() {
          _currentIndex = i;
        });
      },
    );
  }
}
