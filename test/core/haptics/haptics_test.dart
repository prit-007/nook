import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/haptics/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    AppHaptics.enabled = true;
    AppHaptics.debugOverrideEnabled = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        log.add(call);
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppHaptics.enabled = true;
    AppHaptics.debugOverrideEnabled = null;
  });

  group('AppHaptics core feedback', () {
    test('selection() calls HapticFeedback.selectionClick()', () async {
      await AppHaptics.selection();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.selectionClick');
    });

    test('light() calls HapticFeedback.lightImpact()', () async {
      await AppHaptics.light();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('medium() calls HapticFeedback.mediumImpact()', () async {
      await AppHaptics.medium();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('heavy() calls HapticFeedback.heavyImpact()', () async {
      await AppHaptics.heavy();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.heavyImpact');
    });
  });

  group('AppHaptics semantic actions', () {
    test('success() triggers feedback (light impact)', () async {
      await AppHaptics.success();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    test('warning() triggers feedback (medium impact)', () async {
      await AppHaptics.warning();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.mediumImpact');
    });

    test('error() triggers feedback (heavy impact)', () async {
      await AppHaptics.error();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.heavyImpact');
    });

    test('toggle() triggers feedback (selection click)', () async {
      await AppHaptics.toggle();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.selectionClick');
    });
  });

  group('AppHaptics enabled flag & debugOverrideEnabled', () {
    test('isEnabled is true by default', () {
      expect(AppHaptics.isEnabled, isTrue);
    });

    test('setting enabled to false disables feedback', () async {
      AppHaptics.enabled = false;
      expect(AppHaptics.isEnabled, isFalse);

      await AppHaptics.selection();
      await AppHaptics.light();
      await AppHaptics.medium();
      await AppHaptics.heavy();
      await AppHaptics.success();
      await AppHaptics.warning();
      await AppHaptics.error();
      await AppHaptics.toggle();

      expect(log, isEmpty);
    });

    test('debugOverrideEnabled overrides enabled = true when false', () async {
      AppHaptics.enabled = true;
      AppHaptics.debugOverrideEnabled = false;
      expect(AppHaptics.isEnabled, isFalse);

      await AppHaptics.selection();
      await AppHaptics.light();
      await AppHaptics.success();

      expect(log, isEmpty);
    });

    test('debugOverrideEnabled overrides enabled = false when true', () async {
      AppHaptics.enabled = false;
      AppHaptics.debugOverrideEnabled = true;
      expect(AppHaptics.isEnabled, isTrue);

      await AppHaptics.selection();

      expect(log, hasLength(1));
      expect(log.single.method, 'HapticFeedback.vibrate');
      expect(log.single.arguments, 'HapticFeedbackType.selectionClick');
    });
  });
}
