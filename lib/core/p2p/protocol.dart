import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Wire constants for the HabitNow peer protocol (v1).
abstract final class Protocol {
  static const int version = 1;

  /// UDP port for presence broadcasts.
  static const int discoveryPort = 45102;

  /// TCP port for peer sessions.
  static const int sessionPort = 45103;

  /// Magic prefix on every UDP datagram — stale/foreign packets are dropped.
  static const String advMagic = 'HNADV1';

  static Map<String, dynamic> hello(ProfileWire me) => <String, dynamic>{
        't': 'hello',
        'v': version,
        'profile': me.toJson(),
      };

  static Map<String, dynamic> syncRequest() => <String, dynamic>{'t': 'sync.request'};

  static Map<String, dynamic> bye() => <String, dynamic>{'t': 'bye'};
}

/// The small public slice of a profile that crosses the wire.
class ProfileWire {
  const ProfileWire(this.id, this.name, this.emoji, this.colorSeed);

  final String id;
  final String name;
  final String emoji;
  final int colorSeed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorSeed': colorSeed,
      };

  factory ProfileWire.fromJson(Map<String, dynamic> j) => ProfileWire(
        j['id'] as String,
        j['name'] as String? ?? 'Friend',
        j['emoji'] as String? ?? '🙂',
        ((j['colorSeed'] as num?) ?? 0).toInt(),
      );

  /// UDP advertisement payload.
  Map<String, dynamic> toAdv() => <String, dynamic>{
        'm': Protocol.advMagic,
        't': 'adv',
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorSeed': colorSeed,
      };

  static ProfileWire? tryParseAdv(Map<String, dynamic> j) {
    if (j['m'] != Protocol.advMagic || j['t'] != 'adv') return null;
    final String? id = j['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return ProfileWire(
      id,
      j['name'] as String? ?? 'Friend',
      j['emoji'] as String? ?? '🙂',
      ((j['colorSeed'] as num?) ?? 0).toInt(),
    );
  }
}

/// Length-prefixed JSON framing over a TCP stream.
///
/// Frame = 4-byte big-endian payload length + UTF-8 JSON payload.
/// Guards against absurd frames (64 KiB cap) from misbehaving peers.
class FrameReader {
  FrameReader({this.maxFrameBytes = 64 * 1024});

  final int maxFrameBytes;
  final BytesBuilder _buf = BytesBuilder(copy: true);

  /// Feeds raw socket bytes; returns every complete JSON message found.
  List<Map<String, dynamic>> push(List<int> chunk) {
    _buf.add(chunk);
    final Uint8List data = _buf.takeBytes();
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final ByteData bd = ByteData.sublistView(data);
    int cursor = 0;
    while (data.length - cursor >= 4) {
      final int len = bd.getUint32(cursor, Endian.big);
      if (len <= 0 || len > maxFrameBytes) {
        throw const FormatException('protocol: frame out of range');
      }
      if (data.length - cursor - 4 < len) break; // partial frame — wait
      final String payload =
          utf8.decode(data.sublist(cursor + 4, cursor + 4 + len));
      cursor += 4 + len;
      try {
        final dynamic decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) out.add(decoded);
      } on FormatException {
        // Ignore malformed payloads; the session stays alive.
      }
    }
    if (data.length - cursor > 0) {
      _buf.add(data.sublist(cursor));
    }
    return out;
  }
}

/// Encodes a JSON map into one wire frame.
Uint8List encodeFrame(Map<String, dynamic> message) {
  final Uint8List payload = Uint8List.fromList(utf8.encode(jsonEncode(message)));
  final Uint8List frame = Uint8List(4 + payload.length);
  ByteData.sublistView(frame).setUint32(0, payload.length, Endian.big);
  frame.setAll(4, payload);
  return frame;
}

/// Convenience: one-shot decode of a UDP datagram, null if not ours.
Map<String, dynamic>? tryDecodeDatagram(Datagram d) {
  if (d.data.isEmpty) return null;
  try {
    final dynamic decoded = jsonDecode(utf8.decode(d.data));
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // foreign traffic — ignore
  }
  return null;
}
