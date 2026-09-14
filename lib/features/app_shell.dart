import 'package:flutter/material.dart';

import '../app.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/palette.dart';
import '../core/utils/haptics.dart';
import '../core/widgets/primitives.dart';
import '../core/widgets/sheets.dart';
import '../state/app_store.dart';
import 'arena/arena_page.dart';
import 'arena/challenge_create_sheet.dart';
import 'habits/habits_page.dart';
import 'habits/habit_editor.dart';
import 'home/home_page.dart';
import 'profile/profile_page.dart';
import 'tasks/task_editor.dart';
import 'tasks/tasks_page.dart';

/// Root scaffold: fade-through page switcher + custom nav rail + a single
/// "create" button that opens the context-aware creation sheet.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<({IconData icon, IconData active, String label})>
      _tabs = <({IconData icon, IconData active, String label})>[
    (icon: Icons.wb_sunny, active: Icons.wb_sunny, label: 'Today'),
    (icon: Icons.bolt_outlined, active: Icons.bolt, label: 'Habits'),
    (icon: Icons.checklist_outlined, active: Icons.checklist, label: 'Tasks'),
    (icon: Icons.emoji_events_outlined,
        active: Icons.emoji_events,
        label: 'Arena'),
    (icon: Icons.person_outline, active: Icons.person, label: 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: FadeThroughSwitcher(
        index: _index,
        children: <Widget>[
          HomePage(onGotoHabits: () => setState(() => _index = 1)),
          HabitsPage(onCreateHabit: () => _openCreate(context)),
          TasksPage(onCreateTask: () => _openCreate(context)),
          ArenaPage(
            onCreateChallenge: () => _openCreate(context, preferChallenge: true),
          ),
          const ProfilePage(),
        ],
      ),
      floatingActionButton: _index == 4
          ? null
          : _CreateFab(onTap: () => _openCreate(context)),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      bottomNavigationBar: _NavBar(
        tabs: _tabs,
        index: _index,
        onChange: (int i) {
          Haptics.select();
          setState(() => _index = i);
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context,
      {bool preferChallenge = false}) async {
    final AppStore app = AppScope.of(context);
    final String? choice = await showAppSheet<String>(
      context: context,
      builder: (BuildContext ctx) =>
          _CreateSheet(preferChallenge: preferChallenge),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'habit':
        await showHabitEditor(context, app);
      case 'task':
        await showTaskEditor(context, app);
      case 'challenge':
        await showChallengeCreator(context, app);
    }
  }
}

/// Fade-through transition between shell pages (Material motion spec).
class FadeThroughSwitcher extends StatelessWidget {
  const FadeThroughSwitcher({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.emphasized,
      switchOutCurve: Motion.exit,
      transitionBuilder: (Widget child, Animation<double> a) {
        final bool entering = child.key == ValueKey<int>(index);
        return FadeTransition(
          opacity: entering
              ? CurvedAnimation(parent: a, curve: const Interval(0.3, 1))
              : a.drive(Tween<double>(begin: 1, end: 0)),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: entering ? 0.98 : 1.02,
              end: 1.0,
            ).animate(a),
            child: child,
          ),
        );
      },
      layoutBuilder: (Widget? current, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            ...previousChildren,
            if (current != null) current,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(index),
        child: children[index],
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      semanticLabel: 'Create habit, task or challenge',
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: c.primary,
          shape: BoxShape.circle,
          boxShadow: Elev.shadow(3, dark: context.isDark),
        ),
        child: Icon(Icons.add, color: c.onPrimary, size: 26),
      ),
    );
  }
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({required this.preferChallenge});

  final bool preferChallenge;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final List<({String icon, String title, String sub, String choice, int? tabIndex})>
        options = <({String icon, String title, String sub, String choice, int? tabIndex})>[
      (
        icon: '🎯',
        title: 'New habit',
        sub: 'Something you\'ll repeat',
        choice: 'habit',
        tabIndex: 0,
      ),
      (
        icon: '✅',
        title: 'New task',
        sub: 'Once, or on a schedule',
        choice: 'task',
        tabIndex: 0,
      ),
      (
        icon: '⚔️',
        title: 'New challenge',
        sub: 'Head-to-head with a friend',
        choice: 'challenge',
        tabIndex: 0,
      ),
    ];
    if (preferChallenge) {
      options.insert(
        0,
        options.removeLast(),
      );
    }
    return SheetScaffold(
      title: 'Create',
      subtitle: 'Pick what you\'re starting',
      child: Column(
        children: <Widget>[
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: AppCard(
                onTap: () => Navigator.of(context).pop(o.choice),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child:
                          Text(o.icon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: Sp.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(o.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(o.sub,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.inkFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.tabs,
    required this.index,
    required this.onChange,
  });

  final List<({IconData icon, IconData active, String label})> tabs;
  final int index;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Theme(
      data: Theme.of(context),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.hairline)),
          boxShadow: Elev.shadow(2, dark: context.isDark),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64 + 6,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      data: tabs[i],
                      selected: i == index,
                      color: c,
                      onTap: () => onChange(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) data;
  final bool selected;
  final AppColors color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = selected ? color.primary : color.inkFaint;
    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.emphasized,
              padding:
                  const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? color.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Icon(
                selected ? data.active : data.icon,
                size: 23,
                color: tint,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.base,
              style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                  .copyWith(
                color: selected ? color.ink : color.inkFaint,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
