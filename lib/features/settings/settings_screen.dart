import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/edit_profile_dialog.dart';
import 'package:cofi/features/auth/login_screen.dart';
import 'package:cofi/services/google_sign_in_service.dart';
import 'package:cofi/utils/auth_error_handler.dart';
import 'package:cofi/services/notification_service.dart';
import 'package:cofi/features/settings/privacy_policy_screen.dart';
import 'package:cofi/features/settings/terms_of_service_screen.dart';
import 'package:cofi/features/settings/help_support_screen.dart';
import 'package:cofi/utils/formatters.dart';
import 'package:cofi/features/auth/interest_selection_screen.dart';
import 'package:cofi/features/admin/admin_dashboard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isAdmin = false;
  bool _isLoadingAdmin = true;


  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && mounted) {
        setState(() {
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _isAdmin = data['isAdmin'] == true;
          _isLoadingAdmin = false;
        });
      }
    } else {
      setState(() {
        _isLoadingAdmin = false;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          value ? 'Enable Notifications' : 'Disable Notifications',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          value
              ? 'Stay updated with the best café matches and community events!'
              : 'You will stop receiving alerts for new cafés and community updates. Are you sure?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: value ? primary : Colors.redAccent,
            ),
            child: Text(value ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'notificationsEnabled': value});
      if (mounted) {
        setState(() {
          _notificationsEnabled = value;
        });
      }
    }
  }



  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => const EditProfileDialog(),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await GoogleSignInService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final TextEditingController confirmController = TextEditingController();
    final ValueNotifier<bool> canDelete = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade900, width: 2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.redAccent,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Warning message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.shade800.withOpacity(0.5),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action is permanent and cannot be undone!',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Consequences list
                const Text(
                  'The following will be permanently deleted:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _buildConsequenceItem(Icons.rate_review, 'All your reviews'),
                const SizedBox(height: 8),
                _buildConsequenceItem(Icons.place, 'Your visit history'),
                const SizedBox(height: 8),
                _buildConsequenceItem(Icons.upload_file, 'Café submissions'),
                const SizedBox(height: 8),
                _buildConsequenceItem(Icons.person, 'Your profile data'),
                const SizedBox(height: 8),
                _buildConsequenceItem(Icons.favorite, 'Saved favorites'),
                const SizedBox(height: 20),
                // Verification section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To confirm, type DELETE below:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        onChanged: (value) {
                          canDelete.value = value.trim() == 'DELETE';
                          setState(() {}); // Rebuild to update button state
                        },
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type DELETE here',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.normal,
                          ),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Dispose after navigation completes
                Future.delayed(const Duration(milliseconds: 100), () {
                  confirmController.dispose();
                  canDelete.dispose();
                });
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: canDelete,
              builder: (context, enabled, child) {
                return ElevatedButton(
                  onPressed: enabled
                      ? () async {
                          Navigator.of(ctx).pop();
                          // Dispose after navigation completes
                          Future.delayed(const Duration(milliseconds: 100), () {
                            confirmController.dispose();
                            canDelete.dispose();
                          });
                          await _deleteAccount();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    disabledBackgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsequenceItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.red.shade300,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Step 1: Re-authenticate first (mandatory for deletion)
      final reAuthed = await _reauthenticateUser(user);
      if (!reAuthed) return;

      // Re-fetch user to get fresh tokens/state
      final freshUser = FirebaseAuth.instance.currentUser;
      if (freshUser == null) return;

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: primary),
          ),
        );
      }

      // Step 2: Comprehensive Data Cleanup
      await _performDeepCleanup(freshUser.uid);

      // Step 3: Delete user document from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(freshUser.uid)
          .delete();

      // Step 4: Delete the Firebase Auth user account
      await freshUser.delete();

      // Step 5: Ensure Google Sign In is also signed out
      await GoogleSignInService.signOut();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message and navigate to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } on Exception catch (e) {
      // Close initial loading dialog if it was shown
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthErrorHandler.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _performDeepCleanup(String uid) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Lists & Items within them
    try {
      final listsRef = firestore.collection('users').doc(uid).collection('lists');
      final lists = await listsRef.get();
      for (var list in lists.docs) {
        try {
          final items = await list.reference.collection('items').get();
          final batch = firestore.batch();
          for (var item in items.docs) {
            batch.delete(item.reference);
          }
          await batch.commit();
          await list.reference.delete();
        } catch (e) {
          debugPrint('Error cleaning up list ${list.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error fetching lists for cleanup: $e');
    }

    // 2. Shop Claims
    try {
      final claims = await firestore.collection('shop_claims').where('claimantId', isEqualTo: uid).get();
      if (claims.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (var doc in claims.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error cleaning up shop claims: $e');
    }

    // 3. Shared Collections
    try {
      final shared = await firestore.collection('sharedCollections').where('userId', isEqualTo: uid).get();
      if (shared.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (var doc in shared.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error cleaning up shared collections: $e');
    }

    // 4. Jobs (This often fails due to missing index)
    try {
      final jobs = await firestore.collectionGroup('jobs').where('createdBy', isEqualTo: uid).get();
      for (var doc in jobs.docs) {
        await firestore.collection('allJobs').doc(doc.id).delete();
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error cleaning up jobs (Check index): $e');
    }

    // 5. Reviews across all shops
    try {
      final reviews = await firestore.collectionGroup('reviews').where('userId', isEqualTo: uid).get();
      if (reviews.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (var doc in reviews.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error cleaning up reviews: $e');
    }

    // 6. Community Event Comments
    try {
      final comments = await firestore.collectionGroup('comments').where('userId', isEqualTo: uid).get();
      if (comments.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (var doc in comments.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error cleaning up comments: $e');
    }

    // 7. Community Shops (Added by user)
    try {
      final shopsAdded = await firestore.collection('shops').where('posterId', isEqualTo: uid).get();
      if (shopsAdded.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (var doc in shopsAdded.docs) {
          batch.update(doc.reference, {'posterId': null});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error anonymizing posted shops: $e');
    }

    // 8. Dissociate Business Ownership & revert status (CRITICAL FIX)
    try {
      final shopsOwned = await firestore.collection('shops').where('ownerId', isEqualTo: uid).get();
      for (var doc in shopsOwned.docs) {
        await doc.reference.update({
          'ownerId': null, 
          'isVerified': false,
          'submissionType': 'community'
        });
      }
    } catch (e) {
      debugPrint('Error dissociating business ownership: $e');
    }
  }

  Future<bool> _reauthenticateUser(User user) async {
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'password';

    if (providerId == 'google.com') {
      try {
        await GoogleSignInService.reAuthenticateWithGoogle();
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Re-authentication failed: $e')),
          );
        }
        return false;
      }
    } else {
      // Default to password re-authentication
      return await _showPasswordReauthDialog(user);
    }
  }

  Future<bool> _showPasswordReauthDialog(User user) async {
    final TextEditingController passwordController = TextEditingController();
    bool reAuthed = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Re-authenticate',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'For security reasons, please enter your password to confirm account deletion.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Password',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
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
            onPressed: () async {
              try {
                final AuthCredential credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passwordController.text,
                );
                await user.reauthenticateWithCredential(credential);
                reAuthed = true;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Re-authentication failed: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );

    return reAuthed;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoadingAdmin
          ? const Center(child: CircularProgressIndicator(color: primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Settings Section
                _buildSectionCard(
                  title: 'Account',
                  children: [
                    _buildListTile(
                      icon: Icons.person_outline,
                      title: 'Edit Profile',
                      onTap: _showEditProfileDialog,
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: user != null
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        final data = snapshot.data?.data();
                        final accountType =
                            data?['accountType'] as String? ?? 'user';
                        final isAdmin = data?['isAdmin'] == true;

                        return _buildListTile(
                          icon: Icons.badge_outlined,
                          title: 'Account Type',
                          subtitle: isAdmin
                              ? 'Admin Account'
                              : (accountType == 'business'
                                  ? 'Business Account'
                                  : 'User Account'),
                          showChevron: false,
                        );
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    _buildListTile(
                      icon: Icons.logout,
                      title: 'Log Out',
                      onTap: _showLogoutDialog,
                    ),
                  ],
                ),
                
                // Hide all other containers if Admin
                if (!_isAdmin) ...[
                  const SizedBox(height: 16),

                  // Preferences Section
                  _buildSectionCard(
                    title: 'Privacy & Preferences',
                    children: [
                      _buildListTile(
                        icon: Icons.interests,
                        title: 'My Interests',
                        subtitle: 'Update your cafe preferences',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InterestSelectionScreen(
                                isEditing: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildSwitchTile(
                        icon: Icons
                            .notifications_active_outlined, // Changed icon slightly to differentiate
                        title: 'Push Notifications',
                        subtitle: 'Receive alerts about new cafes',
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // App Information Section
                  _buildSectionCard(
                    title: 'App Information',
                    children: [
                      _buildListTile(
                        icon: Icons.info_outline,
                        title: 'About',
                        subtitle: 'Version 1.0.0',
                        onTap: () => _showAboutDialog(),
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildListTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildListTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TermsOfServiceScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildListTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HelpSupportScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Danger Zone Section
                  _buildSectionCard(
                    title: 'Danger Zone',
                    titleColor: Colors.redAccent,
                    borderColor: Colors.redAccent.withValues(alpha: 0.3),
                    children: [
                      _buildListTile(
                        icon: Icons.delete_forever,
                        title: 'Delete Account',
                        onTap: _showDeleteAccountDialog,
                        titleColor: Colors.redAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ==========================================================
                  // 🧪 DEFENSE DEBUG SECTION (Live Testing)
                  // ==========================================================
                  _buildSectionCard(
                    title: 'Defense Verification',
                    titleColor: Colors.amber,
                    borderColor: Colors.amber.withOpacity(0.3),
                    children: [
                      _buildListTile(
                        icon: Icons.notifications_none,
                        title: 'Test Rec (Score: 0.6)',
                        subtitle: 'Expected: Silent Notification',
                        onTap: () async {
                          await NotificationService().createRecommendationNotification(
                            'test_shop_1',
                            'Modern Brew (Test)',
                            0.6,
                            null,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sent 0.6 Recommendation (No Sound)')),
                            );
                          }
                        },
                      ),
                      const Divider(color: Colors.white12, height: 1),
                      _buildListTile(
                        icon: Icons.notifications_active,
                        title: 'Test Alert (Score: 0.8)',
                        subtitle: 'Expected: Auditory Perfect Match',
                        titleColor: Colors.amber,
                        onTap: () async {
                          await NotificationService().createRecommendationNotification(
                            'test_shop_2',
                            'Elite Coffee (Test)',
                            0.8,
                            null,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sent 0.8 Perfect Match (Sound Triggered)'),
                                backgroundColor: Colors.amber,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
              'CoFi',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            const Text(
              'CoFi is your ultimate cafe discovery companion. Explore local cafes, log your visits, write reviews, and connect with the coffee community.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Developed with ☕ by the CoFi Team',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    Color? titleColor,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextWidget(
              text: title,
              fontSize: 14,
              color: titleColor ?? Colors.white54,
              isBold: true,
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool showChevron = true,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white70, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            )
          : null,
      trailing: showChevron && onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.white38)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: primary,
      ),
    );
  }
}
