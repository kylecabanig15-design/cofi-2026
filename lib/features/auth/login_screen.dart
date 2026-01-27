import 'package:cofi/features/auth/account_type_selection_screen.dart';
import 'package:cofi/services/google_sign_in_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/button_widget.dart';
import 'dart:async'; // Added for TimeoutException
import 'package:cofi/features/auth/auth_gate.dart';
import 'package:cofi/utils/auth_error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleSigningIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Check if user is logged in but not verified
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerificationStatus();
    });
  }

  Future<void> _checkEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      // User is logged in but email is not verified
      await FirebaseAuth.instance.signOut(); // Sign them out
      if (mounted) {
        _showEmailVerificationRequiredDialog();
      }
    }
  }

  void _showEmailVerificationRequiredDialog() {
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
              text: 'You must verify your email before using the app.',
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
              text: 'If you didn\'t receive the email, check your spam folder. To get a new link, please try logging in again.',
              fontSize: 14,
              color: Colors.white70,
              align: TextAlign.left,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: TextWidget(
              text: 'Got it',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ).timeout(const Duration(seconds: 30));

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        await FirebaseAuth.instance.signOut(); // Sign out the user

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: TextWidget(
              text: 'Email Not Verified',
              fontSize: 20,
              color: Colors.white,
              isBold: true,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextWidget(
                  text:
                      'Please verify your email before logging in. Check your inbox for the verification email.',
                  fontSize: 14,
                  color: Colors.white70,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      await userCredential.user?.sendEmailVerification();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Verification email resent!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AuthErrorHandler.getFriendlyMessage(e))),
                        );
                      }
                    }
                  },
                  child: TextWidget(
                    text: 'Resend verification email',
                    fontSize: 14,
                    color: primary,
                    isBold: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: TextWidget(
                  text: 'OK',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
        return;
      }

      // Update email verification status in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({'emailVerified': true});

      if (!mounted) return;
      
      // No need to manually navigate. AuthGate listens to authStateChanges.
      // Just ensure we don't interfere.
      if (mounted) {
        // Optional: Show loading or just wait for stream
      }
    } on Exception catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Login Issue', AuthErrorHandler.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleSigningIn = true;
    });

    try {
      final userCredential = await GoogleSignInService.signInWithGoogle()
          .timeout(const Duration(seconds: 45));

      if (userCredential != null && mounted) {
        // Success
        await FirebaseAuth.instance.currentUser?.reload();
        if (mounted) {
           Navigator.of(context).pushReplacementNamed('/');
        }

      } else if (mounted && userCredential == null) {
        _showErrorDialog(
          context,
          'Sign In Failed',
          'Sign in cancelled or configuration error.\n\nPlease check your SHA-1 fingerprint in Firebase Console.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        _showErrorDialog(
          context,
          'Connection Timeout',
          'Google Sign In took too long. Please check your internet connection and try again.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Google Sign In Error', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSigningIn = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final forgotPasswordEmailController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: TextWidget(
            text: 'Reset Password',
            fontSize: 20,
            color: Colors.white,
            isBold: true,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextWidget(
                text:
                    'Enter your email address to receive a password reset link.',
                fontSize: 14,
                color: Colors.grey[400]!,
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: forgotPasswordEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: TextWidget(
                text: 'Cancel',
                fontSize: 14,
                color: Colors.grey[400]!,
              ),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = forgotPasswordEmailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter your email')),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      try {
                        await FirebaseAuth.instance
                            .sendPasswordResetEmail(email: email);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Password reset email sent!')),
                          );
                        }
                      } on Exception catch (e) {
                        setDialogState(() => isSending = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(AuthErrorHandler.getFriendlyMessage(e))),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
              ),
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : TextWidget(
                      text: 'Send',
                      fontSize: 14,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: TextWidget(
          text: title,
          fontSize: 18,
          color: Colors.redAccent,
          isBold: true,
        ),
        content: SingleChildScrollView(
          child: TextWidget(
            text: message,
            fontSize: 14,
            color: Colors.white,
            align: TextAlign.left,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: TextWidget(
              text: 'OK',
              fontSize: 16,
              color: primary,
              isBold: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 150,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Headline - Find Cafes you love
                  TextWidget(
                    text: 'Find Cafes',
                    fontSize: 48,
                    color: Colors.grey[400]!,
                    align: TextAlign.left,
                    isBold: true,
                  ),
                  TextWidget(
                    text: 'you love',
                    fontSize: 48,
                    color: Colors.grey[400]!,
                    align: TextAlign.left,
                    isBold: true,
                  ),
                  const SizedBox(height: 30),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email Field
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Password Field
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle:
                                      const TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Password is required';
                                  }
                                  if (v.length < 6) {
                                    return 'Minimum 6 characters';
                                  }
                                  return null;
                                },
                              )),
                        ),
                        const SizedBox(height: 10),

                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _showForgotPasswordDialog,
                            child: TextWidget(
                              text: "Forgot Password?",
                              fontSize: 14,
                              color: primary,
                              isBold: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Container(height: 1, color: Colors.grey[800]),

                  // Login Button
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ButtonWidget(
                      label: _isLoading ? 'Logging in...' : 'Login',
                      fontSize: 16,
                      color: primary,
                      textColor: Colors.white,
                      radius: 100,
                      onPressed: _isLoading ? () {} : () => _login(),
                    ),
                  ),

                  // Divider with "or"
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: Container(height: 1, color: Colors.grey[800])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextWidget(
                          text: 'or',
                          fontSize: 14,
                          color: Colors.grey[500]!,
                          align: TextAlign.center,
                        ),
                      ),
                      Expanded(
                          child: Container(height: 1, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Google Login Button
                  _buildGoogleSignInButton(),

                  // Sign Up Link
                  const SizedBox(height: 20),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextWidget(
                          text: "Don't have an account? ",
                          fontSize: 16,
                          color: Colors.grey[500]!,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AccountTypeSelectionScreen(),
                              ),
                            );
                          },
                          child: TextWidget(
                            decoration: TextDecoration.underline,
                            text: "Signup",
                            fontSize: 16,
                            color: Colors.white,
                            isBold: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _isGoogleSigningIn ? null : _handleGoogleSignIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: FaIcon(
                      FontAwesomeIcons.google,
                      color: Colors.red,
                      size: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextWidget(
                  text: _isGoogleSigningIn
                      ? 'Signing in...'
                      : 'Continue with Google',
                  fontSize: 16,
                  color: Colors.white,
                  align: TextAlign.center,
                  isBold: true,
                ),
                // Show loading indicator if signing in
                if (_isGoogleSigningIn)
                  const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
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
