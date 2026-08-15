import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/media_path_rewriter.dart';

void main() {
  Map<String, dynamic> document(List<Map<String, dynamic>> children) => {
        'document': {
          'type': 'page',
          'children': children,
        },
      };

  test('rewrites image url and doodle thumbnail by exact path', () {
    const oldImage = '/home/src/attachments/hero.png';
    const oldThumb = '/home/src/attachments/doodle-1_thumb.png';
    final delta = jsonEncode(document([
      {
        'type': 'image',
        'data': {'url': oldImage}
      },
      {
        'type': 'doodle',
        'data': {
          'attachment_id': 'doodle-1',
          'thumbnail_path': oldThumb,
        },
      },
    ]));

    final out = rewriteMediaPaths(delta, [
      const RestoredMedia(
        attachmentId: 'img-1',
        originalFilePath: oldImage,
        newFilePath: '/data/user/0/app/attachments/img-1.png',
      ),
      const RestoredMedia(
        attachmentId: 'doodle-1',
        originalThumbnailPath: oldThumb,
        newFilePath: '/data/user/0/app/doodle-1.doodle.json',
        newThumbnailPath: '/data/user/0/app/doodle-1_thumb.png',
      ),
    ]);

    final doc = jsonDecode(out) as Map<String, dynamic>;
    final children = ((doc['document'] as Map)['children'] as List).cast<Map>();
    expect(
        children[0]['data']['url'], '/data/user/0/app/attachments/img-1.png');
    expect(children[1]['data']['thumbnail_path'],
        '/data/user/0/app/doodle-1_thumb.png');
    expect(children[1]['data']['attachment_id'], 'doodle-1');
  });

  test('re-points attachment_id when a collision remapped the id', () {
    final delta = jsonEncode(document([
      {
        'type': 'doodle',
        'data': {
          'attachment_id': 'doodle-1',
          'thumbnail_path': '/old/thumb.png'
        },
      },
    ]));

    final out = rewriteMediaPaths(delta, [
      const RestoredMedia(
        attachmentId: 'doodle-1',
        newAttachmentId: 'fresh-uuid',
        originalThumbnailPath: '/old/thumb.png',
        newFilePath: '/new/doodle-1.doodle.json',
        newThumbnailPath: '/new/fresh-uuid_thumb.png',
      ),
    ]);

    final doc = jsonDecode(out) as Map<String, dynamic>;
    final doodle =
        (((doc['document'] as Map)['children'] as List).cast<Map>()).single;
    expect(doodle['data']['attachment_id'], 'fresh-uuid');
    expect(doodle['data']['thumbnail_path'], '/new/fresh-uuid_thumb.png');
  });

  test('legacy payload (no paths) rewrites by basename and attachment_id', () {
    // Sender never carried filePath/thumbnailPath; only the exported file name
    // and the delta's structural references survive.
    final delta = jsonEncode(document([
      {
        'type': 'image',
        'data': {'url': 'file:///storage/emulated/0/Pictures/img-1.png'},
      },
      {
        'type': 'doodle',
        'data': {
          'attachment_id': 'doodle-1',
          'thumbnail_path': '',
        },
      },
    ]));

    final out = rewriteMediaPaths(delta, [
      const RestoredMedia(
        attachmentId: 'img-1',
        originalFileName: 'img-1.png',
        newFilePath: '/data/app/attachments/img-1.png',
      ),
      const RestoredMedia(
        attachmentId: 'doodle-1',
        newFilePath: '/data/app/doodle-1.doodle.json',
        newThumbnailPath: '/data/app/doodle-1_thumb.png',
      ),
    ]);

    final doc = jsonDecode(out) as Map<String, dynamic>;
    final children = ((doc['document'] as Map)['children'] as List).cast<Map>();
    expect(children[0]['data']['url'], '/data/app/attachments/img-1.png');
    expect(
        children[1]['data']['thumbnail_path'], '/data/app/doodle-1_thumb.png');
  });

  test('Windows paths (JSON-escaped backslashes) are rewritten', () {
    const winPath = r'C:\Users\Me\Pictures\hero.png';
    final delta = jsonEncode(document([
      {
        'type': 'image',
        'data': {'url': winPath}
      },
    ]));

    final out = rewriteMediaPaths(delta, [
      const RestoredMedia(
        attachmentId: 'img-1',
        originalFilePath: winPath,
        newFilePath: '/data/app/attachments/img-1.png',
      ),
    ]);

    expect(out, isNot(contains('C:')));
    expect(out, contains('/data/app/attachments/img-1.png'));
  });

  test('non-JSON delta falls back to literal path replacement', () {
    const oldPath = r'C:\Users\Me\hero.png';
    final out = rewriteMediaPaths('body {{$oldPath}} tail', [
      const RestoredMedia(
        attachmentId: 'img-1',
        originalFilePath: r'C:\Users\Me\hero.png',
        newFilePath: '/data/hero.png',
      ),
    ]);
    expect(out, 'body {{/data/hero.png}} tail');
    expect(out, contains('/data/hero.png'));
    expect(out, isNot(contains('C:')));
  });

  test('returns input unchanged when nothing needs rewriting', () {
    const delta = '{"ops":[{"insert":"hi"}]}';
    final out = rewriteMediaPaths(delta, [
      const RestoredMedia(
        attachmentId: 'img-1',
        originalFilePath: '/unused/a.png',
        newFilePath: '/unused/a.png',
      ),
    ]);
    expect(out, same(delta));
  });
}
