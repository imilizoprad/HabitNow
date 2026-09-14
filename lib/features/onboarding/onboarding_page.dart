import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/avatar.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/primitives.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/common.dart';
import '../../state/app_store.dart';

/// Avatar faces offered during onboarding and profile editing.
const List<String> kEmojiChoices = <String>[
  '🦁', '🐯', '🐻', '🐼', '🦊', '🐨', '🐸', '🦉', '🐙', '🦄',
  '🐺', '🦖', '🐝', '🦋', '🐢', '🦩', '🐳', '🌟',
];

/// Three-step onboarding: welcome → identity (name/emoji/color) → go.
/// Deliberately skippable-fast: one tap through if you're eager.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pager = PageController();
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode();

  int _step = 0;
  String _emoji = '🦁';
  int _seed = 0;

  @override
  void dispose() {
    _pager.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    Haptics.light();
    if (_step < 2) {
      await _pager.nextPage(
          duration: Motion.slow, curve: Motion.emphasized);
    }
  }

  Future<void> _finish() async {
    final AppStore app = AppScope.of(context);
    Haptics.medium();
    await app.completeOnboarding(
        name: _name.text, emoji: _emoji, colorSeed: _seed);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffold,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int i) => setState(() => _step = i),
                children: <Widget>[
                  _WelcomeStep(onNext: _next),
                  _IdentityStep(
                    nameController: _name,
                    nameFocus: _nameFocus,
                    emoji: _emoji,
                    seed: _seed,
                    onEmoji: (String e) {
                      Haptics.select();
                      setState(() => _emoji = e);
                    },
                    onSeed: (int s) {
                      Haptics.select();
                      setState(() => _seed = s);
                    },
                  ),
                  _GoStep(onFinish: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.sm, Sp.xl, Sp.xl),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < 3; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.emphasized,
                      height: 6,
                      width: i == _step ? 22 : 6,
                      decoration: BoxDecoration(
                        color:
                            i == _step ? c.primary : c.outline,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_step == 0)
                    AppButton.primary(
                      'Let\'s go',
                      icon: Icons.arrow_forward,
                      onTap: _next,
                    )
                  else if (_step == 1)
                    AppButton.primary('Continue', onTap: _next)
                  else
                    AppButton.primary('Start competing', onTap: _finish),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Entrance(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                _Bubble('🏃', Duration()),
                SizedBox(width: Sp.md),
                _Bubble('⚔️', Duration(milliseconds: 180)),
                SizedBox(width: Sp.md),
                _Bubble('🏆', Duration(milliseconds: 360)),
              ],
            ),
            const SizedBox(height: Sp.xxl),
            Text(
              'Habits are better\nwith rivals.',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(height: 1.12),
            ),
            const SizedBox(height: Sp.lg),
            Text(
              'Build habits, challenge friends on the same network, put '
              'points on the line — and let streaks do the talking. '
              'No accounts, no servers, ever.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: c.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.emoji, this.delay);

  final String emoji;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Motion.leisure + delay,
      curve: Interval((delay.inMilliseconds / 700).clamp(0.0, 0.9), 1,
          curve: Motion.springy),
      builder: (BuildContext context, double t, _) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: t.clamp(0.0, 1.0),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline),
              boxShadow: Elev.shadow(1, dark: context.isDark),
            ),
            alignment: Alignment.center,
            child:
                Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
        ),
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.nameController,
    required this.nameFocus,
    required this.emoji,
    required this.seed,
    required this.onEmoji,
    required this.onSeed,
  });

  final TextEditingController nameController;
  final FocusNode nameFocus;
  final String emoji;
  final int seed;
  final ValueChanged<String> onEmoji;
  final ValueChanged<int> onSeed;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Sp.huge),
          Text('Who\'s competing?',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: Sp.xs),
          Text('This is how friends will see you on the network.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Sp.xxl),
          Center(
            child: EmojiAvatar(emoji, seed: seed, size: 108, ring: true),
          ),
          const SizedBox(height: Sp.xxl),
          AppTextField(
            controller: nameController,
            focusNode: nameFocus,
            hint: 'Your name',
            maxLength: 24,
            prefix: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: Sp.xl),
          Text('PICK A FACE',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.md),
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.sm,
            children: <Widget>[
              for (final String e in kEmojiChoices)
                Pressable(
                  onTap: () => onEmoji(e),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: e == emoji ? c.primarySoft : c.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: e == emoji ? c.primary : Colors.transparent,
                          width: 1.6),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 21)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Text('YOUR COLOR',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: c.inkFaint, letterSpacing: 1.2)),
          const SizedBox(height: Sp.md),
          Row(
            children: <Widget>[
              for (int i = 0; i < 8; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: Sp.md),
                Pressable(
                  onTap: () => onSeed(i),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: HabitPalette.color(i),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == seed ? c.ink : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Sp.huge),
        ],
      ),
    );
  }
}

class _GoStep extends StatelessWidget {
  const _GoStep({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Entrance(
            index: 1,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('📡', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: Sp.md),
                  Text('Same Wi-Fi = teammates',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Friends on your network appear automatically. '
                    'Everything is device-to-device — no accounts, no cloud.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          Entrance(
            index: 2,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('⚔️', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: Sp.md),
                  Text('Stakes make it real',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Set a point stake, check in daily, and the winner takes '
                    'the pot at the finish. Losers serve forfeits.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          Entrance(
            index: 3,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('🏅', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: Sp.md),
                  Text('Awards for showing up',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Streaks, perfect weeks and challenge wins all unlock '
                    'awards for your shelf.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Sp.xl),
          Text(
            'You can change everything later in Profile.',
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
