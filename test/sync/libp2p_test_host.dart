import 'package:dart_libp2p/config/config.dart' as p2p_config;
import 'package:dart_libp2p/core/crypto/ed25519.dart' as crypto_ed25519;
import 'package:dart_libp2p/core/host/host.dart';
import 'package:dart_libp2p/core/multiaddr.dart';
import 'package:dart_libp2p/core/network/network.dart' show Reachability;
import 'package:dart_libp2p/p2p/security/noise/noise_protocol.dart';
import 'package:dart_libp2p/p2p/transport/connection_manager.dart'
    as p2p_conn_manager;
import 'package:dart_libp2p/p2p/transport/udx_transport.dart';
import 'package:dart_udx/dart_udx.dart';

/// Builds a libp2p host with UDX transport and Noise security, listening on a
/// random loopback UDP port. Loopback UDX is testable in CI without multicast.
///
/// AutoNAT ambient probing and hole punching are disabled (forced private
/// reachability skips the ambient dials a LAN-only app never wants).
Future<Host> createLoopbackHost() async {
  final keyPair = await crypto_ed25519.generateEd25519KeyPair();
  final udx = UDX();
  final connMgr = p2p_conn_manager.ConnectionManager();

  final options = <p2p_config.Option>[
    p2p_config.Libp2p.identity(keyPair),
    p2p_config.Libp2p.connManager(connMgr),
    p2p_config.Libp2p.transport(
      UDXTransport(connManager: connMgr, udxInstance: udx),
    ),
    p2p_config.Libp2p.security(await NoiseSecurity.create(keyPair)),
    p2p_config.Libp2p.listenAddrs([MultiAddr('/ip4/127.0.0.1/udp/0/udx')]),
    // Keep loopback addrs: the default factory strips them, which would make
    // loopback dials fail with "No addresses found for peer".
    p2p_config.Libp2p.addrsFactory((addrs) => addrs),
    // applyDefaults() hard-sets enableAutoNAT=true after options are applied,
    // so the only way to stop it dialing public peers is to force a private
    // reachability, which skips the ambient probing orchestrator.
    p2p_config.Libp2p.forceReachability(Reachability.private),
    p2p_config.Libp2p.holePunching(false),
  ];

  final host = await p2p_config.Libp2p.new_(options);
  await host.start();
  return host;
}

/// Returns the first loopback UDX multiaddr for [host], or null.
///
/// Uses `network.listenAddresses` because `host.addrs` applies the default
/// addrs factory which strips loopback addresses.
String? loopbackUdxAddr(Host host) {
  for (final addr in host.network.listenAddresses) {
    if (addr.valueForProtocol('ip4') == '127.0.0.1' &&
        addr.hasProtocol('udx')) {
      return addr.toString();
    }
  }
  return null;
}
