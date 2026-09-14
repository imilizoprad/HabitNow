import 'common.dart';

/// The local user. One per install; broadcast to peers during discovery.
class Profile implements Synced {
  @override
  int updatedAt;
  @override
  String updatedBy;

  Profile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorSeed,
    required this.updatedAt,
    required this.updatedBy,
  });

  /// Stable device identity — also used as the actor id in sync metadata.
  final String id;
  String name;

  /// Avatar emoji — playful, zero-asset, and identical across peers.
  String emoji;
  int colorSeed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorSeed': colorSeed,
        'updatedAt': updatedAt,
        'updatedBy': updatedBy,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String? ?? '🙂',
        colorSeed: (j['colorSeed'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        updatedBy: j['updatedBy'] as String? ?? j['id'] as String,
      );

  Profile copyWith({String? name, String? emoji, int? colorSeed}) => Profile(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        colorSeed: colorSeed ?? this.colorSeed,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        updatedBy: id,
      );

  @override
  String toString() => 'Profile($id, $name)';
}

/// A peer this device has met on the network. Purely local knowledge —
/// never broadcast — used to re-render friend lists between sessions.
class FriendRecord {
  FriendRecord({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorSeed,
    required this.firstSeen,
    required this.lastSeen,
    this.lastAddress,
    this.metAt,
  });

  final String id;
  String name;
  String emoji;
  int colorSeed;

  final int firstSeen;
  int lastSeen;

  /// Last IPv4 endpoint that answered a handshake, for quick reconnects.
  String? lastAddress;

  /// Set the first time a real session (sync) happened with this peer —
  /// "seen on the network" alone doesn't make someone a friend.
  int? metAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'emoji': emoji,
        'colorSeed': colorSeed,
        'firstSeen': firstSeen,
        'lastSeen': lastSeen,
        'lastAddress': lastAddress,
        'metAt': metAt,
      };

  factory FriendRecord.fromJson(Map<String, dynamic> j) => FriendRecord(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Friend',
        emoji: j['emoji'] as String? ?? '🙂',
        colorSeed: (j['colorSeed'] as num?)?.toInt() ?? 0,
        firstSeen: (j['firstSeen'] as num?)?.toInt() ?? 0,
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
        lastAddress: j['lastAddress'] as String?,
        metAt: (j['metAt'] as num?)?.toInt(),
      );
}
