import 'package:flutter/foundation.dart';

/// Central logging function. Replaces direct print() calls so production
/// release builds emit nothing while debug builds keep full output.
void debugLog(String message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
