import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/p2p/discovery.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/common.dart';
import '../../data/models/profile.dart';
import '../../state/app_store.dart';
import '../habits/habit_editor.dart' show kHabitIcons;

/// Two-step wizard: pick the habit stake → pick opponent & length.
Future<void> showChallengeCreator(BuildContext context, AppStore app) async {
  final String? peerId = await showAppSheet<String>(
    context: context,
    builder: (BuildContext ctx) => const _OpponentPicker(),
  );
  if (peerId == null || !context.mounted) return;
  await showChallengeCreatorFromPeer(context, app, peerId);
}

Future<void> showChallengeCreatorFromPeer(
    BuildContext context, AppStore app, String peerId) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext ctx) => _ChallengeWizard(app: app, peerId: peerId),
  );
}

/// Step 1: choose who to duel.
class _OpponentPicker extends StatelessWidget {
  const _OpponentPicker();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final Map<String, VisiblePeer> visible = app.arena.visible;
    final List<FriendRecord> friends = app.arena.friends;
    final List<VisiblePeer> strangers = visible.values
        .where((VisiblePeer v) => app.arena.friendById(v.wire.id) == null)
        .toList();

    if (visible.isEmpty && friends.isEmpty) {
      return SheetScaffold(
        title: 'Pick an opponent',
        subtitle: 'Nobody on the network yet',
        child: Column(
          children: <Widget>[
            const Text('📡', style: TextStyle(fontSize: 40)),
            const SizedBox(height: Sp.md),
            Text(
              'Friends appear here when they open HabitNow on the same '
              'Wi-Fi. For a quick test, run the app on two phones.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return SheetScaffold(
      title: 'Pick an opponent',
      subtitle: 'Challenge someone on your network',
      child: Column(
        children: <Widget>[
          for (final VisiblePeer v in strangers)
            _OpponentRow(
              name: v.wire.name,
              emoji: v.wire.emoji,
              seed: v.wire.colorSeed,
              status: 'Nearby',
              onTap: () => Navigator.of(context).pop(v.wire.id),
            ),
          for (final FriendRecord f in friends)
            if (!visible.containsKey(f.id))
              _OpponentRow(
                name: f.name,
                emoji: f.emoji,
                seed: f.colorSeed,
                status: 'Offline — invite waits for them',
                onTap: () => Navigator.of(context).pop(f.id),
              )
            else
              _OpponentRow(
                name: f.name,
                emoji: f.emoji,
                seed: f.colorSeed,
                status: 'Online',
                onTap: () => Navigator.of(context).pop(f.id),
              ),
        ],
      ),
    );
  }
}

class _OpponentRow extends StatelessWidget {
  const _OpponentRow({
    required this.name,
    required this.emoji,
    required this.seed,
    required this.status,
    required this.onTap,
  });

  final String name;
  final String emoji;
  final int seed;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: <Widget>[
            EmojiAvatar(emoji, seed: seed, size: 42),
            const SizedBox(width: Sp.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  Text(status,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Step 2: stake, length, habit template.
class _ChallengeWizard extends StatefulWidget {
  const _ChallengeWizard({required this.app, required this.peerId});

  final AppStore app;
  final String peerId;

  @override
  State<_ChallengeWizard> createState() => _ChallengeWizardState();
}

class _ChallengeWizardState extends State<_ChallengeWizard> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _habitName = TextEditingController();
  int _iconIndex = 0;
  int _seed = 1;
  int _stake = 25;
  int _days = 7;
  Set<int> _weekdays = const <int>{
    DateTime.monday, DateTime.tuesday, DateTime.wednesday,
    DateTime.thursday, DateTime.friday, DateTime.saturday,
    DateTime.sunday,
  };

  @override
  void dispose() {
    _name.dispose();
    _habitName.dispose();
    super.dispose();
  }

  bool get _canSend => _habitName.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    Haptics.medium();
    final String foe = widget.app.arena.identityOf(widget.peerId).$1;
    widget.app.arena.createChallenge(
      friendId: widget.peerId,
      name: _name.text.trim().isEmpty
          ? '${_habitName.text.trim()} duel'
          : _name.text.trim(),
      emoji: const <String>['⚔️', '🔥', '🏃', '🧠', '💪'][_seed % 5],
      habitName: _habitName.text.trim(),
      iconCode: kHabitIcons[_iconIndex].codePoint,
      colorSeed: _seed,
      weekdays: _weekdays,
      stake: _stake,
      durationDays: _days,
    );
    AppToast.show(context,
        message: 'Challenge sent to $foe — waiting for them to accept',
        emoji: '📨');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (String foeName, String foeEmoji, int foeSeed) =
        widget.app.arena.identityOf(widget.peerId);
    return SheetScaffold(
      title: 'Duel $foeName',
      subtitle: 'Same habit, same days — highest count wins the stake',
      bottomActions: <Widget>[
        AppButton.ghost('Cancel', onTap: () => Navigator.of(context).pop()),
        AppButton.primary('Send challenge ⚔️',
            expanded: true, onTap: _canSend ? _send : null),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            controller: _habitName,
            hint: 'The habit you\'ll duel on',
            maxLength: 40,
            autofocus: true,
            prefix: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: HabitPalette.soft(_seed, context.isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(kHabitIcons[_iconIndex],
                  size: 16, color: HabitPalette.color(_seed)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Sp.xl),
          Text('THEIR HABIT · YOUR HABIT',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.sm),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              for (int i = 0; i < kHabitIcons.length; i++)
                Pressable(
                  onTap: () {
                    Haptics.select();
                    setState(() => _iconIndex = i);
                  },
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: i == _iconIndex
                          ? HabitPalette.soft(_seed, context.isDark)
                          : c.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == _iconIndex
                            ? HabitPalette.color(_seed)
                            : Colors.transparent,
                        width: 1.6,
                      ),
                    ),
                    child: Icon(
                      kHabitIcons[i],
                      size: 19,
                      color: i == _iconIndex
                          ? HabitPalette.color(_seed)
                          : c.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Text('DAILY DAYS',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (int d = DateTime.monday; d <= DateTime.sunday; d++) ...<Widget>[
                if (d > DateTime.monday) const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Haptics.select();
                      setState(() {
                        if (_weekdays.contains(d)) {
                          _weekdays = Set<int>.of(_weekdays)..remove(d);
                        } else {
                          _weekdays = Set<int>.of(_weekdays)..add(d);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _weekdays.contains(d)
                            ? c.primarySoft
                            : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.s),
                        border: Border.all(
                            color: _weekdays.contains(d)
                                ? c.primary
                                : Colors.transparent),
                      ),
                      child: Text(
                        const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'][d - 1],
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: _weekdays.contains(d)
                                    ? c.primaryDeep
                                    : c.inkMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.xl),
          Text('STAKE · winner takes it',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              Text('$_stake pts',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: c.gold, fontWeight: FontWeight.w800)),
              Expanded(
                child: Slider(
                  value: _stake.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 9,
                  label: '$_stake',
                  activeColor: c.gold,
                  onChanged: (double v) =>
                      setState(() => _stake = (v ~/ 10) * 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Text(
            'Winner +$_stake · loser −$_stake. Draws refund everyone.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Sp.xl),
          Text('LENGTH',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (final int d in <int>[3, 7, 14, 30]) ...<Widget>[
                if (d != 3) const SizedBox(width: Sp.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Haptics.select();
                      setState(() => _days = d);
                    },
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _days == d ? c.primary : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                        border: Border.all(
                            color: _days == d
                                ? c.primary
                                : Colors.transparent),
                      ),
                      child: Text(
                        d == 30 ? '30 days' : '$d day${d == 1 ? '' : 's'}',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                                color: _days == d
                                    ? c.onPrimary
                                    : c.inkMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.md),
          Text(
            'Starts ${_startLabel()} — check-ins sync live between you both.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }

  String _startLabel() {
    final DateTime start = DateTime.now().dayOnly;
    if (start.weekday == DateTime.saturday ||
        start.weekday == DateTime.sunday) {
      return 'Monday';
    }
    return 'tomorrow';
  }
}
