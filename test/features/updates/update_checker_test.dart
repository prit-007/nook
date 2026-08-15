import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nook/features/updates/update_checker.dart';

Map<String, dynamic> _entry(
  String tag, {
  bool draft = false,
  bool prerelease = false,
  String? publishedAt,
}) {
  return {
    'tag_name': tag,
    'name': tag,
    'html_url': 'https://github.com/prit-007/nook/releases/tag/$tag',
    'body': 'Release notes for $tag',
    'published_at': publishedAt ?? '2026-08-15T00:00:00Z',
    'draft': draft,
    'prerelease': prerelease,
  };
}

void main() {
  test('returns the newest non-draft release', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/repos/prit-007/nook/releases');
      return http.Response(
        jsonEncode([
          _entry('v0.9.0'),
          _entry('v0.8.0'),
        ]),
        200,
      );
    });

    final release = await UpdateChecker(client: client).fetchLatestRelease();

    expect(release, isNotNull);
    expect(release!.tagName, 'v0.9.0');
    expect(
      release.htmlUrl,
      'https://github.com/prit-007/nook/releases/tag/v0.9.0',
    );
    expect(release.body, 'Release notes for v0.9.0');
    expect(release.publishedAt, isNotNull);
    expect(release.draft, isFalse);
  });

  test('skips drafts and picks the next non-draft', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode([
          _entry('v1.0.0', draft: true),
          _entry('v0.9.0'),
        ]),
        200,
      ),
    );

    final release = await UpdateChecker(client: client).fetchLatestRelease();

    expect(release, isNotNull);
    expect(release!.tagName, 'v0.9.0');
  });

  test('returns null when no releases exist', () async {
    final client = MockClient((_) async => http.Response('[]', 200));

    final release = await UpdateChecker(client: client).fetchLatestRelease();

    expect(release, isNull);
  });

  test('throws on non-200 responses', () async {
    final client = MockClient((_) async => http.Response('Not Found', 404));

    expect(
      () => UpdateChecker(client: client).fetchLatestRelease(),
      throwsA(isA<UpdateCheckException>()),
    );
  });

  test('throws on malformed json', () async {
    final client = MockClient((_) async => http.Response('not-json', 200));

    expect(
      () => UpdateChecker(client: client).fetchLatestRelease(),
      throwsA(isA<UpdateCheckException>()),
    );
  });
}
