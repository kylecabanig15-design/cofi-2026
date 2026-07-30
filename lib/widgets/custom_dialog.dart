import 'package:flutter/material.dart';
import 'package:cofi/utils/colors.dart';
import 'package:cofi/widgets/text_widget.dart';
import 'dart:ui';

class CustomDialog {
  static Future<T?> showConfirmation<T>({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    bool isDestructive = false,
    required VoidCallback onConfirm,
    IconData? icon,
  }) {
    final themeColor = isDestructive ? Colors.redAccent : primary;
    final displayIcon = icon ?? (isDestructive ? Icons.warning_rounded : Icons.help_outline_rounded);

    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(displayIcon, color: themeColor, size: 32),
                ),
                const SizedBox(height: 20),
                TextWidget(
                  text: title,
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextWidget(
                  text: message,
                  fontSize: 14,
                  color: Colors.grey[400],
                  align: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: TextWidget(
                          text: cancelText,
                          fontSize: 16,
                          color: Colors.white70,
                          isBold: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onConfirm();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: TextWidget(
                          text: confirmText,
                          fontSize: 16,
                          color: Colors.white,
                          isBold: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'Got it',
    IconData icon = Icons.info_outline,
    Color iconColor = primary,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(height: 20),
                TextWidget(
                  text: title,
                  fontSize: 20,
                  color: Colors.white,
                  isBold: true,
                  align: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextWidget(
                  text: message,
                  fontSize: 14,
                  color: Colors.grey[400],
                  align: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: TextWidget(
                      text: buttonText,
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
    );
  }

  static void showLoading(BuildContext context, {String message = 'Please wait...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: primary),
                    const SizedBox(height: 20),
                    TextWidget(
                      text: message,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
