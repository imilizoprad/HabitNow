import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'protocol.dart';

/// A live connection to one peer.
///
/// Handshake: the engine sends `hello` immediately on creation (both for
/// incoming and outgoing sessions); until the peer's hello arrives the
/// session is unusable. A watchdog closes half-open sessions after 6s so
/// port-scanners or dead sockets can't wedge the engine.
class PeerSession {
  PeerSession._(this._socket, {required this.isIncoming}) {
    _reader = FrameReader();
    _socket
      ..setOption(SocketOption.tcpNoDelay, true)
      ..listen(_onData,
          onError: (Object e) => close(),
          onDone: close,
          cancelOnError: true);
    // Handshake watchdog.
    Timer(const Duration(seconds: 6), () {
      if (!_closed && _handshook.isCompleted != true && peer == null) {
        close();
      }
    });
  }

  final Socket _socket;
  late final FrameReader _reader;

  /// Peer identity — null until the handshake completes.
  ProfileWire? peer;

  final Completer<ProfileWire> _handshook = Completer<ProfileWire>();

  /// Fired for every decoded message after the handshake.
  void Function(Map<String, dynamic> message)? onMessage;

  /// Fired exactly once when the session dies, for any reason.
  void Function(PeerSession session)? onClosed;

  final bool isIncoming;
  bool _closed = false;

  static Future<PeerSession> fromSocket(
    Socket socket, {
    required bool isIncoming,
  }) async =>
      PeerSession._(socket, isIncoming: isIncoming);

  /// Completes the local half of the handshake.
  void sendHello(ProfileWire me) => send(Protocol.hello(me));

  void send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      final Uint8List frame = encodeFrame(message);
      _socket.add(frame);
    } on SocketException {
      close();
    }
  }

  void _onData(Uint8List chunk) {
    if (_closed) return;
    final List<Map<String, dynamic>> messages;
    try {
      messages = _reader.push(chunk);
    } on FormatException {
      close();
      return;
    }
    for (final Map<String, dynamic> m in messages) {
      if (peer == null) {
        if (m['t'] != 'hello') {
          close();
          return;
        }
        final dynamic p = m['profile'];
        final String? id = p is Map<String, dynamic> ? p['id'] as String? : null;
        if (id == null || id.isEmpty) {
          close();
          return;
        }
        peer = ProfileWire.fromJson(p as Map<String, dynamic>);
        if (!_handshook.isCompleted) _handshook.complete(peer);
        continue;
      }
      onMessage?.call(m);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.flush();
      _socket.destroy();
    } on SocketException {
      // already gone
    }
    onClosed?.call(this);
  }
}

/// Listens for incoming peers on the session port.
class PeerServer {
  PeerServer(this.onSession);

  /// Called for every accepted (pre-handshake) socket.
  final void Function(PeerSession session) onSession;
  ServerSocket? _server;

  Future<bool> start() async {
    try {
      _server = await ServerSocket.bind(
          InternetAddress.anyIPv4, Protocol.sessionPort);
    } on SocketException {
      // Another instance holds the port (dev double-run); degrade quietly.
      return false;
    }
    _server!.listen((Socket s) {
      PeerSession.fromSocket(s, isIncoming: true).then(onSession);
    });
    return true;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}

/// Dials a peer by IP.
Future<PeerSession> connectToPeer(String host,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final Socket socket = await Socket.connect(host, Protocol.sessionPort,
      timeout: timeout);
  return PeerSession.fromSocket(socket, isIncoming: false);
}
