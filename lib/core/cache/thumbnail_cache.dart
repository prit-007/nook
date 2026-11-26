import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// In-memory LRU cache for note attachments, doodles, and media thumbnails.
///
/// Prevents redundant disk I/O on repeated card renders and smooths scrolling
/// in masonry grid and list layouts.
class ThumbnailCache {
  ThumbnailCache._();

  static final ThumbnailCache instance = ThumbnailCache._();

  /// Maximum number of in-memory thumbnails held before oldest entries are evicted.
  static const int defaultMaxEntries = 250;

  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();
  int maxEntries = defaultMaxEntries;

  /// Returns the current number of thumbnails cached in memory.
  int get count => _entries.length;

  /// Returns `true` if [filePath] is already cached in memory.
  bool isCached(String filePath) => _entries.containsKey(filePath);

  /// Retrieves the thumbnail bytes for [filePath].
  ///
  /// If already in memory, returns the cached bytes immediately and refreshes
  /// LRU position. Otherwise, reads the file from disk asynchronously and caches it.
  Future<Uint8List?> getBytes(String filePath) async {
    if (_entries.containsKey(filePath)) {
      final bytes = _entries.remove(filePath)!;
      _entries[filePath] = bytes;
      return bytes;
    }

    final file = File(filePath);
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      put(filePath, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Inserts [bytes] into the memory cache for [filePath], evicting the oldest
  /// entry if [maxEntries] is reached.
  void put(String filePath, Uint8List bytes) {
    if (_entries.containsKey(filePath)) {
      _entries.remove(filePath);
    } else if (_entries.length >= maxEntries && _entries.isNotEmpty) {
      _entries.remove(_entries.keys.first);
    }
    _entries[filePath] = bytes;
  }

  /// Clears all cached in-memory thumbnails.
  void clear() {
    _entries.clear();
  }

  /// Convenience widget builder for an in-memory cached thumbnail with fallback.
  Widget buildThumbnail({
    required String filePath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // If bytes are already warm in memory, render Image.memory synchronously to avoid any flicker.
    if (_entries.containsKey(filePath)) {
      return Image.memory(
        _entries[filePath]!,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: 400,
        cacheHeight: 400,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: getBytes(filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: 400,
            cacheHeight: 400,
          );
        }
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data == null) {
          return errorWidget ?? const SizedBox.shrink();
        }
        return placeholder ??
            Image.file(
              File(filePath),
              width: width,
              height: height,
              fit: fit,
              cacheWidth: 400,
              cacheHeight: 400,
            );
      },
    );
  }
}
