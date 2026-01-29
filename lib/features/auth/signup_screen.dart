import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/auth_error_handler.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/button_widget.dart';
import 'package:cofi/features/auth/login_screen.dart';
import 'package:cofi/features/auth/interest_selection_screen.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/premium_background.dart';

class SignupScreen extends StatefulWidget {
  final String accountType; // 'user' or 'business'
  final bool isGoogleSignUp; // whether this is from Google Sign-In

  const SignupScreen({
    super.key,
    required this.accountType,
    this.isGoogleSignUp = false,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _obscurePassword = true;
  final TextEditingController _birthdayController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Notification preferences
  bool _emailNotifications = true;
  bool _eventNotifications = true;
  bool _jobNotifications = false;
  bool _promoNotifications = false;

  @override
  void initState() {
    super.initState();
    // For Google Sign-Up, pre-fill email from Firebase
    if (widget.isGoogleSignUp) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _emailController.text = user.email ?? '';
      }
    }
  }

  @override
  void dispose() {
    _birthdayController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final birthday = _birthdayController.text.trim();

      // For Google Sign-Up, just update the existing user's data
      if (widget.isGoogleSignUp) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName('$first $last');

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'firstName': first,
            'lastName': last,
            'birthday': birthday,
            'displayName': '$first $last',
            'accountType': widget.accountType,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // For regular email/password sign-up
        final pwd = _passwordController.text;
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pwd);
        await cred.user?.updateDisplayName('$first $last');

        // Send email verification
        await cred.user?.sendEmailVerification();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'firstName': first,
          'lastName': last,
          'email': email,
          'birthday': birthday,
          'commitment': false,
          'uid': cred.user!.uid,
          'displayName': '$first $last',
          'address': 'Davao City',
          'bookmarks': [],
          'visited': [],
          'reviews': [],
          'accountType': widget.accountType,
          'emailVerified': false, // Track email verification status
          'isAdmin': false, // NEW: Explicitly initialize
          'createdAt': FieldValue.serverTimestamp(),
          // Notification preferences
          'notificationPreferences': {
            'emailNotifications': _emailNotifications,
            'eventNotifications': _eventNotifications,
            'jobNotifications': _jobNotifications,
            'promoNotifications': _promoNotifications,
          },
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      if (!mounted) return;

      // For Google users, just navigate back (AuthGate will handle routing to interests)
      if (widget.isGoogleSignUp) {
        Navigator.of(context).pop();
      } else {
        // Show verification message and navigate to community commitment screen
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: TextWidget(
              text: 'Verification Email Sent',
              fontSize: 20,
              color: Colors.white,
              isBold: true,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextWidget(
                  text:
                      'We\'ve sent a verification email to $email. Please check your inbox and verify your email before logging in.',
                  fontSize: 14,
                  color: Colors.white70,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextWidget(
                  text:
                      'Note: You must verify your email before you can log in.',
                  fontSize: 12,
                  color: Colors.orange[400],
                  isBold: true,
                  align: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: TextWidget(
                  text: 'Got it',
                  fontSize: 16,
                  color: primary,
                  isBold: true,
                ),
              ),
            ],
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthErrorHandler.getFriendlyMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Finish signing up',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _buildTextField(
                    'First name',
                    controller: _firstNameController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Last name',
                    controller: _lastNameController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Birthday (mm/dd/yyyy)',
                    hint:
                        'To sign up, you need to be at least 18. Your birthday won’t be shared with other people who use Cofi.',
                    suffixIcon: const Icon(Icons.arrow_drop_down,
                        color: Colors.white54),
                    readOnly: true,
                    controller: _birthdayController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                    onTap: () async {
                      FocusScope.of(context).requestFocus(FocusNode());
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(DateTime.now().year - 18, 1, 1),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(DateTime.now().year - 18, 12, 31),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFFDF2C2C),
                                surface: Color(0xFF222222),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        _birthdayController.text =
                            DateFormat('MMM dd, yyyy').format(picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: widget.isGoogleSignUp,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  if (widget.isGoogleSignUp) ...[
                    const SizedBox(height: 4),
                    TextWidget(
                      text:
                          'Since you\'re using Google Sign-In, your email is managed by Google and cannot be changed here.',
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (!widget.isGoogleSignUp)
                    _buildTextField(
                      'Password',
                      controller: _passwordController,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  _buildNotificationPreferences(),
                  const SizedBox(height: 18),
                  _buildDisclaimer(),
                  const SizedBox(height: 20),
                  _buildButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTextField(
    String label, {
    String? hint,
    Widget? suffixIcon,
    bool obscureText = false,
    bool readOnly = false,
    String? initialValue,
    TextEditingController? controller,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 15,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          obscureText: obscureText,
          readOnly: readOnly,
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(color: Colors.grey[400]),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF222222),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
            suffixIcon: suffixIcon,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
          ),
          onTap: onTap,
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextWidget(
        text:
            'By selecting Agree and continue, I agree to appcourse Terms of Service, Payments Terms of Service and Nondiscrimination Policy and acknowledge the Privacy Policy.',
        fontSize: 12.5,
        color: Colors.white70,
        align: TextAlign.left,
        maxLines: 4,
      ),
    );
  }

  Widget _buildButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _isLoading ? null : _signUp,
      child: _isLoading
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : TextWidget(
              text: 'Agree and continue',
              fontSize: 17,
              color: Colors.white,
              isBold: true,
              align: TextAlign.center,
            ),
    );
  }

  Widget _buildNotificationPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: 'Notification Preferences',
          fontSize: 16,
          color: Colors.white,
          isBold: true,
        ),
        const SizedBox(height: 12),
        TextWidget(
          text: 'Choose the types of notifications you\'d like to receive:',
          fontSize: 14,
          color: Colors.white70,
        ),
        const SizedBox(height: 16),

        // Email Notifications
        _buildNotificationToggle(
          'Email Notifications',
          'Receive important account updates via email',
          _emailNotifications,
          (value) => setState(() => _emailNotifications = value),
        ),
        const SizedBox(height: 12),

        // Event Notifications
        _buildNotificationToggle(
          'Event Notifications',
          'Get notified about coffee events and meetups',
          _eventNotifications,
          (value) => setState(() => _eventNotifications = value),
        ),
        const SizedBox(height: 12),

        // Job Notifications
        _buildNotificationToggle(
          'Job Notifications',
          'Receive alerts about new job opportunities at coffee shops',
          _jobNotifications,
          (value) => setState(() => _jobNotifications = value),
        ),
        const SizedBox(height: 12),

        // Promotional Notifications
        _buildNotificationToggle(
          'Promotional Notifications',
          'Get updates about special offers and new features',
          _promoNotifications,
          (value) => setState(() => _promoNotifications = value),
        ),
      ],
    );
  }

  Widget _buildNotificationToggle(
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: title,
                      fontSize: 15,
                      color: Colors.white,
                      isBold: true,
                    ),
                    const SizedBox(height: 4),
                    TextWidget(
                      text: description,
                      fontSize: 13,
                      color: Colors.white70,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: primary,
                activeTrackColor: primary.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.grey[400],
                inactiveTrackColor: Colors.grey[700],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
