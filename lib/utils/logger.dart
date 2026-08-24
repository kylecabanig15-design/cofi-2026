import 'package:cofi/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Central logging function. Replaces direct debugLog() calls so production
/// release builds emit nothing while debug builds keep full output.
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    debugLog(message);
  }
}
