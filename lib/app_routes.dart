import 'package:flutter/material.dart';

import 'core/theme/design_tokens.dart';
import 'features/arena/challenge_detail_page.dart';
import 'features/habits/habit_detail_page.dart';
import 'features/tasks/focus_page.dart';

/// Route arguments.
class HabitRouteArgs {
  const HabitRouteArgs(this.habitId);
  final String habitId;
}

class ChallengeRouteArgs {
  const ChallengeRouteArgs(this.challengeId);
  final String challengeId;
}

class FocusRouteArgs {
  const FocusRouteArgs({this.label, this.habitId, this.taskId});
  final String? label;
  final String? habitId;
  final String? taskId;
}

/// All detail routes push with the house fade-through transition.
Route<dynamic>? appOnGenerateRoute(RouteSettings settings) {
  final WidgetBuilder? builder = switch (settings.name) {
    '/habit' => () {
        final HabitRouteArgs a = settings.arguments! as HabitRouteArgs;
        return HabitDetailPage(habitId: a.habitId);
      },
    '/challenge' => () {
        final ChallengeRouteArgs a =
            settings.arguments! as ChallengeRouteArgs;
        return ChallengeDetailPage(challengeId: a.challengeId);
      },
    '/focus' => () {
        final FocusRouteArgs a =
            settings.arguments as FocusRouteArgs? ?? const FocusRouteArgs();
        return FocusPage(
            label: a.label, habitId: a.habitId, taskId: a.taskId);
      },
    _ => null,
  };
  if (builder == null) return null;
  return FadeThroughRoute<dynamic>(
    settings: settings,
    builder: builder,
  );
}

/// The house page transition: incoming fades + scales up from 96%,
/// outgoing fades out — calm, premium, never bouncy.
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: Motion.slow,
          reverseTransitionDuration: Motion.base,
          pageBuilder: (BuildContext _, Animation<double> __,
                  Animation<double> ___) =>
              builder(_),
          transitionsBuilder: (
            BuildContext _,
            Animation<double> animation,
            Animation<double> secondary,
            Widget child,
          ) {
            final CurvedAnimation fade =
                CurvedAnimation(parent: animation, curve: Motion.emphasized);
            return FadeTransition(
              opacity: fade.drive(Tween<double>(begin: 0, end: 1)),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Motion.emphasized)),
                child: child,
              ),
            );
          },
        );
}
