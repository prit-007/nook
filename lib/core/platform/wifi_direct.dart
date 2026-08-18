import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../providers/talker_provider.dart';

/// A Nook service discovered over Wi-Fi Direct DNS-SD.
///
/// The receiver registers `_syncnotenet._tcp` (the same service Nook mDNS
/// uses, over the Wi-Fi Direct link) carrying its dialable multiaddr in the
/// `dnsaddr` TXT record, so a sender that is NOT on the same Wi-Fi network
/// can still find and dial it — the Quick Share mechanism, built on the
/// existing libp2p/UDX transport.
class WifiDirectService {
  const WifiDirectService({
    required this.instanceName,
    required this.deviceAddress,
    required this.txt,
  });

  final String instanceName;
  final String deviceAddress;
  final Map<String, String> txt;
}

/// The Wi-Fi Direct group created by the receiver (group owner = soft AP).
class WifiDirectGroup {
  const WifiDirectGroup({
    this.networkName = '',
    this.passphrase = '',
    this.ownerAddress = '',
  });

  final String networkName;
  final String passphrase;

  /// Group owner's IP on the P2P subnet (e.g. `192.168.49.1`), known once the
  /// group is formed.
  final String ownerAddress;

  bool get isFormed => ownerAddress.isNotEmpty;
}

/// Thin MethodChannel/EventChannel wrapper around the Android Wi-Fi Direct
/// bridge in `MainActivity.kt` (`com.nook/wifi_direct`).
///
/// Wi-Fi Direct creates an isolated P2P subnet between two Android devices
/// even when they are on different Wi-Fi networks; once joined, the existing
/// UDX/libp2p transport dials straight across it. No Nearby Connections API —
/// it is deprecated — just `WifiP2pManager` + the app's own transport.
///
/// All calls are no-ops on non-Android platforms.
class WifiDirect {
  WifiDirect._();

  static const MethodChannel _channel = MethodChannel('com.nook/wifi_direct');
  static const EventChannel _events =
      EventChannel('com.nook/wifi_direct/events');

  /// Whether the current platform can use Wi-Fi Direct at all.
  static bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  /// Builds the `dnsaddr` TXT value advertising a receiver's dialable multiaddr
  /// over the Wi-Fi Direct link: `/ip4/<owner>/udp/<udxPort>/udx/p2p/<peerId>`.
  /// The UDX host binds `0.0.0.0` so the same port is reachable on the P2P
  /// interface; [ownerAddress] is the group owner's IP (`192.168.49.1`).
  static String buildDnsaddr({
    required String ownerAddress,
    required String udxPort,
    required String peerId,
  }) =>
      '/ip4/$ownerAddress/udp/$udxPort/udx/p2p/$peerId';

  static final StreamController<WifiDirectService> _serviceController =
      StreamController.broadcast();
  static final StreamController<WifiDirectGroup> _groupController =
      StreamController.broadcast();
  static final StreamController<String> _errorController =
      StreamController.broadcast();
  static bool _listening = false;

  /// Nook services discovered over Wi-Fi Direct DNS-SD.
  static Stream<WifiDirectService> get serviceStream =>
      _serviceController.stream;

  /// Group/connection state changes (formed, owner address, etc.).
  static Stream<WifiDirectGroup> get groupStream => _groupController.stream;

  /// Non-fatal Wi-Fi Direct errors (for the sync logs).
  static Stream<String> get errorStream => _errorController.stream;

  static void _ensureListener() {
    if (_listening) return;
    _listening = true;
    _events.receiveBroadcastStream().listen(
      (event) {
        try {
          final map = Map<String, dynamic>.from(event as Map);
          switch (map['event']) {
            case 'service':
              _serviceController.add(WifiDirectService(
                instanceName: map['instanceName'] as String? ?? '',
                deviceAddress: map['deviceAddress'] as String? ?? '',
                txt: Map<String, String>.from(
                  (map['txt'] as Map?)?.cast<String, String>() ?? const {},
                ),
              ));
            case 'group':
              _groupController.add(WifiDirectGroup(
                networkName: map['networkName'] as String? ?? '',
                passphrase: map['passphrase'] as String? ?? '',
                ownerAddress: map['ownerAddress'] as String? ?? '',
              ));
            case 'connection':
              _groupController.add(WifiDirectGroup(
                ownerAddress: map['groupOwnerAddress'] as String? ?? '',
              ));
            case 'error':
              _errorController
                  .add(map['message'] as String? ?? 'wifi direct error');
          }
        } catch (e) {
          nookLog(
            NookLogKey.sync,
            'wifi_direct event parse failed: $e',
            LogLevel.warning,
          );
        }
      },
      onError: (Object e) {
        nookLog(
          NookLogKey.sync,
          'wifi_direct event stream error: $e',
          LogLevel.warning,
        );
      },
    );
  }

  /// Creates a Wi-Fi Direct group on this device (group owner / soft AP).
  /// Returns the group details once created, or null when unsupported/failed.
  static Future<WifiDirectGroup?> createGroup() async {
    if (!isSupportedPlatform) return null;
    _ensureListener();
    try {
      final raw =
          await _channel.invokeMapMethod<String, dynamic>('createGroup');
      if (raw == null) return null;
      return WifiDirectGroup(
        networkName: raw['networkName'] as String? ?? '',
        passphrase: raw['passphrase'] as String? ?? '',
        ownerAddress: raw['ownerAddress'] as String? ?? '',
      );
    } catch (e) {
      nookLog(NookLogKey.sync, 'wifi_direct createGroup failed: $e',
          LogLevel.error);
      return null;
    }
  }

  /// Registers the Nook DNS-SD service (with the `dnsaddr` multiaddr in TXT)
  /// on the active group. Call after [createGroup] so the owner address is
  /// known. Returns false when unsupported.
  static Future<bool> registerService({
    required String instanceName,
    required Map<String, String> txt,
  }) async {
    if (!isSupportedPlatform) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('registerService', {
        'name': instanceName,
        'txt': txt,
      });
      return ok ?? false;
    } catch (e) {
      nookLog(NookLogKey.sync, 'wifi_direct registerService failed: $e',
          LogLevel.error);
      return false;
    }
  }

  /// Removes the group and its registered service.
  static Future<void> removeGroup() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('removeGroup');
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  /// Starts Wi-Fi Direct DNS-SD discovery for Nook services.
  static Future<void> discoverServices() async {
    if (!isSupportedPlatform) return;
    _ensureListener();
    try {
      await _channel.invokeMethod<void>('discoverServices');
    } catch (e) {
      nookLog(NookLogKey.sync, 'wifi_direct discoverServices failed: $e',
          LogLevel.error);
    }
  }

  /// Stops Wi-Fi Direct discovery.
  static Future<void> stopDiscovery() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('stopDiscovery');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Connects to the peer that owns [deviceAddress]'s group. The caller then
  /// waits on [joinGroup] or the group stream for the link to form.
  static Future<void> connect(String deviceAddress) async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('connect', {'address': deviceAddress});
    } catch (e) {
      nookLog(
          NookLogKey.sync, 'wifi_direct connect failed: $e', LogLevel.error);
    }
  }

  /// Cancels a pending connect.
  static Future<void> cancelConnect() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('cancelConnect');
    } catch (_) {
      // Best-effort.
    }
  }

  /// Requests the current connection info (owner address when a group is
  /// formed). Returns null when unsupported or not connected.
  static Future<String?> getOwnerAddress() async {
    if (!isSupportedPlatform) return null;
    try {
      return await _channel.invokeMethod<String>('getOwnerAddress');
    } catch (_) {
      return null;
    }
  }

  /// Joins [deviceAddress]'s Wi-Fi Direct group and waits until the P2P link
  /// is formed (or [timeout] elapses). Returns the group owner's IP, or null.
  static Future<String?> joinGroup(
    String deviceAddress, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (!isSupportedPlatform) return null;
    _ensureListener();
    final completer = Completer<String?>();
    StreamSubscription<WifiDirectGroup>? sub;
    Timer? timer;
    String? current;

    sub = groupStream.listen((group) {
      current = group.ownerAddress;
      if (group.ownerAddress.isNotEmpty && !completer.isCompleted) {
        completer.complete(group.ownerAddress);
      }
    });
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(current);
      }
    });

    await connect(deviceAddress);
    final owner = await completer.future;
    await sub.cancel();
    timer.cancel();
    return owner;
  }

  /// Stops discovery and removes the group (full cleanup).
  static Future<void> cleanup() async {
    await stopDiscovery();
    await removeGroup();
  }
}
