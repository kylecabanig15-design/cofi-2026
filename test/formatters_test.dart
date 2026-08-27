import 'package:cofi/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('job salary formatting', () {
    test('adds the peso symbol and thousands separators', () {
      expect(formatPhilippinePeso('15000'), '₱15,000');
    });

    test('formats both sides of a salary range', () {
      expect(formatPhilippinePeso('12000-18000'), '₱12,000–₱18,000');
    });

    test('adds a normalized payment period', () {
      expect(formatJobSalary('15000', 'Per Month'), '₱15,000 / month');
    });

    test('keeps descriptive values readable', () {
      expect(formatJobSalary('Negotiable', ''), 'Negotiable');
      expect(formatJobSalary(null, 'Per Hour'), 'Salary TBD');
    });

    test('adds commas while typing a job rate', () {
      const formatter = ThousandsSeparatorInputFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '100000'),
      );

      expect(result.text, '100,000');
      expect(result.selection.baseOffset, 7);
    });

    test('formats an existing rate for editing', () {
      expect(formatNumberWithCommas('1000'), '1,000');
      expect(formatNumberWithCommas('10000'), '10,000');
      expect(formatNumberWithCommas('100000'), '100,000');
    });
  });
}
