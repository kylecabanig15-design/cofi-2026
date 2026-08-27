import 'package:flutter/foundation.dart';

/// App-wide lightweight signals for cross-screen refreshes.
/// Kept in a tiny standalone file to avoid circular imports between
/// feature screens (e.g. job_application_screen -> profile_tab).
final ValueNotifier<int> applicationsVersion = ValueNotifier<int>(0);

/// Incremented after a review or visit changes recommendation input data.
final ValueNotifier<int> recommendationVersion = ValueNotifier<int>(0);
