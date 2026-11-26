import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/platform/window_manager.dart';
import 'package:nook/core/security/bip39_wordlist.dart';
import 'package:nook/core/security/kdf.dart';
import 'package:nook/core/security/recovery_key_provider.dart';
import 'package:nook/features/security/recovery_key_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Known 24-word BIP-39 test vector for 32 zero bytes:
  // Checksum is 0x66 -> 23 words of 'abandon' + 'art'
  final allZerosWords = [...List<String>.filled(23, 'abandon'), 'art'];

  // Known 24-word BIP-39 test vector for 32 0xFF bytes:
  final allOnesWords = [...List<String>.filled(23, 'zoo'), 'vote'];

  group('generateRecoveryKey', () {
    test('produces a 24-word BIP39 mnemonic with valid entropy', () {
      final words = generateRecoveryKey();

      expect(words, hasLength(24));
      for (final word in words) {
        expect(bip39EnglishWordList.contains(word), isTrue,
            reason: 'Word "$word" must exist in BIP-39 English wordlist');
      }

      // Valid entropy produces valid key phrase that passes validation
      expect(validateRecoveryKey(words), isTrue);
    });

    test(
        'produces different mnemonics across multiple runs (valid random entropy)',
        () {
      final run1 = generateRecoveryKey();
      final run2 = generateRecoveryKey();

      expect(run1, isNot(equals(run2)));
    });

    test('accepts deterministic entropy bytes', () {
      final zeroEntropy = List<int>.filled(32, 0);
      final words = generateRecoveryKey(entropy: zeroEntropy);

      expect(words, equals(allZerosWords));
      expect(validateRecoveryKey(words), isTrue);

      final onesEntropy = List<int>.filled(32, 255);
      final wordsOnes = generateRecoveryKey(entropy: onesEntropy);
      expect(wordsOnes, equals(allOnesWords));
      expect(validateRecoveryKey(wordsOnes), isTrue);
    });

    test('rejects entropy of invalid length', () {
      expect(
        () => generateRecoveryKey(entropy: List<int>.filled(16, 0)),
        throwsArgumentError,
      );
    });
  });

  group('validateRecoveryKey', () {
    test('accepts valid 24-word key phrases as List<String> and String', () {
      expect(validateRecoveryKey(allZerosWords), isTrue);
      expect(validateRecoveryKey(allZerosWords.join(' ')), isTrue);
      expect(validateRecoveryKey(allOnesWords), isTrue);

      // Randomly generated valid phrase
      final generated = generateRecoveryKey();
      expect(validateRecoveryKey(generated), isTrue);
      expect(validateRecoveryKey(generated.join(' ')), isTrue);
    });

    test('handles whitespace, tabs, newlines, and case insensitivity', () {
      final uppercaseWords = allZerosWords.map((w) => w.toUpperCase()).toList();
      expect(validateRecoveryKey(uppercaseWords), isTrue);

      final paddedString = '  ${allZerosWords.join('   \n  ')}  \t';
      expect(validateRecoveryKey(paddedString), isTrue);
    });

    test('rejects invalid lengths', () {
      expect(validateRecoveryKey(<String>[]), isFalse);
      expect(validateRecoveryKey(''), isFalse);
      expect(validateRecoveryKey(allZerosWords.sublist(0, 12)), isFalse);
      expect(validateRecoveryKey(allZerosWords.sublist(0, 23)), isFalse);
      expect(validateRecoveryKey([...allZerosWords, 'art']), isFalse);
    });

    test('rejects corrupted words (words not in wordlist)', () {
      final corrupted = List<String>.from(allZerosWords);
      corrupted[5] = 'invalidwordnotindictionary';
      expect(validateRecoveryKey(corrupted), isFalse);
      expect(validateRecoveryKey(corrupted.join(' ')), isFalse);
    });

    test('rejects bad checksums', () {
      // 24 valid words from the dictionary, but with the wrong checksum in the 24th word
      final badChecksum = List<String>.from(allZerosWords);
      // 'art' is index 102. 'abandon' is index 0. Changing the last word alters the checksum.
      badChecksum[23] = 'abandon';
      expect(validateRecoveryKey(badChecksum), isFalse);

      final anotherBadChecksum = List<String>.from(allOnesWords);
      anotherBadChecksum[23] = 'zoo';
      expect(validateRecoveryKey(anotherBadChecksum), isFalse);
    });
  });

  group('deriveVaultDEKFromRecoveryKey', () {
    test('derives a deterministic 256-bit key using PBKDF2/HMAC', () {
      final dek1 = deriveVaultDEKFromRecoveryKey(
        allZerosWords,
        iterations: 1000,
      );
      final dek2 = deriveVaultDEKFromRecoveryKey(
        allZerosWords,
        iterations: 1000,
      );

      // 256 bits = 32 bytes
      expect(dek1, hasLength(32));
      expect(dek2, hasLength(32));
      expect(dek1, equals(dek2));

      // Matches direct pbkdf2DeriveBytes with same salt and phrase
      final direct = pbkdf2DeriveBytes(
        password: allZerosWords.join(' '),
        salt: utf8.encode('mnemonic'),
        iterations: 1000,
        keyLength: 32,
      );
      expect(dek1, equals(direct));
    });

    test('produces different keys for different recovery phrases', () {
      final dekA = deriveVaultDEKFromRecoveryKey(
        allZerosWords,
        iterations: 1000,
      );
      final dekB = deriveVaultDEKFromRecoveryKey(
        allOnesWords,
        iterations: 1000,
      );

      expect(dekA, isNot(equals(dekB)));
    });

    test('rejects invalid recovery key phrases with ArgumentError', () {
      expect(
        () => deriveVaultDEKFromRecoveryKey(['not', 'enough', 'words']),
        throwsArgumentError,
      );
      expect(
        () => deriveVaultDEKFromRecoveryKey(
          List<String>.filled(24, 'notaword'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('RecoveryKeyDialog widget', () {
    late List<MethodCall> platformCalls;
    late List<MethodCall> windowChannelCalls;

    setUp(() {
      platformCalls = <MethodCall>[];
      windowChannelCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nook/window_manager'),
        (call) async {
          windowChannelCalls.add(call);
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.nook/window_manager'),
        null,
      );
    });

    Widget buildTestDialog({
      List<String>? words,
      List<int>? verifyIndices,
      VoidCallback? onConfirmed,
    }) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => RecoveryKeyDialog(
                    words: words,
                    verifyIndices: verifyIndices,
                    onConfirmed: onConfirmed,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
    }

    testWidgets('displays the generated words in numbered chips/grid',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(words: allZerosWords));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check all 24 words are visible
      expect(find.text('abandon'), findsWidgets);
      expect(find.text('art'), findsOneWidget);

      // Check numbered index indicators (1 to 24)
      for (var i = 1; i <= 24; i++) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data == '$i' || w.data == '$i.' || w.data == '#$i'),
          ),
          findsWidgets,
          reason: 'Expected numbered chip indicator for index $i',
        );
      }
    });

    testWidgets(
        'displays prominent warning ("Keys cannot be recovered if lost")',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(words: allZerosWords));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Keys cannot be recovered if lost'),
        findsOneWidget,
      );

      // Warning icon uses HugeIcons
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HugeIcon &&
              (w.icon == HugeIcons.strokeRoundedAlertCircle ||
                  w.icon == HugeIcons.strokeRoundedAlert02 ||
                  w.icon == HugeIcons.strokeRoundedAlert01),
        ),
        findsWidgets,
      );
    });

    testWidgets(
        'includes a "Copy to clipboard" affordance with haptic feedback',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(words: allZerosWords));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Find copy button (by HugeIcons.strokeRoundedCopy01 or tooltip/text)
      final copyFinder = find.byWidgetPredicate(
        (w) =>
            (w is HugeIcon && w.icon == HugeIcons.strokeRoundedCopy01) ||
            (w is Text &&
                w.data != null &&
                w.data!.toLowerCase().contains('copy')),
      );
      expect(copyFinder, findsWidgets);

      await tester.tap(copyFinder.first);
      await tester.pumpAndSettle();

      // Check haptic feedback was triggered
      final hasHaptic = platformCalls.any(
        (call) => call.method.startsWith('HapticFeedback'),
      );
      expect(hasHaptic, isTrue,
          reason: 'Haptic feedback must be triggered on copy');

      // Check clipboard was updated with the 24 words
      final hasClipboard = platformCalls.any(
        (call) =>
            call.method == 'Clipboard.setData' &&
            call.arguments['text'] == allZerosWords.join(' '),
      );
      expect(hasClipboard, isTrue,
          reason: 'Clipboard must contain the 24 words');
    });

    testWidgets('requires user to verify 3 random words before Done is enabled',
        (tester) async {
      var confirmed = false;
      await tester.pumpWidget(buildTestDialog(
        words: allZerosWords,
        verifyIndices: const [0, 1, 23],
        onConfirmed: () => confirmed = true,
      ));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('Verify 3 words to confirm you saved it:'),
        findsOneWidget,
      );

      final confirmBtnFinder = find.widgetWithText(FilledButton, 'Done');
      expect(confirmBtnFinder, findsOneWidget);

      // Initially disabled
      expect(tester.widget<FilledButton>(confirmBtnFinder).onPressed, isNull);

      // Enter wrong words -> stays disabled
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'wrong');
      await tester.enterText(fields.at(1), allZerosWords[1]);
      await tester.enterText(fields.at(2), allZerosWords[23]);
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmBtnFinder).onPressed, isNull);
      expect(confirmed, isFalse);

      // Enter all 3 matching words (case-insensitive) -> enabled
      await tester.enterText(fields.at(0), allZerosWords[0].toUpperCase());
      await tester.pump();
      expect(
          tester.widget<FilledButton>(confirmBtnFinder).onPressed, isNotNull);

      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
      expect(find.byType(RecoveryKeyDialog), findsNothing);
    });

    testWidgets('activates FLAG_SECURE on open and clears on dispose',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(words: allZerosWords));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        windowChannelCalls.any(
          (call) =>
              call.method == 'addFlags' &&
              call.arguments['flags'] == WindowManager.flagSecure,
        ),
        isTrue,
        reason: 'FLAG_SECURE must be applied when recovery key dialog opens',
      );

      // Close dialog via Cancel button
      final cancelFinder = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelFinder, findsOneWidget);
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();

      expect(
        windowChannelCalls.any(
          (call) =>
              call.method == 'clearFlags' &&
              call.arguments['flags'] == WindowManager.flagSecure,
        ),
        isTrue,
        reason:
            'FLAG_SECURE must be cleared when recovery key dialog is dismissed',
      );
    });

    testWidgets('clears clipboard automatically after 60 seconds',
        (tester) async {
      await tester.pumpWidget(buildTestDialog(words: allZerosWords));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      final copyFinder = find.byWidgetPredicate(
        (w) =>
            (w is HugeIcon && w.icon == HugeIcons.strokeRoundedCopy01) ||
            (w is Text &&
                w.data != null &&
                w.data!.toLowerCase().contains('copy')),
      );
      await tester.tap(copyFinder.first);
      await tester.pumpAndSettle();

      expect(
        platformCalls.any((call) =>
            call.method == 'Clipboard.setData' &&
            call.arguments['text'] == allZerosWords.join(' ')),
        isTrue,
      );

      // Advance clock by 61 seconds
      await tester.pump(const Duration(seconds: 61));

      // Assert clipboard was cleared
      expect(
        platformCalls.any((call) =>
            call.method == 'Clipboard.setData' && call.arguments['text'] == ''),
        isTrue,
        reason: 'Clipboard must be cleared after 60s for security',
      );
    });
  });
}
