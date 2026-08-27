import 'package:cofi/utils/app_signals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interest changes do not masquerade as collaborative input changes', () {
    final recommendationBefore = recommendationVersion.value;
    final interestsBefore = interestsVersion.value;

    notifyInterestsChanged();

    expect(interestsVersion.value, interestsBefore + 1);
    expect(recommendationVersion.value, recommendationBefore);
  });

  test('rating-context changes do not trigger the interest-only signal', () {
    final recommendationBefore = recommendationVersion.value;
    final interestsBefore = interestsVersion.value;

    notifyRecommendationInputsChanged();

    expect(recommendationVersion.value, recommendationBefore + 1);
    expect(interestsVersion.value, interestsBefore);
  });
}
