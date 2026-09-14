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
import '../../core/widgets/sheets.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/arena.dart';
import '../../data/models/common.dart';
import '../../state/app_store.dart';
import '../../state/arena_store.dart' show ArenaEvent;
import '../habits/habit_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onGotoHabits});

  final VoidCallback onGotoHabits;

  String _greeting() {
    final int h = DateTime.now().hour;
    if (h < 5) return 'Night grind';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final int perfect = app.habits.perfectDayStreak();
    final int scheduled = app.habits.scheduledOn(DateTime.now()).length;
    final int done = app.habits.completedTodayCount();
    final double progress = scheduled == 0 ? 0 : done / scheduled;
    final ArenaEvent? event =
        app.arena.events.isEmpty ? null : app.arena.events.first;
    final List<Challenge> invites = app.arena.pendingInvites;
    final List<Forfeit> myDue = app.arena.forfeitsAssignedToMe
        .where((Forfeit f) => f.status == Forfeit.statusPending)
        .toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        onRefresh: () async {
          app.arena.refreshPresence();
          app.arena.maybeSettleChallenges();
        },
        edgeOffset: 8,
        color: c.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 110),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Sp.screenH, Sp.lg, Sp.screenH, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${_greeting()}, ${app.db.profile?.name ?? 'friend'}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${DateTime.now().weekdayFull}, '
                          '${DateTime.now().medium}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (perfect > 0)
                    StatChip(
                      icon: Icons.local_fire_department,
                      label: '$perfect day${perfect == 1 ? '' : 's'}',
                      color: c.flame,
                      soft: c.flameSoft,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),

            // -- Today ring -------------------------------------------------
            Entrance(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.screenH),
                child: AppCard(
                  padding: const EdgeInsets.all(Sp.xl),
                  child: Row(
                    children: <Widget>[
                      ProgressRing(
                        progress: progress,
                        color: c.primary,
                        trackColor: c.surfaceAlt,
                        size: 84,
                        stroke: 8,
                        child: Text(
                          '$done/$scheduled',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: Sp.xl),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              scheduled == 0
                                  ? 'Nothing scheduled'
                                  : (progress >= 1
                                      ? 'Perfect day 🎉'
                                      : 'You\'re on it'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scheduled == 0
                                  ? 'Add a habit to get the streak going'
                                  : progress >= 1
                                      ? 'Every habit done today. Respect.'
                                      : '${scheduled - done} left to make it a perfect day',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: c.inkMuted),
                            ),
                            if (app.tasks.dueTodayOrOverdue.isNotEmpty) ...<Widget>[
                              const SizedBox(height: Sp.md),
                              Row(
                                children: <Widget>[
                                  Icon(Icons.checklist,
                                      size: 14, color: c.inkMuted),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '${app.tasks.dueTodayOrOverdue.length} task${app.tasks.dueTodayOrOverdue.length == 1 ? '' : 's'} due today',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                              color: c.inkMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),

            // -- Forfeit alert ----------------------------------------------
            if (myDue.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.screenH),
                child: Entrance(
                  index: 1,
                  child: InfoBanner(
                    icon: Icons.warning_amber_rounded,
                    tone: BannerTone.warn,
                    text: 'Forfeit due ${myDue.first.dueDay == DateTime.now().dayOnly.isoDate ? 'today' : 'by ${fromIsoDate(myDue.first.dueDay).medium}'}: "${myDue.first.text}"',
                    action: 'Serve',
                    onAction: () => _serveForfeit(context, app, myDue.first),
                  ),
                ),
              ),

            // -- Latest event ------------------------------------------------
            if (event != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Sp.screenH, Sp.md, Sp.screenH, 0),
                child: Entrance(
                  index: 2,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Sp.lg, vertical: Sp.md),
                    child: Row(
                      children: <Widget>[
                        Text(event.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // -- Pending invites ---------------------------------------------
            if (invites.isNotEmpty) ...<Widget>[
              const SectionHeader('Challenged you', eyebrow: 'Arena'),
              for (int i = 0; i < invites.length; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Sp.screenH, 0, Sp.screenH, Sp.md),
                  child: Entrance(
                    index: i,
                    child: _InviteCard(challenge: invites[i]),
                  ),
                ),
            ],

            // -- Today's habits ----------------------------------------------
            SectionHeader(
              'Today',
              eyebrow: 'Habits',
              action: Pressable(
                onTap: onGotoHabits,
                child: Text('Manage',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: c.primaryDeep)),
              ),
            ),
            if (scheduled == 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: Sp.screenH),
                child: AppCard(
                  onTap: onGotoHabits,
                  child: Row(
                    children: <Widget>[
                      const Text('🌱', style: TextStyle(fontSize: 26)),
                      const SizedBox(width: Sp.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Plant your first habit',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 2),
                            Text('Tap to open the Habit garden',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.inkFaint),
                    ],
                  ),
                ),
              )
            else
              ...<Widget>[
                for (int i = 0; i < app.habits.scheduledOn(DateTime.now()).length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Sp.screenH, 0, Sp.screenH, Sp.md),
                    child: Entrance(
                      index: i + 1,
                      child: HabitRow(
                        habit: app.habits.scheduledOn(DateTime.now())[i],
                        app: app,
                      ),
                    ),
                  ),
              ],

            // -- Active challenges strip -------------------------------------
            if (app.arena.activeChallenges.isNotEmpty) ...<Widget>[
              const SectionHeader('In the Arena', eyebrow: 'Challenges'),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: Sp.screenH),
                  itemCount: app.arena.activeChallenges.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: Sp.md),
                  itemBuilder: (BuildContext context, int i) {
                    final Challenge ch = app.arena.activeChallenges[i];
                    return _MiniChallengeCard(challenge: ch);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _serveForfeit(
      BuildContext context, AppStore app, Forfeit f) async {
    await showAppSheet<void>(
      context: context,
      builder: (BuildContext ctx) => _ServeForfeitSheet(forfeit: f, app: app),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final (String name, String emoji, int seed) =
        app.arena.identityOf(challenge.createdBy);
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
                    Text(
                        '$name wants a duel: '
                        '"${challenge.name}"',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${challenge.habitName} · ${challenge.durationDays} days · ${challenge.stake} pts on the line',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.inkMuted),
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
                child: AppButton.primary(
                  'Accept ⚔️',
                  size: AppButtonSize.small,
                  expanded: true,
                  onTap: () {
                    app.arena.respondInvite(challenge.id, true);
                    AppToast.show(context,
                        message: 'Game on!', emoji: '⚔️');
                  },
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppButton.ghost(
                  'Pass',
                  size: AppButtonSize.small,
                  expanded: true,
                  onTap: () =>
                      app.arena.respondInvite(challenge.id, false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChallengeCard extends StatelessWidget {
  const _MiniChallengeCard({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final String opp = challenge.opponentOf(app.arena.meId) ?? '';
    final (String name, String emoji, int seed) =
        app.arena.identityOf(opp);
    final Map<String, int> totals = app.arena.progressOf(challenge);
    final int mine = totals[app.arena.meId] ?? 0;
    final int theirs = totals[opp] ?? 0;
    final int daysLeft =
        challenge.endDate.difference(DateTime.now()).inDays + 1;

    return Pressable(
      onTap: () => Navigator.of(context).pushNamed(
        '/challenge',
        arguments: ChallengeRouteArgs(challenge.id),
      ),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.hairline),
          boxShadow: Elev.shadow(1, dark: context.isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(challenge.emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    challenge.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatChip(
                  icon: Icons.schedule,
                  label: daysLeft > 0 ? '${daysLeft}d' : 'Last day',
                ),
              ],
            ),
            const SizedBox(height: Sp.md),
            Row(
              children: <Widget>[
                EmojiAvatar(app.db.profile?.emoji ?? '🙂',
                    seed: app.db.profile?.colorSeed ?? 0, size: 22),
                Expanded(
                  child: Center(
                    child: DuelBar(
                      a: mine.toDouble(),
                      b: theirs.toDouble(),
                      colorA: HabitPalette.color(
                          HabitPalette.clampSeed(
                              app.db.profile?.colorSeed ?? 0)),
                      colorB: HabitPalette.color(HabitPalette.clampSeed(seed)),
                      height: 7,
                    ),
                  ),
                ),
                EmojiAvatar(emoji, seed: seed, size: 22),
              ],
            ),
            const SizedBox(height: Sp.sm),
            Text('$mine — $theirs',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _ServeForfeitSheet extends StatelessWidget {
  const _ServeForfeitSheet({required this.forfeit, required this.app});

  final Forfeit forfeit;
  final AppStore app;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (String name, String emoji, int seed) =
        app.arena.identityOf(forfeit.fromId);
    return SheetScaffold(
      title: 'Forfeit time',
      subtitle: 'Assigned by $name',
      bottomActions: <Widget>[
        AppButton.primary('I did it 💪', expanded: true, onTap: () {
          app.arena.markForfeitDone(forfeit);
          AppToast.show(context,
              message: 'Served! Waiting for confirmation', emoji: '✅');
          Navigator.of(context).pop();
        }),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(emoji, seed: seed),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '"${forfeit.text}"',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due ${fromIsoDate(forfeit.dueDay).medium} · worth +15 pts (miss it: −20)',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Container(
            padding: const EdgeInsets.all(Sp.lg),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.m),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 18, color: c.inkMuted),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Text(
                    'They\'ll confirm it over the network. You keep the '
                    '+15 either way — the confirm just closes the loop.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
