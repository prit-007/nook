import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/ocr_service.dart';
import 'package:nook/features/editor/widgets/ocr_scan_sheet.dart';

class _FakeOcrService implements OcrService {
  _FakeOcrService({this.result = const OcrResult(text: 'Scanned text')});

  final OcrResult result;

  @override
  Future<OcrResult> extractText(String imagePath) async => result;
}

void main() {
  testWidgets(
      'OcrScanSheet runs extraction on initialImagePath and returns text',
      (tester) async {
    final fake = _FakeOcrService(
      result: const OcrResult(text: 'Hello from receipt'),
    );
    String? inserted;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ocrServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  inserted = await showOcrScanSheet(
                    context,
                    initialImagePath: '/tmp/fake.png',
                  );
                },
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('Hello from receipt'), findsOneWidget);
    await tester.tap(find.text('Insert Text'));
    await tester.pumpAndSettle();

    expect(inserted, 'Hello from receipt');
  });

  testWidgets('OcrScanSheet surfaces engine unavailability error cleanly',
      (tester) async {
    final fake = _FakeOcrService(
      result: const OcrResult(
        text: '',
        error: 'No offline FOSS OCR engine is installed on this device.',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ocrServiceProvider.overrideWithValue(fake)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showOcrScanSheet(
                  context,
                  initialImagePath: '/tmp/fake.png',
                ),
                child: const Text('Scan'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(
      find.text('No offline FOSS OCR engine is installed on this device.'),
      findsOneWidget,
    );
  });
}
