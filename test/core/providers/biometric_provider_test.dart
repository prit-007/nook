import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/biometric_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BiometricGate', () {
    test('disabled by default and reports unlocked', () {
      final gate = BiometricGate();
      expect(gate.enabled, isFalse);
      expect(gate.isLocked, isFalse);
    });

    test('isLocked is false while disabled even after lock()', () {
      final gate = BiometricGate();
      gate.lock();
      expect(gate.isLocked, isFalse);
    });

    test('enabling locks the app', () {
      final gate = BiometricGate();
      gate.setEnabled(true);
      expect(gate.isLocked, isTrue);
      expect(gate.state, AppLockState.locked);
    });

    test('unlock with successful authenticator unlocks', () async {
      final gate = BiometricGate(authenticator: () async => true);
      gate.setEnabled(true);
      expect(gate.isLocked, isTrue);

      final ok = await gate.unlock();
      expect(ok, isTrue);
      expect(gate.isLocked, isFalse);
    });

    test('unlock with failing authenticator stays locked', () async {
      final gate = BiometricGate(authenticator: () async => false);
      gate.setEnabled(true);

      final ok = await gate.unlock();
      expect(ok, isFalse);
      expect(gate.isLocked, isTrue);
    });

    test('unlock with throwing authenticator stays locked', () async {
      final gate = BiometricGate(authenticator: () async {
        throw Exception('no biometric hardware');
      });
      gate.setEnabled(true);

      final ok = await gate.unlock();
      expect(ok, isFalse);
      expect(gate.isLocked, isTrue);
    });

    test('does not prompt again once already authenticated', () async {
      var calls = 0;
      final gate = BiometricGate(authenticator: () async {
        calls++;
        return true;
      });
      gate.setEnabled(true);

      await gate.unlock();
      await gate.unlock();
      expect(calls, 1);
      expect(gate.isLocked, isFalse);
    });

    test('onAppResumed relocks after prior authentication', () async {
      final gate = BiometricGate(authenticator: () async => true);
      gate.setEnabled(true);
      await gate.unlock();
      expect(gate.isLocked, isFalse);

      gate.onAppResumed();
      expect(gate.isLocked, isTrue);
    });

    test('onAppResumed is a no-op when disabled', () {
      final gate = BiometricGate(authenticator: () async => true);
      gate.onAppResumed();
      expect(gate.isLocked, isFalse);
    });

    test('unlock returns true immediately when disabled', () async {
      final gate = BiometricGate();
      final ok = await gate.unlock();
      expect(ok, isTrue);
    });

    test('persists enabled flag via SharedPreferences', () async {
      final gate = BiometricGate();
      gate.setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('biometric_enabled'), isTrue);
    });

    test('load restores enabled flag', () async {
      SharedPreferences.setMockInitialValues({'biometric_enabled': true});
      final gate = await BiometricGate.load();
      expect(gate.enabled, isTrue);
      expect(gate.isLocked, isTrue);
    });
  });
}
