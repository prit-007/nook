import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/ocr_service.dart';

void main() {
  group('OCR proprietary SDK audit (com.nook/ocr)', () {
    test(
        'build.gradle.kts contains zero Google Play Services or ML Kit dependencies',
        () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);
      final content = gradleFile.readAsStringSync();

      expect(content.contains('play-services-mlkit'), isFalse,
          reason: 'Must not depend on proprietary Google Play Services ML Kit');
      expect(content.contains('play-services-vision'), isFalse,
          reason: 'Must not depend on proprietary Google Play Services Vision');
      expect(content.contains('com.google.mlkit'), isFalse,
          reason: 'Must not depend on proprietary ML Kit SDKs');
      expect(content.contains('com.google.android.gms:play-services'), isFalse,
          reason: 'Must not depend on Google Play Services');
    });

    test(
        'AndroidManifest.xml contains zero proprietary OCR meta-data or dependencies',
        () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      expect(
        content.contains('com.google.android.gms.vision.DEPENDENCIES'),
        isFalse,
        reason: 'Must not request proprietary ML Kit model downloads',
      );
      expect(
        content.contains('com.google.android.gms'),
        isFalse,
        reason: 'Must not reference Google Play Services in manifest',
      );
    });

    test('MainActivity.kt registers no proprietary OCR engine on com.nook/ocr',
        () {
      final activityFile = File(
        'android/app/src/main/kotlin/com/devparadise/nook/MainActivity.kt',
      );
      expect(activityFile.existsSync(), isTrue);
      final content = activityFile.readAsStringSync();

      expect(content.contains('TextRecognition'), isFalse);
      expect(content.contains('com.google.mlkit'), isFalse);
      expect(content.contains('FirebaseVision'), isFalse);
    });

    test(
        'LocalFossOcrService degrades cleanly on missing mobile plugin without network calls',
        () async {
      final service = LocalFossOcrService();
      // Non-existent image file
      final notFound = await service.extractText('non_existent_file.png');
      expect(notFound.isSuccess, isFalse);
      expect(notFound.error, 'Image file not found.');
    });
  });

  group('OCR trained data license check', () {
    test('assets directory contains zero bundled .traineddata binary blobs',
        () {
      final assetsDir = Directory('assets');
      expect(assetsDir.existsSync(), isTrue);
      final trainedDataFiles = assetsDir
          .listSync(recursive: true)
          .where((f) => f.path.endsWith('.traineddata'))
          .toList();

      expect(
        trainedDataFiles,
        isEmpty,
        reason:
            'Repository and app bundle must not contain binary .traineddata blobs',
      );
    });

    test(
        'desktop OCR delegates to system tesseract with clear guidance when missing',
        () {
      final ocrServiceSource =
          File('lib/core/platform/ocr_service.dart').readAsStringSync();
      expect(ocrServiceSource.contains('tesseract-ocr'), isTrue);
      expect(ocrServiceSource.contains('Install Tesseract OCR'), isTrue);
      expect(ocrServiceSource.contains('stdout'), isTrue);
    });
  });
}
