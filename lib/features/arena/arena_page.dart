import 'package:flutter/material.dart';

import '../../app.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../state/app_store.dart';
import 'challenges_tab.dart';
import 'friends_tab.dart';
import 'league_tab.dart';

class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key, required this.onCreateChallenge});

  final VoidCallback onCreateChallenge;

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> {
  int _tab = 0;

  static const List<String> _tabs = <String>['Radar', 'Duels', 'League'];

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppStore app = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(Sp.screenH, Sp.xl, Sp.screenH, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Arena',
                          style:
                              Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(app),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                if (app.networkDegraded)
                  Icon(Icons.wifi_off, size: 20, color: c.warning),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.screenH),
            child: _TabSwitcher(
              tabs: _tabs,
              index: _tab,
              onChange: (int i) => setState(() => _tab = i),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.base,
              switchInCurve: Motion.emphasized,
              switchOutCurve: Motion.exit,
              transitionBuilder: (Widget child, Animation<double> a) =>
                  FadeTransition(
                opacity:
                    CurvedAnimation(parent: a, curve: Motion.emphasized),
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_tab),
                child: switch (_tab) {
                  0 => FriendsTab(onCreateChallenge: widget.onCreateChallenge),
                  1 => ChallengesTab(
                      onCreateChallenge: widget.onCreateChallenge),
                  _ => const LeagueTab(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppStore app) {
    final int connected = app.arena.connected.length;
    final int visible = app.arena.visible.length;
    if (connected > 0) {
      return '$connected connected · $visible on the network';
    }
    if (visible > 0) {
      return '$visible nearby — tap to connect';
    }
    return 'Looking for players on your network…';
  }
}

/// Segmented control with a sliding pill indicator.
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.tabs,
    required this.index,
    required this.onChange,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: LayoutBuilder(builder:
          (BuildContext context, BoxConstraints constraints) {
        final double w = constraints.maxWidth / tabs.length;
        return Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: Motion.base,
              curve: Motion.emphasized,
              left: w * index,
              width: w,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  boxShadow: Elev.shadow(1, dark: context.isDark),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                for (int i = 0; i < tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChange(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: Motion.base,
                          style: (Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: i == index
                                        ? c.ink
                                        : c.inkMuted,
                                    fontWeight: i == index
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  )) ??
                              const TextStyle(),
                          child: Text(tabs[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
