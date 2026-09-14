import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_routes.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/progress.dart';
import '../../data/models/arena.dart';
import '../../data/models/common.dart';
import '../../state/app_store.dart';
import 'forfeit_sheets.dart';

/// All challenges: live invites, active duels, settled history.
class ChallengesTab extends StatelessWidget {
  const ChallengesTab({super.key, required this.onCreateChallenge});

  final VoidCallback onCreateChallenge;

  @override
  Widget build(BuildContext context) {
    final AppStore app = AppScope.of(context);
    final List<Challenge> invites = app.arena.pendingInvites;
    final List<Challenge> active = app.arena.activeChallenges;
    final List<Challenge> past = app.arena.pastChallenges;

    if (invites.isEmpty && active.isEmpty && past.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 40),
        children: <Widget>[
          EmptyState(
            emoji: '⚔️',
            title: 'No duels yet',
            message:
                'Challenge someone from the Radar tab. Pick a habit, set a stake, may the best streak win.',
            actionLabel: 'Start a duel',
            onAction: onCreateChallenge,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, Sp.xs, 0, 110),
      children: <Widget>[
        if (invites.isNotEmpty) ...<Widget>[
          const SectionHeader('Waiting on you', eyebrow: 'Invites'),
          for (int i = 0; i < invites.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(index: i, child: _InviteRow(c: invites[i])),
            ),
        ],
        if (active.isNotEmpty) ...<Widget>[
          const SectionHeader('Live duels', eyebrow: 'Active'),
          for (int i = 0; i < active.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(index: i, child: _ActiveRow(c: active[i])),
            ),
        ],
        if (past.isNotEmpty) ...<Widget>[
          const SectionHeader('History', eyebrow: 'Settled'),
          for (int i = 0; i < past.length; i++)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.md),
              child: Entrance(index: i, child: _PastRow(c: past[i])),
            ),
        ],
      ],
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({required this.c});

  final Challenge c;

  @override
  Widget build(BuildContext context) {
    final AppColors cc = context.colors;
    final AppStore app = AppScope.of(context);
    final (String name, String emoji, int seed) =
        app.arena.identityOf(c.createdBy);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(emoji, seed: seed, size: 38),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'from $name · ${c.durationDays} days · ${c.stake} pts',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cc.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton.primary('Accept', size: AppButtonSize.small,
                    expanded: true,
                    onTap: () => app.arena.respondInvite(c.id, true)),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppButton.ghost('Pass',
                    size: AppButtonSize.small,
                    expanded: true,
                    onTap: () => app.arena.respondInvite(c.id, false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.c});

  final Challenge c;

  @override
  Widget build(BuildContext context) {
    final AppColors cc = context.colors;
    final AppStore app = AppScope.of(context);
    final String opp = c.opponentOf(app.arena.meId) ?? '';
    final (String name, String emoji, int seed) = app.arena.identityOf(opp);
    final Map<String, int> totals = app.arena.progressOf(c);
    final int mine = totals[app.arena.meId] ?? 0;
    final int theirs = totals[opp] ?? 0;
    final int daysLeft = c.endDate.difference(DateTime.now()).inDays + 1;

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed('/challenge',
          arguments: ChallengeRouteArgs(c.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(c.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Text(c.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StatChip(
                icon: Icons.schedule,
                label: daysLeft > 0 ? '${daysLeft}d left' : 'Ends today',
                color: daysLeft <= 1 ? cc.warning : cc.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Row(
            children: <Widget>[
              EmojiAvatar(app.db.profile?.emoji ?? '🙂',
                  seed: app.db.profile?.colorSeed ?? 0, size: 30),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('$mine',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures()
                                      ])),
                        Text(
                          mine > theirs
                              ? 'You lead'
                              : mine < theirs
                                  ? '$name leads'
                                  : 'Level',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: mine >= theirs
                                      ? cc.success
                                      : cc.inkMuted),
                        ),
                        Text('$theirs',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontFeatures: const <FontFeature>[
                                        FontFeature.tabularFigures()
                                      ])),
                      ],
                    ),
                    const SizedBox(height: Sp.sm),
                    DuelBar(
                      a: mine.toDouble(),
                      b: theirs.toDouble(),
                      colorA: HabitPalette.color(HabitPalette.clampSeed(
                          app.db.profile?.colorSeed ?? 0)),
                      colorB: HabitPalette.color(HabitPalette.clampSeed(seed)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.sm),
              EmojiAvatar(emoji, seed: seed, size: 30),
            ],
          ),
        ],
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.c});

  final Challenge c;

  @override
  Widget build(BuildContext context) {
    final AppColors cc = context.colors;
    final AppStore app = AppScope.of(context);
    final String me = app.arena.meId;
    final bool won = c.winnerId == me;
    final bool draw = c.winnerId == null;

    final (String icon, Color tone, String verdict) = c.status ==
            Challenge.statusDeclined
        ? ('🕊️', cc.inkFaint, 'Passed')
        : draw
            ? ('🤝', cc.inkMuted, 'Draw')
            : won
                ? ('🏆', cc.gold, 'You won +${c.stake}')
                : ('🎯', cc.danger, 'Lost −${c.stake}');

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed('/challenge',
          arguments: ChallengeRouteArgs(c.id)),
      padding:
          const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${c.startDate.medium} · $verdict',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cc.inkMuted),
                ),
              ],
            ),
          ),
          if (c.status == Challenge.statusSettled &&
              c.winnerId == me &&
              !app.arena.forfeitAssignedFor(c.id))
            Pressable(
              onTap: () => _assignForfeit(context, app),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.sm),
                child: Text('Assign forfeit',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: cc.primaryDeep)),
              ),
            ),
          if (c.status == Challenge.statusSettled &&
              c.winnerId == me &&
              app.arena.forfeitAssignedFor(c.id))
            Text('Forfeit sent ✓',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: cc.success)),
        ],
      ),
    );
  }

  void _assignForfeit(BuildContext context, AppStore app) {
    final String opp = c.opponentOf(app.arena.meId) ?? '';
    showForfeitAssigner(context, app, opp,
        challengeId: c.id);
  }
}
