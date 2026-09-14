#!/usr/bin/env python3
"""Named-argument checker: parses constructor + method signatures for the
project's own classes and verifies every call site's named arguments exist.
This is the highest-value check possible without the Dart analyzer."""
import os, re, sys

LIB = '/home/user/HabitNow/lib'

def strip(src: str) -> str:
    code = re.sub(r"'(?:[^'\\\n]|\\.)*'", "''", src)
    code = re.sub(r'"(?:[^"\\\n]|\\.)*"', '""', code)
    code = re.sub(r'//.*', '', code)
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    return code

def parse_members(src_code: str):
    """Returns {ClassName: {ctor_params: {named: {name: required}, positional: n},
    static_methods: {name: {named: {...}}}}, top_functions: {...}}"""
    out = {}

    # ---- classes & their constructors ------------------------------------
    for m in re.finditer(r'(?:@immutable\s+)?class\s+(\w+)(?:<[^{]*>)?\s*(?:extends\s+[\w<>,\s?.]+)?(?:\s+with\s+[\w<>,\s]+)?(?:\s+implements\s+[\w<>,\s]+)?\s*\{', src_code):
        cls = m.group(1)
        # find matching closing brace (naive brace counting)
        start = m.end() - 1
        depth = 0
        i = start
        while i < len(src_code):
            if src_code[i] == '{':
                depth += 1
            elif src_code[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = src_code[start:i]
        out[cls] = {'ctors': [], 'statics': set(), 'methods': {}}
        # constructors: ClassName( ... ) incl. named ClassName.x
        for cm in re.finditer(r'(?:const\s+)?' + cls + r'(?:\.\w+)?\s*\(', body):
            sig_start = cm.end() - 1
            d = 0
            j = sig_start
            while j < len(body):
                if body[j] == '(': d += 1
                elif body[j] == ')':
                    d -= 1
                    if d == 0: break
                j += 1
            params = body[sig_start+1:j]
            named = {}
            npart = params[params.find('{'):] if '{' in params else ''
            for pm in re.finditer(r'(required\s+)?\s*(?:(this|super)\.)?([A-Z]\w*\s+)?(\w+)\s*(?:=(?:[^,)]|\([^()]*\))*[^,)]*)?\s*(?:,|\}|$)', npart):
                name = pm.group(4)
                # 'required AppStore store' -> group3='AppStore ', group4='store'
                if pm.group(3) and pm.group(2) is None:
                    name = pm.group(4)
                named[name] = pm.group(1) is not None
            out[cls]['ctors'].append(named)
        # static methods with params (only names, we just need existence)
        for sm in re.finditer(r'static\s+[\w<>,\s?]+?\s+(\w+)\s*\(', body):
            out[cls]['statics'].add(sm.group(1))

    # ---- top-level functions ---------------------------------------------
    top = {}
    for m in re.finditer(r'^(?:Future<[^>]+>|Future|void|bool|int|String|double|Map<[^>]+>|List<[^>]+>|Set<[^>]+>|[\w<>?]+)\s+(\w+)\s*\(', src_code, re.M):
        top[m.group(1)] = True
    return out, top

def main():
    files = {}
    for dirpath, _, fs in os.walk(LIB):
        for f in fs:
            if f.endswith('.dart'):
                p = os.path.join(dirpath, f)
                files[p] = strip(open(p, encoding='utf-8').read())

    classes = {}
    tops = {}
    for p, code in files.items():
        c, t = parse_members(code)
        for k, v in c.items():
            classes.setdefault(k, []).append((p, v))
        tops[p] = t

    # SDK classes commonly constructed in this codebase (allowlist of named args we use)
    SDK_NAMED = {
        'Text': ['style','maxLines','overflow','textAlign','softWrap'],
        'Icon': ['size','color','semanticLabel'],
        'Container': ['padding','decoration','child','alignment','width','height','margin',
                       'constraints','transform','clip'],
        'SizedBox': ['width','height','child'],
        'Padding': ['padding','child'],
        'Column': ['children','mainAxisSize','crossAxisAlignment','mainAxisAlignment'],
        'Row': ['children','mainAxisSize','crossAxisAlignment','mainAxisAlignment'],
        'Stack': ['children','alignment','clipBehavior','fit'],
        'Positioned': ['left','right','top','bottom','child','width','height'],
        'Expanded': ['child','flex'],
        'GestureDetector': ['onTap','onLongPress','behavior','child','onTapUp','onTapDown',
                            'onTapCancel'],
        'AnimatedContainer': ['duration','curve','padding','decoration','child','alignment',
                              'width','height','onEnd','margin','constraints'],
        'TweenAnimationBuilder': ['tween','duration','curve','builder','child','onEnd'],
        'CustomPaint': ['painter','child','size','foregroundPainter'],
        'ListView': ['padding','children','scrollDirection','physics','shrinkWrap',
                     'itemBuilder','itemCount','separatorBuilder','controller',
                     'addAutomaticKeepAlives'],
        'SafeArea': ['child','top','bottom','left','right'],
        'Scaffold': ['backgroundColor','body','appBar','floatingActionButton',
                     'floatingActionButtonLocation','bottomNavigationBar','extendBody'],
        'AppBar': ['title','actions','backgroundColor','surfaceTintColor','centerTitle',
                   'elevation','scrolledUnderElevation','titleSpacing','iconTheme',
                   'actionsIconTheme','toolbarTextStyle','systemOverlayStyle',
                   'automaticallyImplyLeading','toolbarHeight','leading'],
        'TextField': ['controller','focusNode','autofocus','keyboardType','minLines',
                      'maxLines','maxLength','onChanged','style','cursorColor','decoration',
                      'obscureText','enabled'],
        'InputDecoration': ['counterText','hintText','hintStyle','prefixIcon',
                            'prefixIconConstraints','filled','fillColor','contentPadding',
                            'enabledBorder','focusedBorder','border','labelText',
                            'suffixIcon','isDense','errorText'],
        'OutlineInputBorder': ['borderRadius','borderSide'],
        'Switch': ['value','onChanged','activeColor'],
        'Slider': ['value','min','max','divisions','label','onChanged','activeColor'],
        'SegmentedButton': ['segments','selected','onSelectionChanged','style',
                            'showSelectedIcon'],
        'ButtonSegment': ['value','icon','label'],
        'Tooltip': ['message','child'],
        'Dialog': ['backgroundColor','shape','child','insetAnimationDuration'],
        'TextButton': ['onPressed','style','child'],
        'IconButton': ['onPressed','icon','color','tooltip','iconSize','padding'],
        'Divider': ['color','thickness','height','indent','endIndent'],
        'RefreshIndicator': ['onRefresh','child','color','backgroundColor','edgeOffset',
                             'displacement','triggerMode'],
        'Dismissible': ['key','direction','onDismissed','background','child',
                        'confirmDismiss','secondaryBackground'],
        'SnackBar': ['content','action','behavior','shape','duration','backgroundColor',
                     'width','margin'],
        'SnackBarAction': ['label','onPressed','textColor'],
        'BoxDecoration': ['color','borderRadius','border','boxShadow','shape','gradient',
                          'image','backgroundBlendMode'],
        'Border': ['all','top','bottom','left','right','fromSTLB'],
        'BorderSide': ['color','width','style'],
        'BorderRadius': ['circular','horizontal','vertical','only','all'],
        'Radius': ['circular'],
        'EdgeInsets': ['all','symmetric','only','fromLTRB','zero'],
        'BoxShadow': ['color','blurRadius','spreadRadius','offset','blurStyle'],
        'Offset': ['zero','infinite','fromDirection'],
        'Rect': ['fromLTWH','fromCenter','fromCircle','zero'],
        'RRect': ['fromRectAndRadius','fromLTRBR'],
        'LinearGradient': ['begin','end','colors','stops','transform'],
        'Paint': [],
        'TextEditingController': ['text'],
        'TextSelection': ['collapsed'],
        'TimeOfDay': ['hour','minute'],
        'ThemeData': ['useMaterial3','colorScheme','scaffoldBackgroundColor','splashFactory',
                      'extensions','textTheme','visualDensity','materialTapTargetSize',
                      'appBarTheme','dividerTheme','splashColor','highlightColor',
                      'textSelectionTheme','switchTheme','checkboxTheme','sliderTheme',
                      'progressIndicatorTheme','snackBarTheme','platform','dialogTheme',
                      'iconTheme','iconButtonTheme'],
        'ColorScheme': ['brightness','primary','onPrimary','primaryContainer',
                        'onPrimaryContainer','secondary','onSecondary','secondaryContainer',
                        'onSecondaryContainer','tertiary','onTertiary','tertiaryContainer',
                        'onTertiaryContainer','error','onError','errorContainer',
                        'onErrorContainer','surface','onSurface','surfaceContainerHighest',
                        'surfaceContainerHigh','surfaceContainer','surfaceContainerLow',
                        'surfaceContainerLowest','onSurfaceVariant','outline',
                        'outlineVariant','inverseSurface','onInverseSurface',
                        'inversePrimary','shadow','scrim'],
        'AppBarTheme': ['backgroundColor','surfaceTintColor','elevation',
                        'scrolledUnderElevation','centerTitle','titleSpacing','iconTheme',
                        'actionsIconTheme','toolbarTextStyle','systemOverlayStyle'],
        'TextTheme': ['displayLarge','displayMedium','displaySmall','headlineMedium',
                      'headlineSmall','titleLarge','titleMedium','titleSmall','bodyLarge',
                      'bodyMedium','bodySmall','labelLarge','labelMedium','labelSmall'],
        'TextStyle': ['fontSize','height','letterSpacing','fontWeight','color',
                      'fontFeatures','decoration','decorationColor','decorationThickness',
                      'overflow','wordSpacing','background','fontStyle','shadows',
                      'textBaseline','leadingDistribution','inherit'],
        'SwitchThemeData': ['thumbColor','trackColor','trackOutlineColor','overlayColor'],
        'CheckboxThemeData': ['fillColor','checkColor','side','shape'],
        'SliderThemeData': ['activeTrackColor','inactiveTrackColor','thumbColor',
                            'overlayColor','valueIndicatorColor','valueIndicatorTextStyle'],
        'ProgressIndicatorThemeData': ['color','linearTrackColor','circularTrackColor'],
        'SnackBarThemeData': ['backgroundColor','contentTextStyle','behavior','shape'],
        'DividerThemeData': ['color','thickness','space'],
        'TextSelectionThemeData': ['cursorColor','selectionColor','selectionHandleColor'],
        'IconThemeData': ['color','size'],
        'PageRouteBuilder': ['settings','transitionDuration','reverseTransitionDuration',
                             'pageBuilder','transitionsBuilder','opaque','barrierDismissible'],
        'ValueKey': [],
        'KeyedSubtree': ['key','child'],
        'AnimatedSwitcher': ['duration','child','switchInCurve','switchOutCurve',
                             'transitionBuilder','layoutBuilder'],
        'FadeTransition': ['opacity','child'],
        'ScaleTransition': ['scale','child'],
        'SlideTransition': ['position','child'],
        'SlideTransitionX': [],
        'Tween': ['begin','end'],
        'CurvedAnimation': ['parent','curve','reverseCurve'],
        'AnimationController': ['vsync','duration','reverseDuration','value','lowerBound',
                                'upperBound'],
        'Semantics': ['label','button','checked','child','selected','onTapHint','hidden'],
        'IgnorePointer': ['child','ignoring'],
        'Theme': ['data','child'],
        'StatefulBuilder': ['builder'],
        ' Builder': [],
        'ClipRRect': ['borderRadius','child','clipBehavior'],
        'Align': ['alignment','child','widthFactor','heightFactor'],
        'Center': ['child','widthFactor','heightFactor'],
        'AspectRatio': ['aspectRatio','child'],
        'CircularProgressIndicator': [],
        'Builder': ['builder'],
        'GestureDetectorX': [],
        'ConstrainedBox': ['constraints','child'],
        'Wrap': ['spacing','runSpacing','children','alignment','runAlignment',
                 'crossAxisAlignment'],
        'Flexible': ['child','flex','fit'],
        'Spacer': ['flex'],
        'Opacity': ['opacity','child'],
        'AnimatedOpacity': ['opacity','duration','child','curve'],
        'AnimatedScale': ['scale','duration','child','curve'],
        'AnimatedDefaultTextStyle': ['style','duration','child','curve'],
        'AnimatedPositioned': ['duration','left','right','top','bottom','width','height',
                               'child','curve'],
        'IntrinsicHeight': ['child'],
        'Material': ['color','child','shape','borderRadius','type','elevation'],
        'Scrollbar': ['controller','child','thumbVisibility'],
        'SingleChildScrollView': ['padding','child','controller','physics','scrollDirection'],
        'PageView': ['controller','children','onPageChanged','physics',
                     'allowImplicitScrolling'],
        'Transform': ['translate','scale','rotate','child','transform','alignment',
                      'origin','transformHitTests'],
        'DecoratedBox': ['decoration','child','position'],
        'Listener': ['onPointerDown','child'],
        'Placeholder': [],
        'AlertDialog': ['title','content','actions','backgroundColor','shape',
                        'titleTextStyle','contentTextStyle','actionsAlignment'],
        'BottomSheet': ['onClosing','builder','backgroundColor','shape'],
        'Colors': [],
        'Timer': ['periodic'],
        'Stopwatch': [],
    }

    errors = []
    # scan call sites: ClassName( ... named: ... )
    for p, code in files.items():
        for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\s*(?:<[^()<>]*>)?\s*\(', code):
            cls = m.group(1)
            if cls in ('If','For','While','Switch','Return','Assert'):
                continue
            # find arg list
            start = m.end() - 1
            d = 0
            j = start
            while j < len(code):
                if code[j] == '(': d += 1
                elif code[j] == ')':
                    d -= 1
                    if d == 0: break
                j += 1
            args = code[start+1:j]
            # only interested if there are named args
            if not re.search(r'(\w+)\s*:', args):
                continue
            # extract named args at top nesting level
            named_used = []
            depth = 0
            k = 0
            while k < len(args):
                ch = args[k]
                if ch in '([{':
                    depth += 1
                elif ch in ')]}':
                    depth -= 1
                elif depth == 0 and re.match(r'\w+\s*:', args[k:]):
                    prev = args[max(0, k-2):k]
                    # skip member access (a.b) and ternary else-branch (? x : y)
                    if prev.rstrip().endswith('.') or prev.lstrip().startswith('?'):
                        nm = re.match(r'(\w+)', args[k:]).group(1)
                        k += len(nm)
                        continue
                    nm = re.match(r'(\w+)\s*:', args[k:]).group(1)
                    named_used.append((nm, k))
                    k += len(nm)
                k += 1
            if not named_used:
                continue

            if cls in classes:
                valid = set()
                for _, entry in classes[cls]:
                    for ctor in entry['ctors']:
                        valid |= set(ctor.keys())
                for nm, _ in named_used:
                    if nm not in valid:
                        errors.append(f'{p}: {cls} has no named param "{nm}"')
            elif cls in SDK_NAMED:
                valid = set(SDK_NAMED[cls])
                for nm, _ in named_used:
                    if nm not in valid:
                        errors.append(f'{p}: SDK {cls} named param "{nm}" (check manually)')
            # unknown classes: skip (SDK or checker limitation)

    seen = {}
    for e in errors:
        seen[e] = seen.get(e, 0) + 1
    for e in sorted(seen):
        print(('!!' if 'SDK' not in e else '??') + ' ' + e + (f' x{seen[e]}' if seen[e] > 1 else ''))
    print(f'\n{len(seen)} unique findings')

if __name__ == '__main__':
    main()
