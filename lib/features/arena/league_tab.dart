import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/progress.dart';
import '../../state/app_store.dart';

/// Weekly league: podium for the top three + ranked list of your circle.
class LeagueTab extends StatelessWidget {
  const LeagueTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final List<({String id, String name, String emoji, int seed, int points, int rank})>
        board = app.arena.weeklyLeaderboard();
    final int myTotal = app.arena.totalPoints;

    if (board.length <= 1 &&
        board.isNotEmpty &&
        board.first.points == 0) {
      return ListView(
        padding: const EdgeInsets.only(top: 40),
        children: <Widget>[
          const EmptyState(
            emoji: '🏅',
            title: 'The league is quiet',
            message:
                'Points from check-ins, streaks and duels land here every week. Connect with friends and start scoring.',
          ),
        ],
      );
    }

    final int maxPoints = board
        .map((e) => e.points)
        .fold(1, (int a, int b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, Sp.xs, 0, 110),
      children: <Widget>[
        // Podium — only with 2+ players.
        if (board.length >= 2)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Sp.screenH, Sp.md, Sp.screenH, 0),
            child: Entrance(
              child: _Podium(top3: board.take(3).toList()),
            ),
          ),
        const SectionHeader('This week', eyebrow: 'Points'),
        for (int i = 0; i < board.length; i++)
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
            child: Entrance(
              index: i + 1,
              child: _LeagueRow(
                rank: board[i].rank,
                name: board[i].name,
                emoji: board[i].emoji,
                seed: board[i].seed,
                points: board[i].points,
                maxPoints: maxPoints,
                isMe: board[i].id == app.arena.meId,
              ),
            ),
          ),
        const SizedBox(height: Sp.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
          child: AppCard(
            child: Row(
              children: <Widget>[
                Icon(Icons.military_tech, size: 22, color: c.gold),
                const SizedBox(width: Sp.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('All-time score',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        'Every point you\'ve ever earned, streaks included.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                Text('+$myTotal',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                            color: c.gold,
                            fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures()
                              ])),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3});

  final List<({String id, String name, String emoji, int seed, int points, int rank})>
      top3;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    // Visual order: 2nd · 1st · 3rd.
    final List<({String id, String name, String emoji, int seed, int points, int rank})>
        ordered = <({String id, String name, String emoji, int seed, int points, int rank})>[
      if (top3.length > 1) top3[1],
      top3[0],
      if (top3.length > 2) top3[2],
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < ordered.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: Sp.md),
          Expanded(
            child: _PodiumColumn(
              e: ordered[i],
              barHeight: i == 1 ? 66 : 44,
              medal: ordered[i].rank == 1
                  ? '🥇'
                  : ordered[i].rank == 2
                      ? '🥈'
                      : '🥉',
              isMe: ordered[i].id == app.arena.meId,
              color: c,
            ),
          ),
        ],
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.e,
    required this.barHeight,
    required this.medal,
    required this.isMe,
    required AppColors color,
  }) : _c = color;

  final ({String id, String name, String emoji, int seed, int points, int rank}) e;
  final double barHeight;
  final String medal;
  final bool isMe;
  final AppColors _c;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            EmojiAvatar(e.emoji, seed: e.seed, size: 52, ring: isMe),
            Positioned(
              right: -4,
              top: -6,
              child: Text(medal,
                  style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        const SizedBox(height: Sp.sm),
        Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Text(
          '${e.points}',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: _c.gold),
        ),
        const SizedBox(height: Sp.sm),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Motion.emphasized,
          builder: (BuildContext context, double t, _) => Container(
            height: barHeight * t,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  _c.gold.withValues(alpha: 0.55),
                  _c.gold.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.s)),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.rank,
    required this.name,
    required this.emoji,
    required this.seed,
    required this.points,
    required this.maxPoints,
    required this.isMe,
  });

  final int rank;
  final String name;
  final String emoji;
  final int seed;
  final int points;
  final int maxPoints;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AppCard(
      color: isMe ? c.primarySoft : null,
      padding:
          const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 26,
                child: Text(
                  '#$rank',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: isMe ? c.primaryDeep : c.inkFaint),
                ),
              ),
              EmojiAvatar(emoji, seed: seed, size: 34),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  isMe ? '$name (you)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${points >= 0 ? '+' : ''}$points',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                        color: points >= 0 ? c.success : c.danger,
                        fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures()
                          ]),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          AnimatedBar(
            value: maxPoints == 0 ? 0 : points.abs() / maxPoints,
            color: points >= 0
                ? (isMe ? c.primary : c.success)
                : c.danger,
            height: 5,
          ),
        ],
      ),
    );
  }
}
