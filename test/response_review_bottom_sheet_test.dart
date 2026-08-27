import 'package:cofi/features/business/response_review_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('response composer shows one label and one-image limit',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponseReviewBottomSheet(
            shopId: 'shop-1',
            reviewId: 'review-1',
            reviewText: 'Great coffee.',
            reviewAuthor: 'Guest',
            ownerName: 'Café Owner',
          ),
        ),
      ),
    );

    expect(find.text('Your response'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
    expect(find.text('1 max'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
