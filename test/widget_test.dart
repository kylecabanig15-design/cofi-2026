import 'package:flutter_test/flutter_test.dart';

import 'package:cofi/root_auth_gate.dart';

/// Phase 0 baseline smoke test.
///
/// The previous version of this file was the default Flutter counter
/// template referencing `MyApp`, which does not exist in CoFi (the root
/// widget is `RootAuthGate`), so the entire test suite failed to compile.
///
/// Pumping the real widget tree requires Firebase initialization, which is
/// out of scope for a plain unit/widget test environment. Deeper widget and
/// integration tests are planned for Phase 5.
void main() {
  test('RootAuthGate can be constructed', () {
    const gate = RootAuthGate();
    expect(gate.initializationError, isNull);

    const gateWithError =
        RootAuthGate(initializationError: 'init failed');
    expect(gateWithError.initializationError, 'init failed');
  });
}
