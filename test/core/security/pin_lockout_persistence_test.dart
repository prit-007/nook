import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/pin_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
      'PIN lockout state persists across PinProvider.load() restarts (Phase 2.6)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final pin1 = PinProvider(enabled: true);
    await pin1.recordFailedAttemptPersisted();
    await pin1.recordFailedAttemptPersisted();
    await pin1.recordFailedAttemptPersisted();
    expect(pin1.isLockedOut, isTrue);
    expect(pin1.failedAttempts, 3);

    // Simulate app restart via PinProvider.load().
    final pin2 = await PinProvider.load();
    expect(pin2.isLockedOut, isTrue);
    expect(pin2.failedAttempts, 3);
  });
}
