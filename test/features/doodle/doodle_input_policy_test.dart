import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_input_policy.dart';

PointerDownEvent touchDown({int pointer = 1}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.touch,
  );
}

PointerDownEvent stylusButtonDown({int pointer = 2}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.stylus,
    buttons: kSecondaryButton,
    pressure: 0.5,
  );
}

PointerDownEvent stylusDown({int pointer = 2}) {
  return PointerDownEvent(
    pointer: pointer,
    position: Offset.zero,
    kind: PointerDeviceKind.stylus,
    pressure: 0.5,
  );
}

void main() {
  final base = DateTime(2026, 11, 23, 12, 0, 0);

  group('Step 5 — Palm rejection / stylus input policy', () {
    test('accepts stylus events at all times', () {
      final policy = DoodleInputPolicy();
      expect(
        policy.shouldAccept(stylusDown(), now: base),
        isTrue,
      );
      expect(
        policy.shouldAccept(
          stylusDown(pointer: 3),
          now: base.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('accepts touch when no stylus activity has occurred', () {
      final policy = DoodleInputPolicy();
      expect(
        policy.shouldAccept(touchDown(), now: base),
        isTrue,
      );
    });

    test('rejects touch within the palm window after stylus activity', () {
      final policy = DoodleInputPolicy();
      policy.noteStylusActivity(base);
      expect(
        policy.shouldAccept(
          touchDown(),
          now: base.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
      );
    });

    test('accepts touch after the palm window expires', () {
      final policy = DoodleInputPolicy();
      policy.noteStylusActivity(base);
      expect(
        policy.shouldAccept(
          touchDown(),
          now: base.add(const Duration(seconds: 2)),
        ),
        isTrue,
      );
    });

    test('stylus activity inside the window keeps touch rejected', () {
      final policy = DoodleInputPolicy();
      policy.noteStylusActivity(base);
      // A second stylus event 500ms later resets the palm window.
      policy.noteStylusActivity(base.add(const Duration(milliseconds: 500)));
      expect(
        policy.shouldAccept(
          touchDown(),
          now: base.add(const Duration(milliseconds: 900)),
        ),
        isFalse,
      );
    });

    test('stylus-only mode rejects touch but accepts stylus', () {
      final policy = DoodleInputPolicy();
      expect(
        policy.shouldAccept(touchDown(), now: base, stylusOnlyMode: true),
        isFalse,
      );
      expect(
        policy.shouldAccept(stylusDown(), now: base, stylusOnlyMode: true),
        isTrue,
      );
    });

    test('non-stylus, non-touch pointer kinds are accepted', () {
      final policy = DoodleInputPolicy();
      final event = const PointerDownEvent(
        pointer: 1,
        position: Offset.zero,
        kind: PointerDeviceKind.mouse,
      );
      expect(policy.shouldAccept(event, now: base), isTrue);
    });

    group('tool swap', () {
      test('stylus secondary button down requests a swap', () {
        final policy = DoodleInputPolicy();
        expect(
          policy.shouldSwapTool(stylusButtonDown(), now: base),
          isTrue,
        );
      });

      test('stylus primary button down does not swap', () {
        final policy = DoodleInputPolicy();
        expect(
          policy.shouldSwapTool(stylusDown(), now: base),
          isFalse,
        );
      });

      test('touch button press does not swap', () {
        final policy = DoodleInputPolicy();
        final event = const PointerDownEvent(
          pointer: 1,
          position: Offset.zero,
          kind: PointerDeviceKind.touch,
          buttons: kSecondaryButton,
        );
        expect(policy.shouldSwapTool(event, now: base), isFalse);
      });

      test('stylus double-tap within the window swaps', () {
        final policy = DoodleInputPolicy();
        policy.shouldSwapTool(stylusDown(), now: base); // first tap
        expect(
          policy.shouldSwapTool(
            stylusDown(),
            now: base.add(const Duration(milliseconds: 200)),
          ),
          isTrue,
        );
      });

      test('stylus taps farther apart than the window do not swap', () {
        final policy = DoodleInputPolicy();
        policy.shouldSwapTool(stylusDown(), now: base);
        expect(
          policy.shouldSwapTool(
            stylusDown(),
            now: base.add(const Duration(milliseconds: 500)),
          ),
          isFalse,
        );
      });

      test('after a swap double-tap, a further tap does not swap again', () {
        final policy = DoodleInputPolicy();
        policy.shouldSwapTool(stylusDown(), now: base);
        expect(
          policy.shouldSwapTool(
            stylusDown(),
            now: base.add(const Duration(milliseconds: 200)),
          ),
          isTrue,
        );
        expect(
          policy.shouldSwapTool(
            stylusDown(),
            now: base.add(const Duration(milliseconds: 400)),
          ),
          isFalse,
        );
      });
    });
  });
}
