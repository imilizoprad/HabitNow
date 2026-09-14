#!/usr/bin/env python3
"""Type-resolution checker: every Capitalized identifier used in a file must
be declared locally, declared in an imported package:habit_now file, or in
the SDK allowlist. Catches missing imports and typo'd type names."""
import os, re, sys

LIB = '/home/user/HabitNow/lib'

SDK = {
    # dart:core
    'String','int','double','bool','List','Map','Set','Iterable','Future','Stream',
    'DateTime','Duration','Object','Null','Num','Comparable','Override','Deprecated',
    'Function','Type','RegExp','Match','Sink','Iterator','Symbol','Uri','Expando',
    'StringBuffer','Stopwatch','UnimplementedError','StateError','ArgumentError',
    'FormatException','RangeError','Exception','Error','WeakReference','Record',
    # flutter foundation/material/widgets/painting/rendering/animation
    'Widget','StatelessWidget','StatefulWidget','State','BuildContext','Key','ValueKey',
    'UniqueKey','ObjectKey','GlobalKey','ChangeNotifier','Listenable','ValueListenable',
    'Color','Colors','IconData','Icons','TextStyle','TextTheme','FontFeature','FontWeight',
    'EdgeInsets','BorderRadius','Border','BorderSide','BoxDecoration','BoxShadow','BlurStyle',
    'Offset','Size','Rect','RRect','Path','Canvas','Paint','CustomPainter','TextPainter',
    'Curves','Curve','Cubic','Animatable','Animation','AnimationController','Tween',
    'TweenAnimationBuilder','AnimatedBuilder','CurvedAnimation','Interval','SlideTransition',
    'FadeTransition','ScaleTransition','DecoratedBox','Container','Padding','Center','Column',
    'Row','Stack','Positioned','Expanded','Flexible','SizedBox','ConstrainedBox','Align',
    'ClipRRect','ClipRect','CustomPaint','GestureDetector','Semantics','SafeArea','Spacer',
    'Divider','Text','RichText','TextSpan','WidgetSpan','TextField','TextEditingController',
    'FocusNode','Focus','ScrollController','ListView','GridView','PageView','PageController',
    'SingleChildScrollView','RefreshIndicator','Dismissible','AnimatedContainer',
    'AnimatedOpacity','AnimatedScale','AnimatedSwitcher','AnimatedDefaultTextStyle',
    'AnimatedPositioned','AnimatedSize','AnimatedAlign','DefaultTextStyle','Theme','ThemeData',
    'ColorScheme','TextTheme','IconTheme','IconThemeData','MaterialApp','Scaffold','AppBar',
    'PreferredSizeWidget','FloatingActionButtonLocation','SnackBar','SnackBarAction',
    'ScaffoldMessenger','ScaffoldMessengerState','BottomSheet','showModalBottomSheet',
    'showDialog','showTimePicker','showDatePicker','Dialog','AlertDialog','TextButton',
    'IconButton','Switch','Slider','Checkbox','LinearProgressIndicator','CircularProgressIndicator',
    'InputDecoration','InputDecorationTheme','OutlineInputBorder','UnderlineInputBorder',
    'MaterialStateProperty','WidgetStateProperty','WidgetState','WidgetStateBorderSide',
    'ButtonStyle','SegmentedButton','ButtonSegment','Tooltip','Overlay','OverlayEntry',
    'OverlayState','Navigator','PageRouteBuilder','RouteSettings','Route','MaterialRouteMixin',
    'ModalRoute','ModalBarrier','TickerProviderStateMixin','SingleTickerProviderStateMixin',
    'WidgetsBinding','WidgetsBindingObserver','AppLifecycleState','SystemChrome','SystemUiMode',
    'SystemUiOverlayStyle','SystemUiOverlay','Brightness','TargetPlatform','ThemeMode',
    'VisualDensity','MaterialTapTargetSize','MediaQuery','LayoutBuilder','BoxConstraints',
    'InheritedWidget','InheritedNotifier','Dependency','ListenableBuilder','AnimatedBuilder',
    'Ticker','TickerProvider','SchedulerBinding','SchedulerPhase','FrameCallback','RouteObserver',
    'ScrollPhysics','BouncingScrollPhysics','ClampingScrollPhysics','AlwaysScrollableScrollPhysics',
    'NeverScrollableScrollPhysics','FontFeature','TextAlign','TextOverflow','MainAxisAlignment',
    'CrossAxisAlignment','MainAxisSize','WrapAlignment','Wrap','Flow','TableCell','Table',
    'StackFit','Stack','Flex','Flush','Controller','LinearGradient','RadialGradient',
    'SweepGradient','Gradient','Shader','MaskFilter','StrokeCap','StrokeJoin','PaintingStyle',
    'TileMode','BlendMode','FilterQuality','ImageFilter','ColorFilter','Matrix4','DiagnosticsNode',
    'debugPrint','PlatformException','MissingPluginException','MethodChannel','EventChannel',
    'OptionalMethodChannel','DefaultWidgetsLocalizations','WidgetError','FlutterError',
    'FlutterErrorDetails','PlatformDispatcher','SizeChangedLayoutNotifier','ValueNotifier',
    'TweenSequence','TweenSequenceItem','Material','MaterialColor','MaterialStateMouseCursor',
    'MouseCursor','SystemMouseCursors','RestorationMixin','RebuildableWidget','SliverAppBar',
    'SliverList','SliverGrid','CustomScrollView','SliverChildBuilderDelegate','ScrollView',
    'ScrollBehavior','StretchingOverscrollIndicator','GlowingOverscrollIndicator',
    'Hero','TickerMode','AbsorbPointer','IgnorePointer','Visibility','Offstage','KeepAlive',
    'AutomaticKeepAliveClientMixin','EffectiveTickerProvider','ColorTween','RectTween',
    'RelativeRectTween','BoxConstraintsTween','Curves','ElasticInCurve','ElasticOutCurve',
    'ListBody','IndexedStack','OverflowBox','SizedOverflowBox','FittedBox','Baseline',
    'FractionallySizedBox','IntrinsicHeight','IntrinsicWidth','PhysicalModel','PhysicalShape',
    'RotatedBox','Transform','CompositedTransformTarget','CompositedTransformFollower',
    'Directionality','Opacity','RawImage','Image','ImageIcon','AssetImage','NetworkImage',
    'FileImage','MemoryImage','DecorationImage','BoxShape','Axis','VerticalDirection',
    'HorizontalDirection','TextDirection','TextBaseline','Stack','WrapCrossAlignment',
    'ListTile','CircleAvatar','Chip','InputChip','ActionChip','Card','ExpansionTile',
    'PopupMenuButton','PopupMenuItem','DropdownButton','DropdownMenuItem','Stepper','TabBar',
    'TabBarView','TabController','Tab','BottomNavigationBar','BottomNavigationBarItem',
    'NavigationRail','Drawer','DrawerHeader','UserAccountsDrawerHeader','ProgressIndicator',
    'ReorderableListView','Scrollbar','ScrollConfiguration','RefreshIndicatorState',
    'SelectionContainer','SelectableRegion','SelectableText','ToolbarOptions','TextSelectionTheme',
    'TextSelectionThemeData','SwitchTheme','SwitchThemeData','CheckboxTheme','CheckboxThemeData',
    'Radio','RadioTheme','RadioThemeData','SliderTheme','SliderThemeData','ProgressIndicatorTheme',
    'ProgressIndicatorThemeData','SnackBarThemeData','DialogTheme','DialogThemeData',
    'TabBarTheme','TabBarThemeData','DividerThemeData','IconThemeData','AppBarTheme',
    'PopupMenuThemeData','TooltipThemeData','CardTheme','CardThemeData','PageTransitionsTheme',
    'ScrollBehavior','MaterialScrollBehavior','TimeOfDay','showDatePicker','DatePickerThemeData',
    'CupertinoColors','CupertinoIcons','SvgPicture','AspectRatio','FractionalTranslation',
    'SliverPadding','SliverToBoxAdapter','PrimaryScrollController','MainMenu','MaterialBanner',
    'UndoHistory','SmartDashesType','SmartQuotesType','TextInputType','TextInputFormatter',
    'FilteringTextInputFormatter','LengthLimitingTextInputFormatter','MaxLinesEnforcement',
    'AutofillHints','AutofillGroup','EditableText','EditableText','CupertinoTextField',
    'ObfuscateSelection','SelectionChangedCause','GestureBinding','RendererBinding',
    'ServicesBinding','HistogramShader','Picture','PictureRecorder','Vertices','VertexMode',
    'PointMode','ImageShader','Locale','Localizations','LocalizationsDelegate',
    'DefaultLocalizations','Brightness','HapticFeedback','Clipboard','ClipboardData',
    'LogicalKeyboardKey','RawKeyboard','RawKeyEvent','KeyDownEvent','KeyUpEvent',
    'CallbackShortcuts','Shortcuts','Actions','Intent','Action','FocusScope','FocusTraversalGroup',
    'ReadOnlyFocus','TickerCancelledException','SynchronousFuture','AsyncMemoizer','Result',
    'Observable','ProxyAnimation','AnimationStatus','Curves','ThreePointCubic','FlippedCurve',
    # dart:async / dart:io / dart:typed_data / dart:math
    'Timer','Timer.periodic','Completer','StreamController','StreamSubscription','Sink',
    'Socket','SocketStream','ServerSocket','SocketException','SocketOption','RawSocket',
    'RawSocketEvent','RawDatagramSocket','Datagram','InternetAddress','InternetAddressType',
    'File','FileMode','FileSystemException','Directory','RandomAccessFile','Process',
    'Uint8List','Int8List','Int32List','Int64List','Float32List','Float64List','ByteData',
    'Endian','BytesBuilder','ByteBuffer','UnmodifiableUint8ListView',
    'Random','SecureRandom','Math','BigInt','SocketAddress','FileStat','Filesystem',
    'Alignment','AlignmentGeometry','EdgeInsetsGeometry','AxisDirection','GrowthDirection',
    'BoxPainter','TextScaler','TextScalerLinear','OffsetBase','Degrees','Radians',
    'SynchronousFuture','AsyncMemoizer','Priority','FontFeature','ExperimentalFeature',
    'Locale','Clipboard','Paste','Placeholder','SpanLimiter','Overflow','WidgetOrder',
    'VoidCallback','ValueChanged','IndexedWidgetBuilder','NullableIndexedWidgetBuilder',
    'Icon','Icons','IconData','Builder','StatefulBuilder','LayoutWidgetBuilder',
    'HitTestBehavior','TextDecoration','StackTrace','UnmodifiableListView','Throwable',
    'DiagnosticableTree','KeyedSubtree','SliverLayoutBuilder','ParentDataVisitor',
    'Clip','Radius','MapEntry','TickerFuture','FutureOr','SplayTreeMap','Queue','Double',
    'PathMetric','PathMetrics','ColoredBox','WidgetBuilder','JsonValue','JsonEncoder',
    'JsonDecoder','JsonCodec','You','Indent','AsciiCodec','Base64Codec','Base64UrlCodec',
    'InkSparkle','SnackBarBehavior','MaterialStatePropertyAll','WidgetStatePropertyAll',
    'Brightness','DynamicSchemeVariant','FlexTones','SuggestionsBinding',
    'ConstraintAdjustment','PopupPrecedence','ThemeExtension','Shadow','ImageConfiguration',
    'SawTooth','Interval','Easing','Ellipsize','TextHeightBehavior','TextWidthBasis',
    'DefaultTextStyle','FontLoader','FontWeight','FontStyle','PlaceholderAlignment','LineMetrics',
    'TextBox','TextPosition','TextRange','TextSelection','Paragraph','ParagraphBuilder',
    'ParagraphConstraints','ParagraphStyle','TextStyle','StrutStyle','LocaleString',
    'AppLifeCycleState','SemanticsFlag','SemanticsAction','CustomClipper','ListWheelViewport',
    'ListWheelScrollView','ShadingWarmUp','ShaderWarmUp','PipelineOwner','RenderObject',
    'RenderBox','RenderObjectWidget','LeafRenderObjectWidget','SingleChildRenderObjectWidget',
    'MultiChildRenderObjectWidget','ParentDataWidget','RenderObjectElement','ComponentElement',
    'StatelessElement','StatefulElement','Element','BuildOwner','BuildScope','RootWidget',
    'WidgetsFlutterBinding','HardwareKeyboard','KeyData','TextInput','TextEditingValue',
    'TextEditingDelta','TextSelectionOverlay','ClipboardStatus','MouseRegion','Listener',
    'PointerDownEvent','PointerUpEvent','PointerMoveEvent','PointerEvent','PointerDeviceKind',
    'DragStartBehavior','ScrollViewKeyboardDismissBehavior','KeyboardListener',
    'SliverOverlapInjector','SliverPersistentHeader','SliverPersistentHeaderDelegate',
    'NestedScrollView','SliverOverlapAbsorber','TickerProviderStateMixin',
    'AutomaticKeepAlive','ParentData','FlexParentData','Flex','RenderFlex','RenderPadding',
    'RenderProxyBox','RenderShiftedBox','BoxParentData','BoxPainter','Decoration','BoxPainter',
    'ShapeDecoration','UnderlineTabIndicator','CircleBorder','RoundedRectangleBorder',
    'StadiumBorder','BeveledRectangleBorder','ContinuousRectangleBorder','OutlinedBorder',
    'ButtonBar','ButtonBarTheme','ButtonBarThemeData','ToggleButtons','ToggleButtonsTheme',
    'MaterialState','MaterialStatePropertyAll','WidgetStatePropertyAll','MaterialPropertyResolver',
    'SnackBarAction','DismissibleDismissDirection','DismissDirection','ResizeImage',
    'ScrollIncrementAlgorithm','ScrollIncrementCalculator','TwoDimensionalScrollable',
    'VerticalDirection','NavigationDrawer','NavigationBar','NavigationBarThemeData',
    'NavigationDestination','OverlayPortal','OverlayPortalController','SelectionArea',
    'ContextMenuButtonItem','AdaptiveTextSelectionToolbar','TextMagnifier','TextSelectionPoint',
    'GestureRecognition','VelocityTracker','Drag','DragDownDetails','DragStartDetails',
    'DragUpdateDetails','DragEndDetails','LongPressGestureRecognizer','TapGestureRecognizer',
    'DoubleTapGestureRecognizer','PanGestureRecognizer','ScaleGestureRecognizer',
    'VerticalDragGestureRecognizer','HorizontalDragGestureRecognizer','ForcePressGestureRecognizer',
    'MultiTapGestureRecognizer','RenderSemanticsGestureHandler','SemanticsConfiguration',
    'SemanticsHandle','SemanticsOwner','SemanticsUpdateBuilder','CustomSemanticsAction',
    'HighlightedRegion','CompositedTransform','LayerLink','LeaderLayer','FollowerLayer',
    'ContainerLayer','OpacityLayer','ClipRectLayer','TransformLayer','OffsetLayer',
    'PictureLayer','TextureLayer','PlatformViewLayer','PerformanceOverlayLayer',
    'AnnotatedRegionLayer','ShaderMaskLayer','BackdropFilterLayer','ImageFilterLayer',
    'ColorFilterLayer','ImageLayer','AnnotationLayer','Layer','AlwaysCompleteAnimation',
    'AlwaysStoppedAnimation','ProxyElement','RenderTree','UserUpdateNotification',
}

def declared_names(src_code: str) -> set:
    names = set()
    for m in re.finditer(
        r'\b(?:class|abstract class|mixin|enum|extension|typedef)\s+(\w+)', src_code):
        names.add(m.group(1))
    for m in re.finditer(r'^(?:@immutable\s+)?(?:[\w<>(),\s]+?\s)?(\w+)\s*\(', src_code, re.M):
        pass
    # top-level & static-ish functions and consts (crude but effective)
    for m in re.finditer(r'^(?:final|const|var|void|Future<[^>]+>|Future|[A-Z][\w<>?]*)\s+(\w+)\s*[=(]', src_code, re.M):
        names.add(m.group(1))
    for m in re.finditer(r'^\s*(?:static\s+)?(?:const|final)\s+(\w+)\s+(\w+)\s*=', src_code, re.M):
        names.add(m.group(2))
    for m in re.finditer(r'^\s*(?:static\s+)?(?:const|final)\s+([A-Z][\w<>?]*)\s+(\w+)\s*=', src_code, re.M):
        names.add(m.group(2))
    return names

def main():
    files = {}
    for dirpath, _, fs in os.walk(LIB):
        for f in fs:
            if f.endswith('.dart'):
                p = os.path.join(dirpath, f)
                files[p] = open(p, encoding='utf-8').read()

    # declared names per file path (relative to lib)
    decl = {p: declared_names(src) for p, src in files.items()}

    errors = []
    for p, src in files.items():
        # imports scanned on RAW source (strings must survive)
        imported = set()
        dirpath = os.path.dirname(p)
        for m in re.finditer(r"(?:import|export)\s+'([^']+)'", src):
            uri = m.group(1)
            if uri.startswith('dart:') or (uri.startswith('package:') and not uri.startswith('package:habit_now/')):
                continue
            if uri.startswith('package:habit_now/'):
                cand = os.path.join(LIB, uri.replace('package:habit_now/', ''))
            else:
                cand = os.path.normpath(os.path.join(dirpath, uri))
            if cand in files:
                imported |= decl[cand]

        # then strip comments/strings for identifier scan
        code = re.sub(r"'(?:[^'\\]|\\.)*'", "''", src)
        code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code)
        code = re.sub(r'//.*', '', code)
        code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)

        local = decl[p] | imported | SDK
        # identifiers that look like types/constructors
        for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\b', code):
            name = m.group(1)
            if name in local or len(name) == 1:
                continue
            # lowercase-first usage => probably a getter/field, skip if followed by '(' it's a ctor
            errors.append(f'{p}: unresolved type {name} (col {m.start()})')

    # de-dup + report
    seen = {}
    for e in errors:
        f, n = e.split(': unresolved type ')
        seen.setdefault((f, n), 0)
        seen[(f, n)] += 1
    for (f, n), count in sorted(seen.items()):
        print(f'{f}: {n} x{count}')
    total = sum(seen.values())
    print(f'\n{len(seen)} unique unresolved, {total} occurrences')

if __name__ == '__main__':
    main()
