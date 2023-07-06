import 'package:flutter/material.dart';
import 'package:side_panel_flutter/side_panel_container_settings.dart';

class SidePanelContainer extends StatefulWidget {
  const SidePanelContainer({
    Key? key,
    required this.sidePanelBuilder,
    required this.mainContentBuilder,
    this.onAnimationStatusChanged,
    this.ignorePointer = false,
    this.settings = const SidePanelContainerSettings(),
  }) : super(key: key);

  final WidgetBuilder sidePanelBuilder;
  final WidgetBuilder mainContentBuilder;
  final bool ignorePointer;
  final AnimationStatusListener? onAnimationStatusChanged;
  final SidePanelContainerSettings settings;

  @override
  SidePanelContainerState createState() => SidePanelContainerState();
}

class SidePanelContainerState extends State<SidePanelContainer> with TickerProviderStateMixin {
  static final kMinimumDistanceToDetectDragging = 20.0;
  final mainContentKey = GlobalKey();

  late AnimationController _mainContentAnimationController;

  Animation? mainContentAnimation;
  Animation? mainContentOpacityAnimation;
  Animation? sidePanelAnimation;

  bool isClosed = true;
  bool isClosing = false;
  bool isOpen = false;
  bool isOpening = false;

  double _currentProgressPercent = 0.0;

  double _onHorizontalDragDownPositionDx = 0.0;
  Offset _onHorizontalDragDownOffset = Offset.zero;

  /// Toggle drawer
  void toggleSidePanel() => _mainContentAnimationController.isCompleted
      ? _mainContentAnimationController.reverse()
      : _mainContentAnimationController.forward();

  /// Open drawer
  void openSidePanel() => _mainContentAnimationController.forward();

  /// Close drawer
  void closeSidePanel() => _mainContentAnimationController.reverse();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (mainContentKey.globalPaintBounds!.contains(_onHorizontalDragDownOffset)) {
                closeSidePanel();
              }
            },
            onHorizontalDragDown: (details) {
              _onHorizontalDragDownOffset = details.globalPosition;
              _onHorizontalDragDownPositionDx = details.globalPosition.dx;
            },
            onHorizontalDragStart: (details) {
              _detectDirection();
              _normalizeOnPanDownPosition();
            },
            onHorizontalDragEnd: (details) {
              _openOrClosePanel();
            },
            onHorizontalDragUpdate: (details) {
              final panelWidth = widget.settings.sidePanelWidth;
              if (isOpening) {
                final globalPosition = details.globalPosition.dx - _onHorizontalDragDownPositionDx;
                double progress = globalPosition / panelWidth;
                _animate(normalizeProgressValue(progress));
              } else {
                final globalPosition = _onHorizontalDragDownPositionDx - details.globalPosition.dx;
                double progress = 1 - globalPosition / panelWidth;
                _animate(normalizeProgressValue(progress));
              }
            },
            child: Stack(
              children: [
                _MainContent(
                  shouldAbsorbPointer: isOpen,
                  animationController: _mainContentAnimationController,
                  animation: mainContentAnimation,
                  mainContentKey: mainContentKey,
                  opacityAnimation: mainContentOpacityAnimation,
                  contentBuilder: widget.mainContentBuilder,
                ),
                _SlidePanel(
                  sidePanelBuilder: widget.sidePanelBuilder,
                  shouldIgnorePointer: isClosed,
                  animationController: _mainContentAnimationController,
                  animation: sidePanelAnimation,
                  sidePanelWidth: widget.settings.sidePanelWidth,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double normalizeProgressValue(double position) {
    if (position > 1.0) {
      position = 1.0;
    }
    if (position < 0.0) {
      position = 0.0;
    }
    return position;
  }

  void _detectDirection() {
    isOpening = mainContentKey.globalPaintBounds!.left == 0;
    isClosing = !isOpening;
  }

  void _normalizeOnPanDownPosition() {
    if (isOpening) {
      _onHorizontalDragDownPositionDx += kMinimumDistanceToDetectDragging;
    } else {
      _onHorizontalDragDownPositionDx -= kMinimumDistanceToDetectDragging;
    }
  }

  @override
  void initState() {
    super.initState();
    _mainContentAnimationController = AnimationController(
      vsync: this,
      duration: widget.settings.animationDuration,
    )..addStatusListener((AnimationStatus status) {
        if (mounted) {
          isOpen = status == AnimationStatus.completed;
          isClosed = status == AnimationStatus.dismissed;
          widget.onAnimationStatusChanged?.call(status);
          setState(() {});
        }
      });
    _mainContentAnimationController.reset();
  }

  @override
  void didUpdateWidget(covariant SidePanelContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings.sidePanelWidth != oldWidget.settings.sidePanelWidth) {
      _onChangeSidePanelWidth();
    }
  }

  void _onChangeSidePanelWidth() {
    final sidePanelWidth = widget.settings.sidePanelWidth;

    mainContentAnimation = Tween<double>(begin: 0, end: sidePanelWidth).animate(
      CurvedAnimation(
        parent: _mainContentAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );

    sidePanelAnimation = Tween<double>(begin: -sidePanelWidth, end: 0).animate(
      CurvedAnimation(
        parent: _mainContentAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    final panelWidth = widget.settings.sidePanelWidth;

    mainContentAnimation ??= Tween<double>(begin: 0, end: panelWidth).animate(
      CurvedAnimation(
        parent: _mainContentAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );

    sidePanelAnimation ??= Tween<double>(begin: -panelWidth, end: 0).animate(
      CurvedAnimation(
        parent: _mainContentAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );

    mainContentOpacityAnimation ??= Tween<double>(begin: 1, end: 0.5).animate(
      CurvedAnimation(
        parent: _mainContentAnimationController,
        curve: Curves.easeIn,
        reverseCurve: Curves.easeOut,
      ),
    );
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
    _mainContentAnimationController.reset();
    _mainContentAnimationController.dispose();
    isOpen = false;
    isClosed = true;
  }

  void _openOrClosePanel() {
    if (widget.ignorePointer) return;

    final autocompletePercentLimit = widget.settings.autocompletePercentLimit;
    if (isOpening) {
      if (_currentProgressPercent >= autocompletePercentLimit) {
        openSidePanel();
      } else {
        closeSidePanel();
      }
      return;
    }

    if (isClosing) {
      if (_currentProgressPercent <= (1 - autocompletePercentLimit)) {
        closeSidePanel();
      } else {
        openSidePanel();
      }
      return;
    }
  }

  void _animate(double percent) {
    if (widget.ignorePointer) return;

    _currentProgressPercent = percent;
    _mainContentAnimationController.value = percent;
  }
}

extension GlobalKeyExtension on GlobalKey {
  Rect? get globalPaintBounds {
    final renderObject = currentContext?.findRenderObject();
    var translation = renderObject?.getTransformTo(null).getTranslation();

    if (translation != null) {
      return renderObject!.paintBounds.shift(
        Offset(translation.x, translation.y),
      );
    } else {
      return null;
    }
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    Key? key,
    required this.shouldAbsorbPointer,
    required this.animationController,
    required this.animation,
    required this.mainContentKey,
    required this.opacityAnimation,
    required this.contentBuilder,
  }) : super(key: key);

  final WidgetBuilder contentBuilder;
  final bool shouldAbsorbPointer;
  final GlobalKey<State<StatefulWidget>> mainContentKey;
  final AnimationController animationController;
  final Animation? animation;
  final Animation? opacityAnimation;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: shouldAbsorbPointer,
      child: AnimatedBuilder(
        animation: animationController,
        builder: (_, child) {
          return Transform.translate(
            offset: Offset(animation!.value, 0),
            child: child,
          );
        },
        child: Container(
          key: mainContentKey,
          width: double.infinity,
          height: double.infinity,
          child: AnimatedBuilder(
            animation: animationController,
            builder: (_, child) {
              return Opacity(
                opacity: opacityAnimation!.value,
                child: contentBuilder(context),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlidePanel extends StatelessWidget {
  const _SlidePanel({
    Key? key,
    required this.sidePanelBuilder,
    required this.shouldIgnorePointer,
    required this.animationController,
    required this.animation,
    required this.sidePanelWidth,
  }) : super(key: key);

  final WidgetBuilder sidePanelBuilder;
  final bool shouldIgnorePointer;
  final AnimationController animationController;
  final Animation? animation;
  final double sidePanelWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return IgnorePointer(
          ignoring: shouldIgnorePointer,
          child: AnimatedBuilder(
            animation: animationController,
            builder: (_, child) {
              return Transform.translate(
                offset: Offset(animation!.value, 0),
                child: child,
              );
            },
            child: Container(
              width: sidePanelWidth,
              height: constraints.maxHeight,
              child: sidePanelBuilder(context),
            ),
          ),
        );
      },
    );
  }
}
