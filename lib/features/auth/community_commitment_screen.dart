import 'package:cofi/services/google_sign_in_service.dart';
import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cofi/utils/auth_error_handler.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/custom_toast.dart';

class CommunityCommitmentScreen extends StatefulWidget {
  const CommunityCommitmentScreen({super.key});

  @override
  State<CommunityCommitmentScreen> createState() =>
      _CommunityCommitmentScreenState();
}

class _CommunityCommitmentScreenState extends State<CommunityCommitmentScreen> {
  bool _isLoading = false;
  bool _isCheckingVerification = false;

  Future<void> _agreeAndContinue() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be signed in to continue.')),
          );
        }
        return;
      }

      // Check if email is verified before proceeding
      await user.reload();
      if (!user.emailVerified) {
        if (mounted) {
          _showEmailVerificationDialog();
        }
        return;
      }

      // Update commitment in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'commitment': true,
        'emailVerified': true, // Update email verification status
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // No manual navigation needed - AuthGate will handle it
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to update commitment. ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              text: 'You must verify your email before continuing.',
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
            onPressed: () async {
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
    setState(() => _isCheckingVerification = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (mounted) {
          CustomToast.showSuccess(
            context,
            'Check your inbox and spam folder for the verification link.',
            title: 'Verification email sent',
          );
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        CustomToast.showError(
          context,
          AuthErrorHandler.getFriendlyMessage(e),
          title: 'Email not sent',
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isCheckingVerification = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          // Email is now verified, proceed with commitment
          await _agreeAndContinue();
        } else {
          if (mounted) {
            CustomToast.showWarning(
              context,
              'Open the verification link in your inbox, then try again.',
              title: 'Email not verified',
            );
            _showEmailVerificationDialog();
          }
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        CustomToast.showError(
          context,
          AuthErrorHandler.getFriendlyMessage(e),
          title: 'Verification check failed',
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingVerification = false);
    }
  }

  // This screen is rendered inline as AuthGate content (bottom-most route),
  // so Navigator.pop() pops nothing and traps the user. Declining signs out
  // instead, which routes back to login via AuthGate's auth stream.
  Future<void> _declineAndSignOut() async {
    try {
      await GoogleSignInService.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        CustomToast.showError(
          context,
          'We could not sign you out. Please try again.',
          title: 'Sign-out failed',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _declineAndSignOut,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              TextWidget(
                text: 'Our community commitment',
                fontSize: 13,
                color: Colors.white70,
                isBold: false,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextWidget(
                text: 'CoFi is a cafe community\nwhere anyone can belong',
                fontSize: 24,
                color: Colors.white,
                isBold: true,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              TextWidget(
                text:
                    "To ensure this, we're asking you to commit to the following:",
                fontSize: 14.5,
                color: Colors.white,
                isBold: false,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              TextWidget(
                text:
                    'I agree to treat everyone in the Cofi community – regardless of their race, religion, national origin, ethnicity, skin color, disability, sex, gender identity, sexual orientation or age – with respect, and without judgment or bias.',
                fontSize: 14.5,
                color: Colors.white,
                isBold: false,
                maxLines: 8,
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: (_isLoading || _isCheckingVerification)
                    ? null
                    : _agreeAndContinue,
                child: (_isLoading || _isCheckingVerification)
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : TextWidget(
                        text: 'Agree and Continue',
                        fontSize: 17,
                        color: Colors.white,
                        isBold: true,
                        align: TextAlign.center,
                      ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF222222),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _declineAndSignOut,
                child: TextWidget(
                  text: 'Decline',
                  fontSize: 17,
                  color: Colors.white,
                  isBold: true,
                  align: TextAlign.center,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
