import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/palette.dart';

/// Bottom sheets: consistent shape, drag handle, safe areas, scroll-safe
/// with the keyboard.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool dismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).extension<AppColors>()!.overlayScrim,
    builder: (BuildContext ctx) => _SheetShell(child: builder(ctx)),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AnimatedBuilder(
      animation: ModalRoute.of(context)!.animation!,
      builder: (BuildContext context, Widget? _) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.xl)),
              border: Border(
                top: BorderSide(color: c.hairline),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: Sp.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                ),
                Flexible(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Standard sheet scaffold: title, optional subtitle, scrollable content,
/// bottom action row.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.actions,
    this.bottomActions,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final List<Widget>? bottomActions;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(subtitle!,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
            const SizedBox(height: Sp.sm),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    Sp.xl, Sp.sm, Sp.xl, Sp.sm),
                child: child,
              ),
            ),
            if (bottomActions != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    Sp.xl,
                    Sp.sm,
                    Sp.xl,
                    Sp.xl + MediaQuery.of(context).padding.bottom * 0.2),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < bottomActions!.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: Sp.md),
                      Expanded(child: bottomActions![i]),
                    ],
                  ],
                ),
              ),
          ],
        ),
      );
  }
}

/// Confirm dialog with the house style.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final AppColors c = context.colors;
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => Dialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.l),
        side: BorderSide(color: c.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: Sp.md),
            Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: Sp.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                        foregroundColor: c.inkMuted,
                        minimumSize: const Size.fromHeight(46)),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          destructive ? c.danger : c.primaryDeep,
                      backgroundColor: destructive
                          ? c.dangerSoft
                          : c.primarySoft,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
