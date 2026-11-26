import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WindowManager.cancelPendingSaves();
  });

  tearDown(() {
    WindowManager.cancelPendingSaves();
  });

  group('WindowManager - Window Size Persistence', () {
    test('saveWindowSize and loadWindowSize round-trip via SharedPreferences',
        () async {
      const testSize = Size(1440.0, 900.0);
      await WindowManager.saveWindowSize(testSize);

      final loadedSize = await WindowManager.loadWindowSize();
      expect(loadedSize, testSize);

      // Verify underlying SharedPreferences keys
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowWidth), 1440.0);
      expect(prefs.getDouble(WindowManager.keyWindowHeight), 900.0);
    });

    test('loadWindowSize falls back to 1200x800 when no size is persisted',
        () async {
      final loadedSize = await WindowManager.loadWindowSize();
      expect(loadedSize, WindowManager.defaultWindowSize);
      expect(loadedSize.width, 1200.0);
      expect(loadedSize.height, 800.0);
    });

    test('loadWindowSize accepts a custom default fallback size', () async {
      const customDefault = Size(1024.0, 768.0);
      final loadedSize =
          await WindowManager.loadWindowSize(defaultSize: customDefault);
      expect(loadedSize, customDefault);
    });

    test('loadWindowSize falls back to default on partial or invalid values',
        () async {
      SharedPreferences.setMockInitialValues({
        WindowManager.keyWindowWidth: 1000.0,
        // keyWindowHeight is missing
      });
      expect(await WindowManager.loadWindowSize(),
          WindowManager.defaultWindowSize);

      SharedPreferences.setMockInitialValues({
        WindowManager.keyWindowWidth: -100.0,
        WindowManager.keyWindowHeight: 600.0,
      });
      expect(await WindowManager.loadWindowSize(),
          WindowManager.defaultWindowSize);

      SharedPreferences.setMockInitialValues({
        WindowManager.keyWindowWidth: 800.0,
        WindowManager.keyWindowHeight: 0.0,
      });
      expect(await WindowManager.loadWindowSize(),
          WindowManager.defaultWindowSize);
    });
  });

  group('WindowManager - Window Position Persistence', () {
    test(
        'saveWindowPosition and loadWindowPosition round-trip via SharedPreferences',
        () async {
      const testPosition = Offset(250.0, 180.0);
      await WindowManager.saveWindowPosition(testPosition);

      final loadedPosition = await WindowManager.loadWindowPosition();
      expect(loadedPosition, testPosition);

      // Verify underlying SharedPreferences keys
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowX), 250.0);
      expect(prefs.getDouble(WindowManager.keyWindowY), 180.0);
    });

    test('saveWindowPosition and loadWindowPosition handle negative offsets',
        () async {
      // Multi-monitor environments can have negative coordinates
      const testPosition = Offset(-300.0, -120.0);
      await WindowManager.saveWindowPosition(testPosition);

      final loadedPosition = await WindowManager.loadWindowPosition();
      expect(loadedPosition, testPosition);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowX), -300.0);
      expect(prefs.getDouble(WindowManager.keyWindowY), -120.0);
    });

    test('loadWindowPosition falls back to null when no position is persisted',
        () async {
      final loadedPosition = await WindowManager.loadWindowPosition();
      expect(loadedPosition, isNull);
    });

    test('loadWindowPosition accepts a custom default fallback position',
        () async {
      const customDefault = Offset(100.0, 100.0);
      final loadedPosition = await WindowManager.loadWindowPosition(
        defaultPosition: customDefault,
      );
      expect(loadedPosition, customDefault);
    });

    test('loadWindowPosition falls back to default on partial position values',
        () async {
      SharedPreferences.setMockInitialValues({
        WindowManager.keyWindowX: 100.0,
        // keyWindowY is missing
      });
      expect(await WindowManager.loadWindowPosition(), isNull);
      expect(
        await WindowManager.loadWindowPosition(
            defaultPosition: const Offset(50.0, 50.0)),
        const Offset(50.0, 50.0),
      );
    });
  });

  group('WindowManager - Debounced Saving', () {
    test(
        'saveWindowSizeDebounced cancels intermediate saves and persists final size',
        () async {
      const delay = Duration(milliseconds: 100);

      // Rapidly trigger 3 window resizes
      WindowManager.saveWindowSizeDebounced(
        const Size(800.0, 600.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowSizeDebounced(
        const Size(1000.0, 700.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowSizeDebounced(
        const Size(1600.0, 1000.0),
        debounceDuration: delay,
      );

      final prefs = await SharedPreferences.getInstance();

      // Immediately: Nothing should be persisted yet to prevent I/O thrashing
      expect(prefs.getDouble(WindowManager.keyWindowWidth), isNull);
      expect(prefs.getDouble(WindowManager.keyWindowHeight), isNull);
      expect(WindowManager.hasPendingSizeSave, isTrue);

      // Wait for debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // After debounce: Only the final size should be persisted
      expect(prefs.getDouble(WindowManager.keyWindowWidth), 1600.0);
      expect(prefs.getDouble(WindowManager.keyWindowHeight), 1000.0);
      expect(WindowManager.hasPendingSizeSave, isFalse);
    });

    test(
        'saveWindowPositionDebounced cancels intermediate saves and persists final position',
        () async {
      const delay = Duration(milliseconds: 100);

      // Rapidly trigger 3 window moves
      WindowManager.saveWindowPositionDebounced(
        const Offset(50.0, 50.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowPositionDebounced(
        const Offset(120.0, 150.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowPositionDebounced(
        const Offset(350.0, 420.0),
        debounceDuration: delay,
      );

      final prefs = await SharedPreferences.getInstance();

      // Immediately: Nothing should be persisted yet
      expect(prefs.getDouble(WindowManager.keyWindowX), isNull);
      expect(prefs.getDouble(WindowManager.keyWindowY), isNull);
      expect(WindowManager.hasPendingPositionSave, isTrue);

      // Wait for debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // After debounce: Only the final position should be persisted
      expect(prefs.getDouble(WindowManager.keyWindowX), 350.0);
      expect(prefs.getDouble(WindowManager.keyWindowY), 420.0);
      expect(WindowManager.hasPendingPositionSave, isFalse);
    });

    test('saveWindowSize with debounceDuration parameter debounces', () async {
      const delay = Duration(milliseconds: 100);

      await WindowManager.saveWindowSize(
        const Size(1280.0, 720.0),
        debounceDuration: delay,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowWidth), 1280.0);
      expect(prefs.getDouble(WindowManager.keyWindowHeight), 720.0);
      expect(WindowManager.hasPendingSizeSave, isFalse);
    });

    test('saveWindowPosition with debounceDuration parameter debounces',
        () async {
      const delay = Duration(milliseconds: 100);

      await WindowManager.saveWindowPosition(
        const Offset(75.0, 85.0),
        debounceDuration: delay,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowX), 75.0);
      expect(prefs.getDouble(WindowManager.keyWindowY), 85.0);
      expect(WindowManager.hasPendingPositionSave, isFalse);
    });

    test('flushPendingSaves writes pending saves immediately', () async {
      const delay = Duration(milliseconds: 500);

      WindowManager.saveWindowSizeDebounced(
        const Size(1920.0, 1080.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowPositionDebounced(
        const Offset(200.0, 100.0),
        debounceDuration: delay,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowWidth), isNull);
      expect(prefs.getDouble(WindowManager.keyWindowX), isNull);

      // Flush immediately
      await WindowManager.flushPendingSaves();

      expect(prefs.getDouble(WindowManager.keyWindowWidth), 1920.0);
      expect(prefs.getDouble(WindowManager.keyWindowHeight), 1080.0);
      expect(prefs.getDouble(WindowManager.keyWindowX), 200.0);
      expect(prefs.getDouble(WindowManager.keyWindowY), 100.0);
      expect(WindowManager.hasPendingSizeSave, isFalse);
      expect(WindowManager.hasPendingPositionSave, isFalse);
    });

    test('cancelPendingSaves cancels pending timers without writing', () async {
      const delay = Duration(milliseconds: 100);

      WindowManager.saveWindowSizeDebounced(
        const Size(1920.0, 1080.0),
        debounceDuration: delay,
      );
      WindowManager.saveWindowPositionDebounced(
        const Offset(200.0, 100.0),
        debounceDuration: delay,
      );

      WindowManager.cancelPendingSaves();
      expect(WindowManager.hasPendingSizeSave, isFalse);
      expect(WindowManager.hasPendingPositionSave, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(WindowManager.keyWindowWidth), isNull);
      expect(prefs.getDouble(WindowManager.keyWindowX), isNull);
    });
  });

  group('WindowManager - Flag preservation', () {
    test('flagSecure constant remains unchanged', () {
      expect(WindowManager.flagSecure, 0x00002000);
    });
  });
}
