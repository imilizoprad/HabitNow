import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/haptics.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/arena.dart';
import '../../data/models/profile.dart';
import '../../state/app_store.dart';

/// Preset dares — playful but humane, editable before sending.
const List<String> kForfeitPresets = <String>[
  'No sugar for 3 days',
  'Cold shower tomorrow morning',
  '10k steps every day this week',
  'No social media before noon (3 days)',
  'Cook a healthy dinner from scratch',
  '30 burpees, filmed as proof 😅',
];

/// Assign a forfeit to a friend.
Future<void> showForfeitAssigner(
  BuildContext context,
  AppStore app,
  String toId, {
  String? challengeId,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (BuildContext ctx) => ForfeitAssignerSheet(
      app: app,
      toId: toId,
      challengeId: challengeId,
    ),
  );
}

class ForfeitAssignerSheet extends StatefulWidget {
  const ForfeitAssignerSheet({
    super.key,
    required this.app,
    required this.toId,
    this.challengeId,
  });

  final AppStore app;
  final String toId;
  final String? challengeId;

  @override
  State<ForfeitAssignerSheet> createState() => _ForfeitAssignerSheetState();
}

class _ForfeitAssignerSheetState extends State<ForfeitAssignerSheet> {
  final TextEditingController _text = TextEditingController();
  int _days = 3;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _text.text.trim();
    if (text.isEmpty) return;
    final (String name, _, _) = widget.app.arena.identityOf(widget.toId);
    widget.app.arena.assignForfeit(
      toId: widget.toId,
      text: text,
      days: _days,
      challengeId: widget.challengeId,
    );
    AppToast.show(context,
        message: 'Forfeit sent to $name — no mercy 😈', emoji: '😈');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final (String name, String emoji, int seed) =
        widget.app.arena.identityOf(widget.toId);
    return SheetScaffold(
      title: 'Assign a forfeit',
      subtitle: 'For $name — they get +15 for serving it, −20 for dodging',
      bottomActions: <Widget>[
        AppButton.ghost('Cancel', onTap: () => Navigator.of(context).pop()),
        AppButton.primary('Send it 😈',
            expanded: true,
            onTap: _text.text.trim().isEmpty ? null : _send),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(emoji, seed: seed, size: 38),
              const SizedBox(width: Sp.md),
              Expanded(
                child: AppTextField(
                  controller: _text,
                  hint: 'The dare…',
                  maxLength: 80,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              for (final String p in kForfeitPresets)
                Pressable(
                  onTap: () {
                    Haptics.select();
                    _text.text = p;
                    _text.selection = TextSelection.collapsed(
                        offset: p.length);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Sp.md, vertical: 7),
                    decoration: BoxDecoration(
                      color: _text.text == p ? c.primarySoft : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                          color: _text.text == p
                              ? c.primary
                              : Colors.transparent),
                    ),
                    child: Text(
                      p,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                              color: _text.text == p
                                  ? c.primaryDeep
                                  : c.inkMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Text('DEADLINE',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.sm),
          Row(
            children: <Widget>[
              for (final int d in const <int>[1, 2, 3, 7]) ...<Widget>[
                if (d != 1) const SizedBox(width: Sp.sm),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Haptics.select();
                      setState(() => _days = d);
                    },
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _days == d ? c.dangerSoft : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                        border: Border.all(
                            color: _days == d ? c.danger : Colors.transparent),
                      ),
                      child: Text(
                        d == 1 ? '24 hours' : '$d days',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                                color:
                                    _days == d ? c.danger : c.inkMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.sm),
          Text(
            'Miss the deadline and it\'s an automatic −20, on both your apps.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Incoming forfeits (serve/verify) — embedded at the bottom of the Arena
/// Radar tab and rendered here as cards.
class ForfeitCard extends StatelessWidget {
  const ForfeitCard({super.key, required this.forfeit});

  final Forfeit forfeit;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);
    final bool incoming = forfeit.toId == app.arena.meId;
    final (String name, String emoji, int seed) = incoming
        ? app.arena.identityOf(forfeit.fromId)
        : app.arena.identityOf(forfeit.toId);
    final bool overdue = forfeit.status == Forfeit.statusPending &&
        forfeit.dueDay.compareTo(DateTime.now().dayOnly.isoDate) < 0;

    final (Color tone, Color soft, String statusLabel) =
        switch (forfeit.status) {
          Forfeit.statusDone => (c.warning, c.warningSoft, 'Awaiting confirm'),
          Forfeit.statusVerified => (c.success, c.successSoft, 'Served & confirmed'),
          Forfeit.statusFailed => (c.danger, c.dangerSoft, 'Failed'),
          _ => overdue
              ? (c.danger, c.dangerSoft, 'Overdue')
              : (c.primary, c.primarySoft, 'Due ${fromIsoDate(forfeit.dueDay).friendly}'),
        };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              EmojiAvatar(emoji, seed: seed, size: 34),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '"${forfeit.text}"',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      incoming
                          ? 'From $name · $statusLabel'
                          : 'For $name · $statusLabel',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              if (incoming && forfeit.status == Forfeit.statusPending)
                AppButton.primary('Served 💪',
                    size: AppButtonSize.small,
                    onTap: () {
                      app.arena.markForfeitDone(forfeit);
                      AppToast.show(context,
                          message: 'Served! They\'ll confirm it', emoji: '✅');
                    }),
              if (!incoming && forfeit.status == Forfeit.statusDone) ...<Widget>[
                AppButton.primary('Confirm',
                    size: AppButtonSize.small,
                    onTap: () {
                      app.arena.verifyForfeit(forfeit, true);
                      AppToast.show(context,
                          message: 'Confirmed — forfeit served', emoji: '🤝');
                    }),
                const SizedBox(width: Sp.sm),
                AppButton.ghost('Redo',
                    size: AppButtonSize.small,
                    onTap: () => app.arena.verifyForfeit(forfeit, false)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
