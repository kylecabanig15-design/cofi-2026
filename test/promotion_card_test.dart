import 'package:cofi/models/promotion_model.dart';
import 'package:cofi/widgets/promotion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('special offer opens a structured details sheet', (tester) async {
    final promotion = Promotion(
      id: 'promotion-1',
      shopId: 'shop-1',
      shopName: 'Daily Grind',
      title: 'Coffee and pastry pairing',
      offer: '20% off',
      description: 'Choose any handcrafted coffee with a fresh pastry.',
      terms: 'Valid for one redemption per guest.',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
      status: 'published',
      imageUrl: '',
      logoUrl: '',
      imageSource: 'promotion',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 230,
            child: PromotionCard(promotion: promotion),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Coffee and pastry pairing'));
    await tester.pumpAndSettle();

    expect(find.text('Offered by'), findsOneWidget);
    expect(find.text('Offer period'), findsOneWidget);
    expect(find.text('Aug 1 – Aug 31, 2026'), findsOneWidget);
    expect(find.text('About this offer'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('Before you go'), findsOneWidget);
    expect(find.text('How to use this offer'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Got it'), findsOneWidget);
  });

  testWidgets('special offer details can be dragged down to dismiss',
      (tester) async {
    final promotion = Promotion(
      id: 'promotion-2',
      shopId: 'shop-1',
      shopName: 'Daily Grind',
      title: 'Weekend coffee flight',
      offer: 'Save 15%',
      description: 'Try three rotating coffee selections.',
      terms: '',
      startDate: null,
      endDate: null,
      status: 'published',
      imageUrl: '',
      logoUrl: '',
      imageSource: 'promotion',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 230,
            child: PromotionCard(promotion: promotion),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Weekend coffee flight'));
    await tester.pumpAndSettle();
    expect(find.text('Offered by'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();

    expect(find.text('Offered by'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
