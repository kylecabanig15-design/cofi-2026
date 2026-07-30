import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'dart:ui';
import 'package:cofi/widgets/custom_toast.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Password Requirements State
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _validatePassword(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUppercase = value.contains(RegExp(r'[A-Z]'));
      _hasNumber = value.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = value.contains(RegExp(r'[!@#\$&*~_]'));
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_hasMinLength || !_hasUppercase || !_hasNumber || !_hasSpecialChar) {
      _showErrorSnackBar('Please meet all password requirements');
      return;
    }

    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      _showErrorSnackBar('New passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Re-authenticate first
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordCtrl.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordCtrl.text);

        if (!mounted) return;
        Navigator.pop(context);
        CustomToast.showSuccess(context, 'Password updated successfully! ✨');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to update password';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect current password';
      } else if (e.code == 'weak-password') {
        message = 'The new password is too weak';
      }
      _showErrorSnackBar(message);
    } catch (e) {
      _showErrorSnackBar('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    CustomToast.showError(context, message);
  }

  Widget _buildRequirement(String text, bool isMet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? Colors.green.withValues(alpha: 0.2) : Colors.grey[800],
              border: Border.all(
                color: isMet ? Colors.green : Colors.grey[700]!,
                width: 1,
              ),
            ),
            child: Icon(
              isMet ? Icons.check : Icons.close,
              size: 12,
              color: isMet ? Colors.green : Colors.grey[500],
            ),
          ),
          const SizedBox(width: 12),
          TextWidget(
            text: text,
            fontSize: 14,
            color: isMet ? Colors.white : Colors.grey[500],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextWidget(
          text: label,
          fontSize: 14,
          color: Colors.grey[400],
          isBold: true,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[900],
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primary, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey[500],
              ),
              onPressed: onToggleVisibility,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextWidget(
          text: 'Change Password',
          fontSize: 18,
          color: Colors.white,
          isBold: true,
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text: 'Secure Your Account',
                                fontSize: 16,
                                color: Colors.white,
                                isBold: true,
                              ),
                              const SizedBox(height: 4),
                              TextWidget(
                                text: 'Create a strong, unique password to keep your account safe.',
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    label: 'Current Password',
                    controller: _currentPasswordCtrl,
                    obscureText: _obscureCurrent,
                    onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'New Password',
                    controller: _newPasswordCtrl,
                    obscureText: _obscureNew,
                    onChanged: _validatePassword,
                    onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  const SizedBox(height: 20),
                  
                  // Password Requirements Panel
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[850]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextWidget(
                          text: 'Password Requirements',
                          fontSize: 14,
                          color: Colors.white,
                          isBold: true,
                        ),
                        const SizedBox(height: 16),
                        _buildRequirement('At least 8 characters', _hasMinLength),
                        _buildRequirement('At least one uppercase letter', _hasUppercase),
                        _buildRequirement('At least one number', _hasNumber),
                        _buildRequirement('At least one special character (!@#\$&*)', _hasSpecialChar),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Confirm New Password',
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  const SizedBox(height: 40),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        disabledBackgroundColor: primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : TextWidget(
                              text: 'Update Password',
                              fontSize: 16,
                              color: Colors.white,
                              isBold: true,
                            ),
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
}
