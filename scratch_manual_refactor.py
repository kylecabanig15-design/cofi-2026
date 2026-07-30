import os

replacements = {
    "lib/features/settings/settings_screen.dart": [
        (
            '''  void _showLogoutDialog() {
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
  }''',
            '''  void _showLogoutDialog() {
    CustomDialog.showConfirmation(
      context: context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmText: 'Log Out',
      isDestructive: true,
      icon: Icons.logout_outlined,
      onConfirm: () async {
        try {
          await GoogleSignInService.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } catch (e) {
          if (mounted) CustomToast.showError(context, 'Logout failed: $e');
        }
      },
    );
  }'''
        ),
        (
            '''        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );''',
            '''        CustomToast.showSuccess(context, 'Account deleted successfully');'''
        ),
        (
            '''        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthErrorHandler.getFriendlyMessage(e))),
        );''',
            '''        CustomToast.showError(context, AuthErrorHandler.getFriendlyMessage(e));'''
        ),
        (
            '''import 'package:cofi/features/settings/change_password_screen.dart';''',
            '''import 'package:cofi/features/settings/change_password_screen.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'package:cofi/widgets/custom_dialog.dart';'''
        )
    ],
    "lib/features/cafe/review_shop_screen.dart": [
        (
            '''      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Review submitted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));''',
            '''      CustomToast.showSuccess(context, 'Review submitted successfully!');
    } catch (e) {
      if (!mounted) return;
      CustomToast.showError(context, 'Failed: $e');'''
        ),
        (
            '''import 'package:cofi/widgets/text_widget.dart';''',
            '''import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/custom_toast.dart';'''
        )
    ],
    "lib/widgets/post_job_bottom_sheet.dart": [
        (
            '''      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job posted successfully!')),
      );''',
            '''      CustomToast.showSuccess(context, 'Job posted successfully!');'''
        ),
        (
            '''      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );''',
            '''      CustomToast.showError(context, 'Error: $e');'''
        ),
        (
            '''import 'package:cofi/widgets/text_widget.dart';''',
            '''import 'package:cofi/widgets/text_widget.dart';
import 'package:cofi/widgets/custom_toast.dart';'''
        )
    ]
}

def run():
    for filepath, reps in replacements.items():
        with open(filepath, 'r') as f:
            content = f.read()
        for old, new in reps:
            content = content.replace(old, new)
        with open(filepath, 'w') as f:
            f.write(content)
            print(f"Updated {filepath}")

if __name__ == '__main__':
    run()
