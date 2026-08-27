import 'dart:ui';

import 'package:cofi/utils/colors.dart';
import 'package:flutter/material.dart';

/// Product-wide dialogs for decisions, information, and blocking progress.
abstract final class CustomDialog {
  static const _surface = Color(0xFF1B1917);
  static const _line = Color(0xFF3C3733);
  static const _body = Color(0xFFC7C1BC);
  static const _danger = Color(0xFFFF6B6B);
  static const _accent = Color(0xFFD69A77);

  /// Preferred confirmation API. Returns true only when the user explicitly
  /// chooses the primary action.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final accentColor = isDestructive ? _danger : _accent;
    final displayIcon = icon ??
        (isDestructive
            ? Icons.delete_outline_rounded
            : Icons.help_outline_rounded);

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.28),
                            ),
                          ),
                          child:
                              Icon(displayIcon, color: accentColor, size: 25),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.25,
                                  height: 1.2,
                                ),
                              ),
                              if (isDestructive) ...[
                                const SizedBox(height: 5),
                                const Text(
                                  'THIS CANNOT BE UNDONE',
                                  style: TextStyle(
                                    color: _danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.05,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      style: const TextStyle(
                        color: _body,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: _line),
                              minimumSize: const Size(0, 50),
                            ),
                            child: Text(cancelText),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: isDestructive
                                  ? const Color(0xFFB8343D)
                                  : primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 50),
                            ),
                            child: Text(confirmText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return result ?? false;
  }

  /// Backwards-compatible callback API for existing flows.
  static Future<T?> showConfirmation<T>({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    bool isDestructive = false,
    required VoidCallback onConfirm,
    IconData? icon,
  }) async {
    final confirmed = await confirm(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
      icon: icon,
    );
    if (confirmed) onConfirm();
    return null;
  }

  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'Got it',
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = _accent,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 26),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(buttonText),
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

  static void showLoading(
    BuildContext context, {
    String message = 'Please wait…',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
