import 'package:flutter/material.dart';

enum ToastType { success, error, warning, info }

/// Product-wide transient feedback.
///
/// Use this instead of constructing a raw [SnackBar]. It gives every action a
/// semantic state, consistent wording hierarchy, and an accessible live region.
class CustomToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    showFromMessenger(
      messenger,
      message,
      type: type,
      duration: duration,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Safe for async callbacks that captured the messenger before awaiting.
  static void showFromMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final visual = _ToastVisual.forType(type);
    final resolvedTitle = title ?? visual.title;

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      padding: EdgeInsets.zero,
      duration: duration,
      action: actionLabel != null && onAction != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: visual.accent,
              onPressed: onAction,
            )
          : null,
      content: Semantics(
        liveRegion: true,
        label: '$resolvedTitle. $message',
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF211F1D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: visual.accent.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(visual.icon, color: visual.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFFC9C4C0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: messenger.hideCurrentSnackBar,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String message,
      {String? title}) {
    show(context, message, type: ToastType.success, title: title);
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(
      context,
      message,
      type: ToastType.error,
      title: title,
      duration: const Duration(seconds: 5),
    );
  }

  static void showWarning(BuildContext context, String message,
      {String? title}) {
    show(context, message, type: ToastType.warning, title: title);
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.info, title: title);
  }
}

class _ToastVisual {
  const _ToastVisual(this.title, this.icon, this.accent);

  final String title;
  final IconData icon;
  final Color accent;

  factory _ToastVisual.forType(ToastType type) {
    return switch (type) {
      ToastType.success => const _ToastVisual(
          'Done',
          Icons.check_rounded,
          Color(0xFF69D39B),
        ),
      ToastType.error => const _ToastVisual(
          'Something went wrong',
          Icons.error_outline_rounded,
          Color(0xFFFF7676),
        ),
      ToastType.warning => const _ToastVisual(
          'Check this first',
          Icons.warning_amber_rounded,
          Color(0xFFFFBE5C),
        ),
      ToastType.info => const _ToastVisual(
          'Heads up',
          Icons.info_outline_rounded,
          Color(0xFFD69A77),
        ),
    };
  }
}
