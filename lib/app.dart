import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/utils/haptics.dart';
import 'core/widgets/toast.dart';
import 'data/models/arena.dart';
import 'app_routes.dart';
import 'features/app_shell.dart';
import 'features/onboarding/onboarding_page.dart';
import 'state/app_store.dart';

/// Handy access to the app-wide store.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class ArenaApp extends StatelessWidget {
  const ArenaApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (BuildContext context, _) {
          Haptics.enabled = store.hapticsEnabled;
          return MaterialApp(
            title: 'HabitNow Arena',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: store.themeMode,
            home: const _RootGate(),
            onGenerateRoute: appOnGenerateRoute,
          );
        },
      ),
    );
  }
}

/// Splash → onboarding → shell, with the award-celebration bridge.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final AppStore store = AppScope.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (BuildContext context, _) {
        if (!store.ready) return const _Splash();
        if (store.db.profile == null) return const OnboardingPage();
        return _CelebrationBridge(
          store: store,
          child: const AppShell(),
        );
      },
    );
  }
}

/// Drains [ArenaStore.pendingCelebrations] after each frame and stages
/// award moments over whatever screen is up.
class _CelebrationBridge extends StatefulWidget {
  const _CelebrationBridge({required this.store, required this.child});

  final AppStore store;
  final Widget child;

  @override
  State<_CelebrationBridge> createState() => _CelebrationBridgeState();
}

class _CelebrationBridgeState extends State<_CelebrationBridge> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final List<AwardDef> pending = widget.store.arena.pendingCelebrations;
    if (!_showing && pending.isNotEmpty) {
      _showing = true;
      final AwardDef def = pending.removeAt(0);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Celebration.celebrate(
          context,
          emoji: def.emoji,
          title: def.title,
          subtitle: def.description,
        );
        if (mounted) setState(() => _showing = false);
      });
    }
    return widget.child;
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.9, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (BuildContext context, double t, _) => Opacity(
            opacity: t,
            child: Transform.scale(scale: t, child: const _SplashMark()),
          ),
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: c.primarySoft,
            shape: BoxShape.circle,
            border: Border.all(color: c.primary.withValues(alpha: 0.35)),
          ),
          alignment: Alignment.center,
          child: const Text('⚔️', style: TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 20),
        Text(
          'HabitNow',
          style: Theme.of(context)
              .textTheme
              .displayMedium
              ?.copyWith(color: c.ink),
        ),
        const SizedBox(height: 6),
        Text(
          'grow together',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: c.inkMuted, letterSpacing: 1.5),
        ),
      ],
    );
  }
}
