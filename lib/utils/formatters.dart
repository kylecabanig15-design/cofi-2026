import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

String formatAddress(String address) {
  if (address.isEmpty) return '—';

  // Clean up common extra parts
  final parts = address.split(',').map((e) => e.trim()).toList();

  // Requirement: Cap it at "Davao City"
  // If "Davao City" is present, we only show parts up to "Davao City"
  int davaoIndex = -1;
  for (int i = 0; i < parts.length; i++) {
    if (parts[i].toLowerCase().contains('davao city')) {
      davaoIndex = i;
      break;
    }
  }

  if (davaoIndex != -1) {
    // Show everything before and including Davao City
    final relevantParts = parts.sublist(0, davaoIndex + 1);
    return relevantParts.join(', ');
  }

  // Fallback: Show first two parts if available
  if (parts.length > 1) {
    return "${parts[0]}, ${parts[1]}";
  }

  return address;
}

/// Formats a job rate as Philippine pesos without corrupting descriptive
/// values such as "Negotiable". Numeric ranges are formatted on both ends.
String formatPhilippinePeso(dynamic value) {
  final raw = (value ?? '').toString().trim();
  if (raw.isEmpty || raw.toLowerCase().contains('tbd')) return 'Salary TBD';

  String clean(String part) => part
      .replaceAll(RegExp(r'php|pesos?', caseSensitive: false), '')
      .replaceAll('₱', '')
      .replaceAll(',', '')
      .trim();

  String? amount(String part) {
    final parsed = num.tryParse(clean(part));
    if (parsed == null) return null;
    return '₱${NumberFormat('#,##0.##', 'en_PH').format(parsed)}';
  }

  final range = raw.split(RegExp(r'\s*[-–]\s*'));
  if (range.length == 2) {
    final first = amount(range[0]);
    final second = amount(range[1]);
    if (first != null && second != null) return '$first–$second';
  }

  return amount(raw) ?? raw;
}

String formatJobSalary(dynamic rate, dynamic paymentType) {
  final amount = formatPhilippinePeso(rate);
  if (amount == 'Salary TBD') return amount;
  final period = (paymentType ?? '').toString().trim();
  if (period.isEmpty) return amount;
  final normalized = period
      .replaceFirst(RegExp(r'^per\s+', caseSensitive: false), '')
      .toLowerCase();
  return '$amount / $normalized';
}

/// Formats editable numeric text with thousands separators but without a
/// currency symbol. Descriptive legacy values are returned unchanged.
String formatNumberWithCommas(dynamic value) {
  final raw = (value ?? '').toString().replaceAll(',', '').trim();
  if (raw.isEmpty) return '';
  final parsed = num.tryParse(raw);
  if (parsed == null) return value.toString();
  return NumberFormat('#,##0.##', 'en_PH').format(parsed);
}

/// Keeps job-rate input numeric and inserts commas while the owner types.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (sanitized.isEmpty) return const TextEditingValue();

    final firstDecimal = sanitized.indexOf('.');
    final integerText =
        firstDecimal == -1 ? sanitized : sanitized.substring(0, firstDecimal);
    final decimalText = firstDecimal == -1
        ? ''
        : sanitized.substring(firstDecimal + 1).replaceAll('.', '');
    final integer = int.tryParse(integerText.isEmpty ? '0' : integerText) ?? 0;
    final formattedInteger = NumberFormat('#,##0', 'en_PH').format(integer);
    final limitedDecimal =
        decimalText.length > 2 ? decimalText.substring(0, 2) : decimalText;
    final formatted = firstDecimal == -1
        ? formattedInteger
        : '$formattedInteger.$limitedDecimal';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
