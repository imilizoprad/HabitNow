import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/date_x.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/progress.dart';
import '../../core/widgets/text_field.dart';
import '../../core/widgets/toast.dart';
import '../../data/models/habit.dart';
import '../../state/app_store.dart';

/// Focus timer — the redesigned stopwatch from the original HabitNow.
/// Tap the ring to start/pause; long-press to reset; save logs a session.
class FocusPage extends StatefulWidget {
  const FocusPage({super.key, this.label, this.habitId, this.taskId});

  final String? label;
  final String? habitId;
  final String? taskId;

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  static const int _goalSeconds = 25 * 60; // pomodoro-ish default

  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  late final TextEditingController _labelCtrl =
      TextEditingController(text: widget.label ?? 'Focus');
  String? get _habitId => widget.habitId;

  @override
  void initState() {
    super.initState();
    _labelCtrl.addListener(() {
      // Sync without rebuilding — the timer keeps ticking independently.
      _label = _labelCtrl.text;
    });
  }

  String get _label => _labelCtrl.text;

  @override
  void dispose() {
    _ticker?.cancel();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  void _toggle() {
    Haptics.light();
    setState(() {
      if (_watch.isRunning) {
        _watch.stop();
        _ticker?.cancel();
      } else {
        _watch.start();
        _startTicking();
      }
    });
  }

  void _reset() {
    Haptics.warning();
    setState(() {
      _watch
        ..stop()
        ..reset();
      _ticker?.cancel();
    });
  }

  Future<void> _save() async {
    final int secs = _watch.elapsedMilliseconds ~/ 1000;
    if (secs < 5) {
      AppToast.show(context, message: 'Run it a little longer first 🙂', emoji: '⏱️');
      return;
    }
    final AppStore app = AppScope.of(context);
    app.tasks.addSession(FocusSession(
      id: newId('fs'),
      label: _label,
      startedAt: DateTime.now()
          .subtract(_watch.elapsed)
          .millisecondsSinceEpoch,
      seconds: secs,
      habitId: _habitId,
    ));
    Haptics.success();
    _reset();
    if (mounted) {
      AppToast.show(context, message: 'Session saved · +focus', emoji: '🤿');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final int elapsed = _watch.elapsedMilliseconds ~/ 1000;
    final double progress = (elapsed % _goalSeconds) / _goalSeconds;
    final AppStore app = AppScope.of(context);
    final List<FocusSession> today = app.tasks.sessionsToday;
    final int todaySecs =
        today.fold(0, (int a, FocusSession s) => a + s.seconds);

    return Scaffold(
      backgroundColor: c.scaffold,
      appBar: AppBar(
        title:
            Text('Focus', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Entrance(
                      index: 0,
                      child: GestureDetector(
                        onLongPress: _reset,
                        child: Pressable(
                          onTap: _toggle,
                          semanticLabel: _watch.isRunning
                              ? 'Pause focus timer'
                              : 'Start focus timer',
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              ProgressRing(
                                progress: progress,
                                color: _watch.isRunning
                                    ? c.primary
                                    : c.inkFaint,
                                trackColor: c.surfaceAlt,
                                size: 240,
                                stroke: 13,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    formatDuration(
                                        Duration(seconds: elapsed)),
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayLarge,
                                  ),
                                  const SizedBox(height: Sp.xs),
                                  Text(
                                    _watch.isRunning
                                        ? 'TAP TO PAUSE · HOLD TO RESET'
                                        : 'TAP TO START',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                            color: c.inkFaint,
                                            letterSpacing: 1.2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.xxl),
                    Entrance(
                      index: 1,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: Sp.screenH),
                        child: AppTextField(
                          controller: _labelCtrl,
                          hint: 'What are you focusing on?',
                          maxLength: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: Sp.xl),
                    Entrance(
                      index: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          AppButton.primary('Save session',
                              icon: Icons.bookmark_add_outlined,
                              onTap: _save),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Sp.screenH, 0, Sp.screenH, Sp.xl),
              child: AppCard(
                child: Row(
                  children: <Widget>[
                    Icon(Icons.history, size: 20, color: c.inkMuted),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Text(
                        today.isEmpty
                            ? 'No sessions today yet'
                            : '${today.length} session${today.length == 1 ? '' : 's'} today · ${formatDuration(Duration(seconds: todaySecs))} focused',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
