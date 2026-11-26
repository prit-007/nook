import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/database.dart';

/// Abstraction over `package:home_widget` for unit testing.
abstract class HomeWidgetBridge {
  Future<bool?> saveWidgetData<T>(String id, T? data);
  Future<bool?> updateWidget(
      {String? name, String? androidName, String? iOSName});
  Future<Uri?> initiallyLaunchedFromHomeWidget();
  Stream<Uri?> get widgetClicked;
}

class DefaultHomeWidgetBridge implements HomeWidgetBridge {
  const DefaultHomeWidgetBridge();

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) =>
      HomeWidget.saveWidgetData<T>(id, data);

  @override
  Future<bool?> updateWidget({
    String? name,
    String? androidName,
    String? iOSName,
  }) =>
      HomeWidget.updateWidget(
        name: name,
        androidName: androidName,
        iOSName: iOSName,
      );

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}

/// Syncs pinned non-locked notes and quick-capture deep links to OS home
/// screen widgets (Android AppWidget / iOS WidgetKit).
class HomeWidgetService {
  HomeWidgetService({HomeWidgetBridge? bridge})
      : _bridge = bridge ?? const DefaultHomeWidgetBridge();

  static const String androidProviderName = 'NookWidgetProvider';
  static const String iOSWidgetName = 'NookWidget';

  final HomeWidgetBridge _bridge;

  /// Pushes up to 5 pinned, non-deleted, non-locked notes to the home widget.
  /// Locked notes are excluded so private titles/previews never leak onto the
  /// device home screen.
  Future<void> syncPinnedNotes(List<Note> notes) async {
    if (kIsWeb) return;
    final pinned = notes
        .where((n) => n.pinned && !n.deleted && !n.locked)
        .take(5)
        .map(
          (n) => {
            'id': n.id,
            'title': n.title.trim().isEmpty ? 'Untitled' : n.title.trim(),
            'preview': (n.plainText ?? '').trim().split('\n').first,
          },
        )
        .toList();

    try {
      await _bridge.saveWidgetData<String>(
        'pinned_notes_json',
        jsonEncode(pinned),
      );
      await _bridge.saveWidgetData<int>('pinned_count', pinned.length);
      await _bridge.saveWidgetData<String>(
        'pinned_summary',
        pinned.isEmpty
            ? 'Tap + to capture a thought'
            : pinned.map((p) => '• ${p['title']}').join('\n'),
      );
      await _bridge.updateWidget(
        androidName: androidProviderName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {
      // Safe no-op on unsupported desktop/test platforms without widget host.
    }
  }

  /// Maps a widget launch URI (e.g. `nook://capture?type=text` or
  /// `nook://note/<id>`) to an in-app GoRouter route.
  static String? resolveRouteFromUri(Uri? uri) {
    if (uri == null || uri.scheme != 'nook') return null;
    if (uri.host == 'capture') {
      final type = uri.queryParameters['type'] ?? 'text';
      return '/note/new?type=$type';
    }
    if (uri.host == 'note' && uri.pathSegments.isNotEmpty) {
      return '/note/${uri.pathSegments.first}';
    }
    return null;
  }

  Future<Uri?> getInitialLaunchUri() =>
      _bridge.initiallyLaunchedFromHomeWidget();

  Stream<Uri?> get widgetClicks => _bridge.widgetClicked;
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => HomeWidgetService(),
);
