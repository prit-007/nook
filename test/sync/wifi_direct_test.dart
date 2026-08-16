import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/wifi_direct.dart';
import 'package:nook/sync/transport/sync_transport.dart';

void main() {
  group('SyncDevice.fromWifiDirectService', () {
    const txt = {
      'dnsaddr': '/ip4/192.168.49.1/udp/53214/udx/p2p/12D3KooWabcdefghijk',
      'name': 'Galaxy S24',
    };

    test('maps a Wi-Fi Direct DNS-SD service to a dialable device', () {
      final device = SyncDevice.fromWifiDirectService(
        instanceName: 'nook-Galaxy S24',
        deviceAddress: 'aa:bb:cc:dd:ee:ff',
        txt: txt,
      );

      expect(device, isNotNull);
      expect(device!.deviceId, '12D3KooWabcdefghijk');
      expect(device.deviceName, 'Galaxy S24');
      expect(device.transportType, 'wifi-direct');
      expect(device.wifiDirectAddress, 'aa:bb:cc:dd:ee:ff');
      expect(device.multiaddresses, ['/ip4/192.168.49.1/udp/53214/udx']);
    });

    test('returns null for a service without a dnsaddr record', () {
      final device = SyncDevice.fromWifiDirectService(
        instanceName: 'nook-Someone',
        deviceAddress: 'aa:bb:cc:dd:ee:ff',
        txt: const {},
      );

      expect(device, isNull);
    });

    test('returns null for a malformed dnsaddr (no peer id)', () {
      final device = SyncDevice.fromWifiDirectService(
        instanceName: 'nook-Someone',
        deviceAddress: 'aa:bb:cc:dd:ee:ff',
        txt: const {'dnsaddr': '/ip4/192.168.49.1/udp/53214/udx'},
      );

      expect(device, isNull);
    });

    test('falls back to the instance name when no friendly name TXT', () {
      final device = SyncDevice.fromWifiDirectService(
        instanceName: 'nook-Pixel 8',
        deviceAddress: '11:22:33:44:55:66',
        txt: const {
          'dnsaddr': '/ip4/192.168.49.1/udp/4001/udx/p2p/peer123',
        },
      );

      expect(device, isNotNull);
      expect(device!.deviceName, 'nook-Pixel 8');
    });

    test('wifi-direct devices are distinct from libp2p devices with same id',
        () {
      final wifiDirect = SyncDevice.fromWifiDirectService(
        instanceName: 'nook-X',
        deviceAddress: 'aa:bb:cc:dd:ee:ff',
        txt: txt,
      )!;
      const libp2p = SyncDevice(
        deviceId: '12D3KooWabcdefghijk',
        deviceName: 'Galaxy S24',
        isOnline: true,
      );

      expect(wifiDirect, isNot(equals(libp2p)));
    });
  });

  group('WifiDirect platform gating (all platforms)', () {
    test('is supported only on Android', () {
      // Runs on the host platform during `flutter test`. On Android/CI the
      // expectation flips; the point is that the gate is a single check that
      // all other platforms (linux, ios, macos, windows, web) treat as false.
      expect(WifiDirect.isSupportedPlatform, !kIsWeb && Platform.isAndroid);
    });

    test('every non-Android platform is a safe no-op', () {
      if (WifiDirect.isSupportedPlatform) return; // covered by Android tests
      // On any non-Android host these must never throw or touch the network:
      expect(
          WifiDirect.buildDnsaddr(
            ownerAddress: '192.168.49.1',
            udxPort: '4001',
            peerId: 'peer123',
          ),
          '/ip4/192.168.49.1/udp/4001/udx/p2p/peer123');
    });
  });

  group('WifiDirect.buildDnsaddr', () {
    test('builds a dialable multiaddr with peer id', () {
      expect(
        WifiDirect.buildDnsaddr(
          ownerAddress: '192.168.49.1',
          udxPort: '53214',
          peerId: '12D3KooWabcdefghijk',
        ),
        '/ip4/192.168.49.1/udp/53214/udx/p2p/12D3KooWabcdefghijk',
      );
    });
  });
}
