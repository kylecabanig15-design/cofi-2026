import 'package:cofi/services/google_sign_in_service.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cofi/widgets/premium_background.dart';

class InterestSelectionScreen extends StatefulWidget {
  final bool isEditing;
  const InterestSelectionScreen({super.key, this.isEditing = false});

  @override
  State<InterestSelectionScreen> createState() =>
      _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingInterests();
    }
  }

  Future<void> _loadExistingInterests() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data();
      final userInterests =
          (data?['interests'] as List?)?.cast<String>() ?? [];
      
      setState(() {
        for (var interest in userInterests) {
          if (interests.containsKey(interest)) {
            interests[interest] = true;
          }
        }
      });
    }
  }

  Map<String, bool> interests = {
    // Drink Types
    'Espresso': false,
    'Flat White': false,
    'Spanish Latte': false,
    'Vietnamese Coffee': false,
    'Cold Brew': false,
    'Pour Over': false,
    'Specialty Coffee': false,
    'Matcha Drinks': false,

    // Food
    'Pastries': false,

    // Activities
    'Work-Friendly (Wi-Fi + outlets)': false,
    'Study Sessions': false,
    'Night Café (Open Late)': false,
    'Family Friendly': false,

    // Convenience
    'Pet-Friendly': false,
    'Parking Available': false,

    // Vibe
    'Minimalist / Modern': false,
    'Rustic / Cozy': false,
    'Outdoor / Garden': false,
    'Seaside / Scenic': false,
    'Artsy / Aesthetic': false,
    'Instagrammable': false,
  };

  // Grouped Interests Mapping
  final Map<String, List<String>> _interestGroups = {
    '☕ Drink Types': [
      'Espresso',
      'Flat White',
      'Spanish Latte',
      'Vietnamese Coffee',
      'Cold Brew',
      'Pour Over',
      'Specialty Coffee',
      'Matcha Drinks',
    ],
    '🥐 Food Options': [
      'Pastries',
    ],
    '🧑‍💻 Use Case / Activities': [
      'Work-Friendly (Wi-Fi + outlets)',
      'Study Sessions',
      'Night Café (Open Late)',
      'Family Friendly',
    ],
    '🐾 Accessibility & Convenience': [
      'Pet-Friendly',
      'Parking Available',
    ],
    '🎨 Vibe / Ambience': [
      'Minimalist / Modern',
      'Rustic / Cozy',
      'Outdoor / Garden',
      'Seaside / Scenic',
      'Artsy / Aesthetic',
      'Instagrammable',
    ],
  };

  // Map each interest to a high-quality professional image
  Map<String, String> interestImages = {
    'Specialty Coffee':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800',
    'Matcha Drinks':
        'https://images.unsplash.com/photo-1515823064-d6e0c04616a7?w=800',
    'Espresso':
        'https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=800',
    'Spanish Latte':
        'https://images.unsplash.com/photo-1516195700843-20a1d5e93d2d?w=800',
    'Vietnamese Coffee':
        'https://images.unsplash.com/photo-1671014594641-262cc4b9a16d?w=800',
    'Cold Brew':
        'https://images.unsplash.com/photo-1549652127-2e5e59e86a7a?w=800',
    'Pour Over':
        'https://plus.unsplash.com/premium_photo-1667621220863-3fa666433b5d?w=800',
    'Flat White':
        'https://images.unsplash.com/photo-1727080409436-356bdc609899?w=800',
    'Pastries':
        'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800',
    'Work-Friendly (Wi-Fi + outlets)':
        'https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=800',
    'Pet-Friendly':
        'https://images.unsplash.com/photo-1537151608828-ea2b11777ee8?w=800',
    'Parking Available':
        'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=800',
    'Family Friendly':
        'https://images.unsplash.com/photo-1540479859555-17af45c78602?w=800',
    'Study Sessions': 
        'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800',
    'Night Café (Open Late)':
        'https://images.unsplash.com/photo-1511018556340-d16986a1c194?w=800',
    'Minimalist / Modern': 
        'https://images.unsplash.com/photo-1494438639946-1ebd1d20bf85?w=800',
    'Rustic / Cozy': 
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=800',
    'Outdoor / Garden':
        'https://images.unsplash.com/photo-1763301331567-21c465b66e02?w=800',
    'Seaside / Scenic': 
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?w=800',
    'Artsy / Aesthetic':
        'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=800',
    'Instagrammable':
        'https://images.unsplash.com/photo-1559925393-8be0ec4767c8?w=800',
  };

  final String _fallbackImageUrl = 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800';

  bool _isLoading = false;

  List<String> _getSelectedInterests() {
    return interests.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _saveInterestsAndContinue() async {
    // Validate at least one interest is selected
    if (_getSelectedInterests().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one interest')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check if email is verified before proceeding (skip for Google users)
        final isGoogleUser =
            user.providerData.any((p) => p.providerId == 'google.com');
        if (!isGoogleUser) {
          await user.reload();
          if (!user.emailVerified) {
            setState(() => _isLoading = false);
            _showEmailVerificationDialog();
            return;
          }
        }

        // Show success confirmation FIRST
        setState(() => _isLoading = false);
        await _showSuccessConfirmation();

        if (!mounted) return;

        // NOW save interests to Firestore
        // This will trigger the AuthGate to navigate to HomeScreen
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'interests': _getSelectedInterests(),
          'emailVerified': user.emailVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // If we are editing, just pop back
        if (widget.isEditing) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Interests updated successfully!')),
            );
            Navigator.of(context).pop();
          }
          return;
        }
        
        // If onboarding, continue
        // Ensure we check if user needs to select commitment or account type
        // But for now, let auth_gate handle routing
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error saving interests. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessConfirmation() async {
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated checkmark
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: primary, width: 3),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: primary,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Success message
                const Text(
                  'Interests Saved Successfully!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your preferences have been saved.\nRedirecting to Explore...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Loading indicator
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Wait 2 seconds for the user to see the success message
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Dismiss the dialog
      Navigator.of(context).pop();
    }
  }

  void _showEmailVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.email_outlined, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            TextWidget(
              text: 'Email Verification Required',
              fontSize: 20,
              color: Colors.white,
              isBold: true,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextWidget(
              text: 'You must verify your email before saving interests.',
              fontSize: 16,
              color: Colors.white,
              align: TextAlign.left,
            ),
            const SizedBox(height: 12),
            TextWidget(
              text:
                  'Please check your inbox and click the verification link we sent you.',
              fontSize: 14,
              color: Colors.white70,
              align: TextAlign.left,
            ),
            const SizedBox(height: 8),
            TextWidget(
              text: 'If you didn\'t receive the email, check your spam folder.',
              fontSize: 14,
              color: Colors.white70,
              align: TextAlign.left,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isLoading = false);
            },
            child: TextWidget(
              text: 'I\'ll check later',
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resendVerificationEmail();
            },
            child: TextWidget(
              text: 'Resend email',
              fontSize: 14,
              color: primary,
              isBold: true,
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _checkVerificationStatus();
            },
            child: TextWidget(
              text: 'I\'ve verified',
              fontSize: 14,
              color: Colors.green,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Verification email sent! Please check your inbox.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          // Email is now verified, proceed with saving interests
          await _saveInterestsAndContinue();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Email not verified yet. Please check your inbox and try again.'),
                backgroundColor: Colors.orange,
              ),
            );
            _showEmailVerificationDialog();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to check verification status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int selectedCount = _getSelectedInterests().length;

    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        leading: widget.isEditing
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  // SAFE NAVIGATION: Check if we can pop first.
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    // Only sign out if we can't go back (root) and user wants to abort
                    // Or maybe just minimize app/do nothing?
                    // For now, let's just confirm with the user
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Go back to login?', style: TextStyle(color: Colors.white)),
                        actions: [
                          TextButton(onPressed: ()=>Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: ()=>Navigator.pop(context, true), child: const Text('Yes', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (shouldLogout == true) {
                      await GoogleSignInService.signOut();
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
              ),
        actions: [
          if (!widget.isEditing)
            TextButton(
              onPressed: _isLoading ? null : () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  setState(() => _isLoading = true);
                  
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'interests': [], // Empty interests = skipped
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    
                    if (mounted) {
                      // Show quick confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Skipped! You can set interests later in settings.'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                      
                      // AuthGate will now redirect to HomeScreen
                      // since interests field exists (even if empty)
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
              child: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : const Text('Skip', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: TextWidget(
                  text: widget.isEditing 
                      ? 'Update Your Interests' 
                      : 'Choose Your Interests',
                  fontSize: 24,
                  color: Colors.white,
                  isBold: true,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextWidget(
                  text: widget.isEditing
                      ? 'Select the types of cafes you prefer'
                      : 'Select at least one to get personalized recommendations',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: _interestGroups.entries.expand((entry) {
                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 16),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            String interest = entry.value[index];
                            bool isSelected = interests[interest]!;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  interests[interest] = !interests[interest]!;
                                });
                              },
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                transform: Matrix4.identity()
                                  ..scale(isSelected ? 0.98 : 1.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? primary : Colors.white10,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: primary.withOpacity(0.3),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // Image
                                    Positioned.fill(
                                      child: CachedNetworkImage(
                                        imageUrl: interestImages[interest] ?? _fallbackImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation(Colors.white24),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Image.network(
                                          _fallbackImageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    // Overlay Gradient
                                    Positioned.fill(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              isSelected
                                                  ? primary.withOpacity(0.8)
                                                  : Colors.black.withOpacity(0.8),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Content
                                    Positioned(
                                      bottom: 12,
                                      left: 12,
                                      right: 12,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.2),
                                                    blurRadius: 4,
                                                  )
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.check_rounded,
                                                color: primary,
                                                size: 14,
                                              ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            interest,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: entry.value.length,
                        ),
                      ),
                    ];
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: _isLoading ? null : _saveInterestsAndContinue,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : TextWidget(
                            text:
                                widget.isEditing ? 'Save Changes' : 'Continue',
                            fontSize: 18,
                            color: Colors.white,
                            isBold: true,
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
}
