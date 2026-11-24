import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/pin_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PinProvider lockout & backoff', () {
    test('initial state has 0 failed attempts and not locked out', () {
      final provider = PinProvider();
      expect(provider.failedAttempts, 0);
      expect(provider.isLockedOut, isFalse);
      expect(provider.remainingLockoutSeconds, 0);
    });

    test('recordFailedAttempt increments attempts and locks out at thresholds',
        () {
      final provider = PinProvider();

      provider.recordFailedAttempt();
      expect(provider.failedAttempts, 1);
      expect(provider.isLockedOut, isFalse);

      provider.recordFailedAttempt();
      expect(provider.failedAttempts, 2);
      expect(provider.isLockedOut, isFalse);

      // 3rd attempt triggers 30s lockout
      provider.recordFailedAttempt();
      expect(provider.failedAttempts, 3);
      expect(provider.isLockedOut, isTrue);
      expect(provider.remainingLockoutSeconds, greaterThan(0));
      expect(provider.remainingLockoutSeconds, lessThanOrEqualTo(30));

      // Reset attempts clears lockout
      provider.resetAttempts();
      expect(provider.failedAttempts, 0);
      expect(provider.isLockedOut, isFalse);
    });

    test('higher failed attempt counts trigger longer lockouts', () {
      final provider = PinProvider();

      for (var i = 0; i < 5; i++) {
        provider.recordFailedAttempt();
      }
      expect(provider.failedAttempts, 5);
      expect(provider.isLockedOut, isTrue);
      expect(provider.remainingLockoutSeconds, greaterThan(30));
      expect(provider.remainingLockoutSeconds, lessThanOrEqualTo(60));

      for (var i = 0; i < 2; i++) {
        provider.recordFailedAttempt();
      }
      expect(provider.failedAttempts, 7);
      expect(provider.isLockedOut, isTrue);
      expect(provider.remainingLockoutSeconds, greaterThan(60));
      expect(provider.remainingLockoutSeconds, lessThanOrEqualTo(300));
    });
  });
}
