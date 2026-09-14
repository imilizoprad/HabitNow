import 'dart:async';
import 'dart:io';

import 'discovery.dart';
import 'protocol.dart';
import 'session.dart';

/// The peer-to-peer conductor.
///
/// Owns discovery + the session server and maintains at most one session
/// per peer. Every session (incoming or outgoing) registers itself through
/// the same path, and duplicate connections — an inevitable race when both
/// peers dial each other — are resolved deterministically: the peer with
/// the lexicographically larger id keeps the outgoing connection, the
/// smaller keeps the incoming one. Both sides compute the same answer, so
/// exactly one connection survives on each side.
///
/// The engine is deliberately ignorant of domain models — the app wires in
/// [collectSyncState] / [applyRemote], keeping this layer reusable.
class SyncEngine {
  SyncEngine({required this.me});

  final ProfileWire Function() me;

  /// Builds the full state payload for a peer's initial sync.
  Map<String, dynamic> Function(String forPeerId)? collectSyncState;

  /// Applies any remote message. Must be idempotent + LWW-safe.
  void Function(Map<String, dynamic> message, String fromPeerId)? applyRemote;

  /// Should we auto-connect to this visible peer? (e.g. existing friend)
  bool Function(String peerId)? shouldAutoConnect;

  /// Live peer bookkeeping surfaced to the UI.
  void Function()? onPeersChanged;

  late final PeerDiscovery discovery = PeerDiscovery(me);
  late final PeerServer server = PeerServer(_accept);

  final Map<String, PeerSession> _sessions = <String, PeerSession>{};
  final Map<String, Timer> _retries = <String, Timer>{};
  final Set<String> _dialing = <String>{};
  StreamSubscription<void>? _discoverySub;
  Timer? _pruneTimer;
  bool _closed = false;

  /// Peer ids with a live, handshook session.
  Set<String> get connectedPeers => _sessions.keys.toSet();

  PeerSession? sessionTo(String peerId) => _sessions[peerId];

  /// Returns true when the session server bound its port (false = another
  /// instance holds it; discovery + outgoing dials still work).
  Future<bool> start() async {
    final bool bound = await server.start();
    await discovery.start();
    _discoverySub = discovery.changes.listen((_) {
      onPeersChanged?.call();
      _autoConnectVisible();
    });
    _pruneTimer = Timer.periodic(const Duration(seconds: 3), (Timer _) {
      discovery.snapshot(); // prunes internally
      onPeersChanged?.call();
    });
    _autoConnectVisible();
    return bound;
  }

  void _accept(PeerSession s) {
    _wire(s);
    s.sendHello(me());
  }

  void _wire(PeerSession s) {
    s.onMessage = (Map<String, dynamic> m) => _onMessage(s, m);
    s.onClosed = _onSessionClosed;
  }

  void _onMessage(PeerSession s, Map<String, dynamic> m) {
    // First authenticated message from a handshook session registers it.
    if (s.peer != null && !_sessions.containsKey(s.peer!.id)) {
      _register(s, s.peer!);
    }
    final String peerId = s.peer!.id;
    switch (m['t']) {
      case 'sync.request':
        s.send(collectSyncState?.call(peerId) ??
            <String, dynamic>{'t': 'sync.state'});
      case 'sync.state':
      case 'checkin.delta':
      case 'challenge.offer':
      case 'challenge.response':
      case 'forfeit.offer':
      case 'forfeit.status':
      case 'chat':
        applyRemote?.call(m, peerId);
      case 'bye':
        s.close();
    }
  }

  void _register(PeerSession s, ProfileWire wire) {
    if (wire.id == me().id) {
      unawaited(s.close()); // talking to ourselves (device loopback quirk)
      return;
    }
    final PeerSession? existing = _sessions[wire.id];
    if (existing != null) {
      // Deterministic duplicate rule: bigger id keeps outgoing.
      final bool keepOutgoing = me().id.compareTo(wire.id) > 0;
      final bool keepNew = s.isIncoming != keepOutgoing;
      if (keepNew) {
        _sessions[wire.id] = s;
        unawaited(existing.close());
      } else {
        unawaited(s.close());
        return;
      }
    } else {
      _sessions[wire.id] = s;
    }
    _retries.remove(wire.id)?.cancel();
    onPeersChanged?.call();
    s.send(Protocol.syncRequest());
  }

  void _onSessionClosed(PeerSession dead) {
    _sessions.removeWhere((String _, PeerSession v) => v == dead);
    onPeersChanged?.call();
    if (_closed || dead.peer == null) return;
    final String peerId = dead.peer!.id;
    // A visible peer dropped us — retry shortly while they keep advertising.
    final VisiblePeer? vp = discovery.peerById(peerId);
    if (vp != null && shouldAutoConnect?.call(peerId) == true) {
      _retries.remove(peerId)?.cancel();
      _retries[peerId] = Timer(const Duration(seconds: 4), () {
        if (!_closed) unawaited(connect(vp.address, peerId));
      });
    }
  }

  void _autoConnectVisible() {
    for (final VisiblePeer vp in discovery.snapshot()) {
      if (shouldAutoConnect?.call(vp.wire.id) == true) {
        unawaited(connect(vp.address, vp.wire.id));
      }
    }
  }

  /// Dial a peer by address. Registration happens once their hello lands
  /// (see [_onMessage]); a no-op if we're already dialing that peer.
  Future<void> connect(String address, String peerId) async {
    if (_closed ||
        _sessions.containsKey(peerId) ||
        _dialing.contains(peerId)) {
      return;
    }
    _dialing.add(peerId);
    try {
      final PeerSession s = await connectToPeer(address);
      _wire(s);
      s.sendHello(me());
      // If their hello never arrives the session's watchdog closes it;
      // discovery will re-offer the peer and we retry.
    } on SocketException {
      // Peer unreachable; discovery retries when they re-appear.
    } finally {
      _dialing.remove(peerId);
    }
  }

  /// Send to a connected peer; false when they're offline (state converges
  /// via the next sync instead of queuing).
  bool sendTo(String peerId, Map<String, dynamic> message) {
    final PeerSession? s = _sessions[peerId];
    if (s == null) return false;
    s.send(message);
    return true;
  }

  /// Best-effort fan-out to every connected peer.
  void broadcast(Map<String, dynamic> message) {
    for (final PeerSession s in _sessions.values) {
      s.send(message);
    }
  }

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    _pruneTimer?.cancel();
    unawaited(_discoverySub?.cancel());
    for (final Timer t in _retries.values) {
      t.cancel();
    }
    _retries.clear();
    for (final PeerSession s in _sessions.values) {
      s.send(Protocol.bye());
      unawaited(s.close());
    }
    _sessions.clear();
    await discovery.stop();
    await server.stop();
  }
}
