import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight MethodChannel wrapper for Android 13+ nearby permissions.
/// Avoids the heavy `permission_handler` dependency and AGP 9 Gradle conflicts.
class NearbyPermissions {
  static const _channel = MethodChannel('com.nook/nearby_permissions');

  /// Returns true if all nearby permissions are already granted.
  static Future<bool> check() async {
    if (kIsWeb) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('checkNearbyPermissions');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Requests nearby permissions from the user. Returns true if granted.
  /// On Android 13+: NEARBY_WIFI_DEVICES, BLUETOOTH_SCAN, BLUETOOTH_CONNECT.
  /// On Android 12-: ACCESS_FINE_LOCATION, BLUETOOTH_SCAN, BLUETOOTH_CONNECT.
  static Future<bool> request() async {
    if (kIsWeb) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('requestNearbyPermissions');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  /// Returns true if Wi-Fi is enabled on the device (Android only).
  static Future<bool> isWifiEnabled() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isWifiEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
