import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/p2p/discovery.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/profile.dart';
import '../../state/app_store.dart';
import 'challenge_create_sheet.dart' show showChallengeCreatorFromPeer;
import 'forfeit_sheets.dart'
    show ForfeitCard, showForfeitAssigner;

/// Friends radar: animated sweep for visible peers, connected friends with
/// live presence, and a manual connect escape hatch for locked-down Wi-Fi.
class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key, required this.onCreateChallenge});

  final VoidCallback onCreateChallenge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final Map<String, VisiblePeer> visible = app.arena.visible;
    final Set<String> connected = app.arena.connected;
    final List<FriendRecord> friends = app.arena.friends;

    // Peers on the network we haven't met yet.
    final List<VisiblePeer> strangers = visible.values
        .where((VisiblePeer v) => app.arena.friendById(v.wire.id) == null)
        .toList();

    if (visible.isEmpty && friends.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 30),
        children: <Widget>[
          const RadarPlaceholder(),
          const SizedBox(height: Sp.sm),
          EmptyState(
            emoji: '📡',
            title: 'Scanning the network',
            message:
                'Friends on the same Wi-Fi (or hotspot) show up here automatically. Start a hotspot together if you\'re out and about.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, Sp.xs, 0, 110),
      children: <Widget>[
        if (strangers.isNotEmpty) ...<Widget>[
          const SectionHeader('Nearby now',
              eyebrow: 'On your network'),
          for (int i = 0; i < strangers.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(
                index: i,
                child: _PeerCard(
                  name: strangers[i].wire.name,
                  emoji: strangers[i].wire.emoji,
                  seed: strangers[i].wire.colorSeed,
                  connected: connected.contains(strangers[i].wire.id),
                  actionLabel:
                      connected.contains(strangers[i].wire.id)
                          ? 'Connected'
                          : 'Connect',
                  onAction: connected.contains(strangers[i].wire.id)
                      ? null
                      : () async {
                          await app.arena.connectManual(strangers[i]);
                          if (context.mounted) {
                            AppToast.show(context,
                                message:
                                    'Connected with ${strangers[i].wire.name}',
                                emoji: '🤝');
                          }
                        },
                  secondaryAction: 'Duel',
                  onSecondary: () => showChallengeCreatorFromPeer(
                      context, app, strangers[i].wire.id),
                ),
              ),
            ),
        ],
        if (app.arena.forfeits.isNotEmpty) ...<Widget>[
          const SectionHeader('Forfeits', eyebrow: 'Punishments'),
          for (int i = 0; i < app.arena.forfeits.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(
                index: i,
                child:
                    ForfeitCard(forfeit: app.arena.forfeits[i]),
              ),
            ),
        ],
        if (friends.isNotEmpty) ...<Widget>[
          const SectionHeader('Your circle', eyebrow: 'Friends'),
          for (int i = 0; i < friends.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(
                index: i,
                child: _FriendCard(
                  friend: friends[i],
                  connected: connected.contains(friends[i].id),
                  visible: visible.containsKey(friends[i].id),
                  onDuel: () => showChallengeCreatorFromPeer(
                      context, app, friends[i].id),
                  onForfeit: () => showForfeitAssigner(
                      context, app, friends[i].id),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard({
    required this.name,
    required this.emoji,
    required this.seed,
    required this.connected,
    required this.actionLabel,
    this.onAction,
    this.secondaryAction,
    this.onSecondary,
  });

  final String name;
  final String emoji;
  final int seed;
  final bool connected;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? secondaryAction;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      child: Row(
        children: <Widget>[
          EmojiAvatar(emoji, seed: seed, size: 44, online: connected),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  connected ? 'Connected — syncing' : 'Visible on network',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                          color: connected ? c.success : c.inkMuted),
                ),
              ],
            ),
          ),
          if (onSecondary != null) ...<Widget>[
            AppButton.soft(secondaryAction!,
                size: AppButtonSize.small, onTap: onSecondary),
            const SizedBox(width: Sp.sm),
          ],
          AppButton.primary(
            actionLabel,
            size: AppButtonSize.small,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.connected,
    required this.visible,
    required this.onDuel,
    required this.onForfeit,
  });

  final FriendRecord friend;
  final bool connected;
  final bool visible;
  final VoidCallback onDuel;
  final VoidCallback onForfeit;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(friend.emoji,
                  seed: friend.colorSeed, size: 44, online: connected),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(friend.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      connected
                          ? 'Connected now'
                          : visible
                              ? 'Nearby'
                              : 'Offline · seen ${_lastSeen()}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                              color: connected
                                  ? c.success
                                  : c.inkMuted),
                    ),
                  ],
                ),
              ),
              AppButton.soft('Duel ⚔️',
                  size: AppButtonSize.small, onTap: onDuel),
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded,
                  size: 15, color: c.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Owe them a punishment? Assign a forfeit.',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.inkFaint),
                ),
              ),
              Pressable(
                onTap: onForfeit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                  child: Text('Assign forfeit',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: c.primaryDeep)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _lastSeen() {
    final Duration d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(friend.lastSeen));
    if (d.inMinutes < 60) return 'recently';
    if (d.inHours < 24) return 'today';
    return '${d.inDays}d ago';
  }
}

/// Idle radar animation shown while nobody's around.
class RadarPlaceholder extends StatefulWidget {
  const RadarPlaceholder({super.key});

  @override
  State<RadarPlaceholder> createState() => _RadarPlaceholderState();
}

class _RadarPlaceholderState extends State<RadarPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _RadarPainter(
          sweep: _ctrl,
          primary: c.primary,
          track: c.surfaceAlt,
          faint: c.outline,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweep,
    required this.primary,
    required this.track,
    required this.faint,
  }) : super(repaint: sweep);

  final Animation<double> sweep;
  final Color primary;
  final Color track;
  final Color faint;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 6;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int i = 1; i <= 3; i++) {
      p.color = faint;
      canvas.drawCircle(center, r * i / 3, p);
    }
    final double angle = sweep.value * 2 * math.pi;
    final Paint sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = primary;
    canvas.drawLine(
      center,
      Offset(center.dx + r * 0.9 * math.cos(angle),
          center.dy + r * 0.9 * math.sin(angle)),
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => false; // repaints via animation
}
