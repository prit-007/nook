import 'package:flutter/services.dart';

/// Holds Android's `WifiManager.MulticastLock` while LAN discovery is running.
///
/// Android Wi-Fi drivers drop inbound multicast frames unless a MulticastLock
/// is held, which silently kills mDNS discovery (both the PTR query and its
/// response). The lock is acquired through a platform channel on
/// `MainActivity.kt`; on every other platform (or when the channel is missing,
/// e.g. in unit tests) these calls are no-ops.
class MulticastLock {
  MulticastLock._();

  static const MethodChannel _channel =
      MethodChannel('com.nook/multicast_lock');

  /// Best-effort acquire — never throws; tests and non-Android platforms just
  /// no-op.
  static Future<void> acquire() async {
    try {
      await _channel.invokeMethod<void>('acquire');
    } catch (_) {
      // No-op: desktop/tests or platform not wired up.
    }
  }

  /// Best-effort release.
  static Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {
      // No-op.
    }
  }
}
