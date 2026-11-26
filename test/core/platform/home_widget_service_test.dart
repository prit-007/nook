import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/home_widget_service.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';

class _FakeBridge implements HomeWidgetBridge {
  final Map<String, Object?> saved = {};
  bool updated = false;

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    saved[id] = data;
    return true;
  }

  @override
  Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
  }) async {
    updated = true;
    return true;
  }

  @override
  Stream<Uri?> get widgetClicked => const Stream.empty();
}

Note _note(
  String id,
  String title, {
  bool pinned = false,
  bool locked = false,
  bool deleted = false,
}) {
  final now = DateTime(2026, 11, 26);
  return Note(
    id: id,
    type: NoteType.text,
    title: title,
    plainText: 'Body of $title',
    pinned: pinned,
    locked: locked,
    deleted: deleted,
    createdAt: now,
    updatedAt: now,
    deviceOriginId: 'd1',
    syncVersion: 1,
  );
}

void main() {
  test('syncPinnedNotes excludes locked and deleted notes', () async {
    final bridge = _FakeBridge();
    final service = HomeWidgetService(bridge: bridge);

    await service.syncPinnedNotes([
      _note('1', 'Public Pin', pinned: true),
      _note('2', 'Secret Pin', pinned: true, locked: true),
      _note('3', 'Deleted Pin', pinned: true, deleted: true),
      _note('4', 'Unpinned', pinned: false),
    ]);

    expect(bridge.updated, isTrue);
    expect(bridge.saved['pinned_count'], 1);
    final list =
        jsonDecode(bridge.saved['pinned_notes_json'] as String) as List;
    expect(list, hasLength(1));
    expect((list.first as Map)['title'], 'Public Pin');
  });

  test('resolveRouteFromUri maps capture and note deep links', () {
    expect(
      HomeWidgetService.resolveRouteFromUri(
        Uri.parse('nook://capture?type=checklist'),
      ),
      '/note/new?type=checklist',
    );
    expect(
      HomeWidgetService.resolveRouteFromUri(
        Uri.parse('nook://note/abc-123'),
      ),
      '/note/abc-123',
    );
    expect(
      HomeWidgetService.resolveRouteFromUri(Uri.parse('https://example.com')),
      isNull,
    );
  });
}
