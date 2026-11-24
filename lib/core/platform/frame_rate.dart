import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Method channel for requesting high refresh rate on Android.
const MethodChannel frameRateChannel = MethodChannel('nook/frame_rate');

/// Internal seam for testing on non-Android host platforms.
@visibleForTesting
bool debugOverrideIsAndroid = false;

/// Request a high refresh rate (e.g., 120 Hz) on Android devices that support
/// it. Returns [true] if the request was dispatched successfully, [false]
/// otherwise. On non-Android platforms this is a no-op that returns [false].
Future<bool> requestHighRefreshRate() async {
  if (!Platform.isAndroid && !debugOverrideIsAndroid) return false;
  try {
    await frameRateChannel.invokeMethod('setFrameRate', 120);
    return true;
  } on PlatformException {
    return false;
  }
}
