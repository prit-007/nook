import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/frame_rate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugOverrideIsAndroid = true;
  });

  tearDown(() {
    debugOverrideIsAndroid = false;
  });

  group('Frame rate', () {
    test('requestHighRefreshRate sends setFrameRate on method channel',
        () async {
      final receivedCalls = <String>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        frameRateChannel,
        (call) async {
          receivedCalls.add(call.method);
          return null;
        },
      );

      final result = await requestHighRefreshRate();

      expect(receivedCalls, contains('setFrameRate'));
      expect(result, isTrue);
    });

    test('requestHighRefreshRate returns false on error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        frameRateChannel,
        (call) async {
          throw PlatformException(code: 'ERROR', message: 'failed');
        },
      );

      final result = await requestHighRefreshRate();
      expect(result, isFalse);
    });
  });
}
