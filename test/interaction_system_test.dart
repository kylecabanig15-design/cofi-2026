import 'package:cofi/utils/app_theme.dart';
import 'package:cofi/widgets/button_widget.dart';
import 'package:cofi/widgets/custom_dialog.dart';
import 'package:cofi/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('semantic feedback has a clear title, message, icon, and close',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => CustomToast.showSuccess(
                context,
                'Your changes are now visible.',
                title: 'Profile updated',
              ),
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Profile updated'), findsOneWidget);
    expect(find.text('Your changes are now visible.'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('destructive confirmation requires an explicit decision',
      (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await CustomDialog.confirm(
                  context: context,
                  title: 'Delete review?',
                  message: 'The review will be permanently removed.',
                  confirmText: 'Delete review',
                  isDestructive: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('THIS CANNOT BE UNDONE'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete review'), findsOneWidget);

    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared button communicates its loading state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ButtonWidget(
            label: 'Publish offer',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
