import 'package:cofi/features/business/widgets/business_workspace_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner controls share one visual and interaction system',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BusinessWorkspaceTheme(
          child: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    BusinessSectionLabel(
                      step: '01',
                      title: 'Role basics',
                      description: 'Describe the opening clearly.',
                    ),
                    TextField(
                      decoration: InputDecoration(labelText: 'Role name'),
                    ),
                    SizedBox(height: 16),
                    BusinessMetricsStrip(
                      items: [
                        BusinessMetricData('4', 'Open roles'),
                        BusinessMetricData('2', 'In review'),
                        BusinessMetricData('1', 'Paused'),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: null,
                            child: Text('Save draft'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: null,
                            child: Text('Publish'),
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

    expect(find.text('Role basics'), findsOneWidget);
    expect(find.text('Open roles'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary actions inherit the destination accent', (tester) async {
    late ThemeData workspaceTheme;

    await tester.pumpWidget(
      MaterialApp(
        home: BusinessWorkspaceTheme(
          accentColor: Colors.amberAccent,
          child: Builder(
            builder: (context) {
              workspaceTheme = Theme.of(context);
              return Scaffold(
                body: FilledButton(
                  onPressed: () {},
                  child: const Text('Publish offer'),
                ),
              );
            },
          ),
        ),
      ),
    );

    final expectedFill = BusinessWorkspaceColors.actionFill(Colors.amberAccent);
    final resolvedFill = workspaceTheme
        .filledButtonTheme.style!.backgroundColor!
        .resolve(<WidgetState>{});

    expect(workspaceTheme.colorScheme.secondary, Colors.amberAccent);
    expect(workspaceTheme.colorScheme.primary, expectedFill);
    expect(resolvedFill, expectedFill);
    expect(resolvedFill, isNot(BusinessWorkspaceColors.action));
    expect(resolvedFill!.computeLuminance(), lessThanOrEqualTo(.18));
    expect(tester.takeException(), isNull);
  });
}
