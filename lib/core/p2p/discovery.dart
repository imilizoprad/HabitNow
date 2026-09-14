import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// A peer visible on the local network right now.
@immutable
class VisiblePeer {
  const VisiblePeer({
    required this.wire,
    required this.address,
    required this.lastSeen,
  });

  final ProfileWire wire;
  final String address;
  final DateTime lastSeen;

  bool isFresh(Duration ttl, DateTime now) =>
      now.difference(lastSeen) < ttl;
}

/// LAN presence via UDP broadcast.
///
/// Every ~2.5s we announce ourselves on 255.255.255.255:45102 and listen
/// for the same. Peers that keep advertising are "visible". Hotspots and
/// home routers both work; AP-isolated networks won't (the UI surfaces
/// manual IP connect as the escape hatch).
class PeerDiscovery {
  PeerDiscovery(this.me);

  final ProfileWire Function() me;
  RawDatagramSocket? _socket;
  Timer? _ticker;

  final Map<String, VisiblePeer> _visible = <String, VisiblePeer>{};

  /// Unique peers seen within the freshness window (self excluded).
  List<VisiblePeer> snapshot() {
    final DateTime now = DateTime.now();
    final List<VisiblePeer> out = <VisiblePeer>[];
    _visible.removeWhere((String id, VisiblePeer p) => !p.isFresh(
        const Duration(seconds: 9), now));
    for (final VisiblePeer p in _visible.values) {
      out.add(p);
    }
    return out;
  }

  VisiblePeer? peerById(String id) => _visible[id];

  /// Fires whenever the visible set changes (add / refresh / prune).
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  static const Duration _interval = Duration(milliseconds: 2500);

  Future<void> start() async {
    if (_socket != null) return;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        Protocol.discoveryPort,
        reuseAddress: true,
        reusePort: false,
      );
    } on SocketException {
      // Port taken (e.g. two instances on one device): run listen-only.
      try {
        _socket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4, Protocol.discoveryPort + 7);
      } on SocketException {
        return; // Discovery unavailable; manual connect still works.
      }
    }
    _socket!.broadcastEnabled = true;
    _socket!.listen((RawSocketEvent e) {
      final RawDatagramSocket s = _socket!;
      if (e == RawSocketEvent.read) {
        final Datagram? d = s.receive();
        if (d != null) _onDatagram(d);
      }
    });
    _ticker = Timer.periodic(_interval, (Timer _) => _advertise());
    _advertise();
  }

  void _advertise() {
    final RawDatagramSocket? s = _socket;
    if (s == null) return;
    try {
      final List<int> bytes =
          utf8.encode(jsonEncode(me().toAdv()));
      s.send(bytes, InternetAddress('255.255.255.255'),
          Protocol.discoveryPort);
    } on SocketException {
      // Network dropped; the ticker retries.
    }
  }

  void _onDatagram(Datagram d) {
    if (d.address.type != InternetAddressType.IPv4) return;
    final Map<String, dynamic>? msg = tryDecodeDatagram(d);
    if (msg == null) return;
    final ProfileWire? adv = ProfileWire.tryParseAdv(msg);
    if (adv == null || adv.id == me().id) return;
    final bool known = _visible.containsKey(adv.id);
    _visible[adv.id] = VisiblePeer(
      wire: adv,
      address: d.address.address,
      lastSeen: DateTime.now(),
    );
    if (!known) _changes.add(null);
  }

  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _socket?.close();
    _socket = null;
    _visible.clear();
    await _changes.close();
  }
}
