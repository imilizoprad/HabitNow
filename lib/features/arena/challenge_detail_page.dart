import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/arena.dart';
import '../../data/models/common.dart';
import '../../state/app_store.dart';
import '../../state/arena_store.dart' show ChatLine;
import 'forfeit_sheets.dart';

/// Head-to-head view: live duel bar, day-by-day timeline, quick-line chat,
/// settlement summary + forfeit CTA.
class ChallengeDetailPage extends StatelessWidget {
  const ChallengeDetailPage({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    Challenge? challenge;
    for (final Challenge ch in app.arena.challenges) {
      if (ch.id == challengeId) challenge = ch;
    }
    if (challenge == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          emoji: '🫥',
          title: 'Challenge not found',
          message: 'It may have been cancelled.',
        ),
      );
    }
    final Challenge ch = challenge;
    final String me = app.arena.meId;
    final String opp = ch.opponentOf(me) ?? '';
    final (String oppName, String oppEmoji, int oppSeed) =
        app.arena.identityOf(opp);
    final Map<String, int> totals = app.arena.progressOf(ch);
    final Map<String, Map<String, bool>> days = app.arena.dayMapOf(ch);
    final int mine = totals[me] ?? 0;
    final int theirs = totals[opp] ?? 0;
    final int mySeed = app.db.profile?.colorSeed ?? 0;
    final bool settled = ch.status == Challenge.statusSettled;
    final int daysLeft = ch.endDate.difference(DateTime.now()).inDays + 1;
    final List<ChatLine> chat = app.arena.chats[ch.id] ?? const <ChatLine>[];

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title: Text(ch.name, style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, 110),
        children: <Widget>[
          // -- duel header ------------------------------------------------
          AppCard(
            padding: const EdgeInsets.all(Sp.xl),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _DuelistHeader(
                        emoji: app.db.profile?.emoji ?? '🙂',
                        seed: mySeed,
                        name: 'You',
                        score: mine,
                        color: HabitPalette.color(
                            HabitPalette.clampSeed(mySeed)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                      child: Column(
                        children: <Widget>[
                          Text('VS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: c.inkFaint)),
                          const SizedBox(height: 4),
                          Text(
                            '${ch.stake}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: c.gold),
                          ),
                          Text('pts stake',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: c.inkFaint)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _DuelistHeader(
                        emoji: oppEmoji,
                        seed: oppSeed,
                        name: oppName,
                        score: theirs,
                        color: HabitPalette.color(
                            HabitPalette.clampSeed(oppSeed)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xl),
                DuelBar(
                  a: mine.toDouble(),
                  b: theirs.toDouble(),
                  colorA: HabitPalette.color(HabitPalette.clampSeed(mySeed)),
                  colorB:
                      HabitPalette.color(HabitPalette.clampSeed(oppSeed)),
                  height: 14,
                ),
                const SizedBox(height: Sp.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    StatChip(
                      icon: Icons.handyman,
                      label: ch.habitName,
                      color: HabitPalette.color(
                          HabitPalette.clampSeed(ch.colorSeed)),
                    ),
                    const SizedBox(width: Sp.sm),
                    StatChip(
                      icon: Icons.schedule,
                      label: settled
                          ? 'Finished'
                          : daysLeft > 0
                              ? '$daysLeft days left'
                              : 'Final day',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),

          // -- settlement / invite banners ----------------------------------
          if (ch.status == Challenge.statusPending) ...<Widget>[
            InfoBanner(
              icon: Icons.hourglass_top,
              text: ch.createdBy == me
                  ? 'Waiting for $oppName to accept…'
                  : 'Open the Arena tab to accept this duel.',
              tone: BannerTone.info,
            ),
            const SizedBox(height: Sp.md),
          ],
          if (settled) ...<Widget>[
            _SettlementCard(ch: ch),
            const SizedBox(height: Sp.md),
          ],

          // -- day timeline -------------------------------------------------
          if (!settled) ...<Widget>[
            Text('THE RUN',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
            const SizedBox(height: Sp.md),
            AppCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.lg),
              child: Column(
                children: <Widget>[
                  for (final MapEntry<String, Map<String, bool>> day
                      in days.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.md),
                      child: _DayRow(
                        dayKey: day.key,
                        mineDone: day.value[me] ?? false,
                        theirsDone: day.value[opp] ?? false,
                        myColor: HabitPalette.color(
                            HabitPalette.clampSeed(mySeed)),
                        theirColor: HabitPalette.color(
                            HabitPalette.clampSeed(oppSeed)),
                        isToday: day.key == DateTime.now().dayOnly.isoDate,
                      ),
                    ),
                  if (days.isEmpty)
                    Text(
                      'Starts ${fromIsoDate(ch.startDay).friendly} — rest up.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: c.inkMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),

            // -- chat quick-lines --------------------------------------------
            Text('HYPE',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
            const SizedBox(height: Sp.md),
            if (chat.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: Sp.sm,
                  runSpacing: Sp.sm,
                  children: <Widget>[
                    for (final ChatLine line in chat.reversed.take(4))
                      StatChip(
                        icon: Icons.chat_bubble_outline,
                        label:
                            '${line.fromId == me ? 'You' : oppName}: ${line.text}',
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Sp.sm),
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.sm,
              children: <Widget>[
                for (final String line in const <String>[
                  '👀 I\'m coming for you',
                  '🔥 streak\'s safe',
                  '😅 barely made it today',
                  '🏆 prepare to lose',
                ])
                  AppButton.soft(line,
                      size: AppButtonSize.small,
                      onTap: () => app.arena.sendChat(
                          ch.id, opp, line)),
              ],
            ),
            const SizedBox(height: Sp.lg),
          ],

          // -- forfeit CTA when settled & winner -----------------------------
          if (settled &&
              ch.winnerId == me &&
              !app.arena.forfeitAssignedFor(ch.id)) ...<Widget>[
            AppButton.primary('Assign a forfeit to $oppName 😈',
                expanded: true,
                onTap: () => showForfeitAssigner(context, app, opp,
                    challengeId: ch.id)),
            const SizedBox(height: Sp.lg),
          ],
          if (settled &&
              ch.winnerId == opp &&
              !app.arena.forfeitAssignedFor(ch.id)) ...<Widget>[
            InfoBanner(
              icon: Icons.warning_amber_rounded,
              tone: BannerTone.warn,
              text:
                  'Brace yourself — $oppName can assign you a forfeit for losing.',
            ),
            const SizedBox(height: Sp.lg),
          ],
        ],
      ),
    );
  }
}

class _DuelistHeader extends StatelessWidget {
  const _DuelistHeader({
    required this.emoji,
    required this.seed,
    required this.name,
    required this.score,
    required this.color,
  });

  final String emoji;
  final int seed;
  final String name;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        EmojiAvatar(emoji, seed: seed, size: 54),
        const SizedBox(height: Sp.sm),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge),
        Text(
          '$score',
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(color: color),
        ),
        Text('check-ins',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.colors.inkFaint)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.dayKey,
    required this.mineDone,
    required this.theirsDone,
    required this.myColor,
    required this.theirColor,
    required this.isToday,
  });

  final String dayKey;
  final bool mineDone;
  final bool theirsDone;
  final Color myColor;
  final Color theirColor;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final DateTime day = fromIsoDate(dayKey);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(day.weekdayShort,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(
                          color: isToday ? c.primaryDeep : c.inkMuted,
                          fontWeight: isToday
                              ? FontWeight.w800
                              : FontWeight.w600)),
              Text(day.medium,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.inkFaint)),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Center(
                  child: Container(
                    height: 1,
                    color: c.hairline,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _Dot(done: mineDone, color: myColor, isToday: isToday),
                  _Dot(done: theirsDone, color: theirColor, isToday: isToday),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.done,
    required this.color,
    required this.isToday,
  });

  final bool done;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: done ? 1 : 0),
      duration: Motion.base,
      curve: Motion.springy,
      builder: (BuildContext context, double t, _) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: Color.lerp(c.surfaceAlt, color, t),
          shape: BoxShape.circle,
          border: isToday && !done
              ? Border.all(color: c.inkFaint, width: 1.4)
              : null,
        ),
        child: t > 0.9
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({required this.ch});

  final Challenge ch;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final bool draw = ch.winnerId == null;
    final bool won = ch.winnerId == app.arena.meId;
    final (Color tone, Color soft, String emoji, String headline) = draw
        ? (c.inkMuted, c.surfaceAlt, '🤝', 'Dead heat — stakes refunded')
        : won
            ? (c.success, c.successSoft, '🏆',
                'You won +${ch.stake} points')
            : (c.danger, c.dangerSoft, '🎯',
                '\${app.arena.identityOf(ch.winnerId!).$1} took it (−\${ch.stake} pts)');

    return Container(
      padding: const EdgeInsets.all(Sp.xl),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(Radii.l),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(headline,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: tone)),
                const SizedBox(height: 2),
                Text(
                  'Margin: ${ch.margin} check-in${ch.margin == 1 ? '' : 's'} · settled ${DateTime.fromMillisecondsSinceEpoch(ch.updatedAt).friendly}',
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
    );
  }
}
