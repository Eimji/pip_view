import 'package:flutter/material.dart';

import 'constants.dart';

enum PIPViewCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class RawPIPView extends StatefulWidget {
  final PIPViewCorner initialCorner;
  final double initialCornerTopPadding;
  final double initialCornerBottomPadding;
  final double? floatingWidth;
  final double? floatingHeight;
  final double? floatingBorderRadius;
  final EdgeInsets borderSpacing;
  final bool avoidKeyboard;
  final double keyboardPadding;
  final Widget? topWidget;
  final Widget? bottomWidget;
  // this is exposed because trying to watch onTap event
  // by wrapping the top widget with a gesture detector
  // causes the tap to be lost sometimes because it
  // is competing with the drag
  final void Function()? onTapTopWidget;

  const RawPIPView({
    Key? key,
    this.initialCorner = PIPViewCorner.topRight,
    this.initialCornerTopPadding = 0.0,
    this.initialCornerBottomPadding = 0.0,
    this.floatingWidth,
    this.floatingHeight,
    this.floatingBorderRadius = 10.0,
    this.borderSpacing = const EdgeInsets.all(16.0),
    this.avoidKeyboard = true,
    this.keyboardPadding = 0,
    this.topWidget,
    this.bottomWidget,
    this.onTapTopWidget,
  }) : super(key: key);

  @override
  RawPIPViewState createState() => RawPIPViewState();
}

class RawPIPViewState extends State<RawPIPView> with TickerProviderStateMixin {
  late final AnimationController _toggleFloatingAnimationController;
  late final AnimationController _dragAnimationController;
  Offset _dragOffset = Offset.zero;
  double _dragScale = 1.0;
  double _initialDragScale = 1.0;
  var _isDragging = false;
  var _isFloating = false;
  Widget? _bottomWidgetGhost;

  @override
  void initState() {
    super.initState();

    _toggleFloatingAnimationController = AnimationController(
      duration: defaultAnimationDuration,
      vsync: this,
    );
    _dragAnimationController = AnimationController(
      duration: defaultAnimationDuration,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant RawPIPView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isFloating) {
      if (widget.topWidget == null || widget.bottomWidget == null) {
        _isFloating = false;
        _bottomWidgetGhost = oldWidget.bottomWidget;
        _toggleFloatingAnimationController.reverse().whenCompleteOrCancel(() {
          if (mounted) {
            setState(() => _bottomWidgetGhost = null);
          }
        });
      }
    } else {
      if (widget.topWidget != null && widget.bottomWidget != null) {
        _isFloating = true;
        _toggleFloatingAnimationController.forward();
      }
    }
  }

  bool _isAnimating() {
    return _toggleFloatingAnimationController.isAnimating ||
        _dragAnimationController.isAnimating;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isAnimating()) return;

    _initialDragScale = _dragScale;

    setState(() {
      _isDragging = true;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset = _dragOffset.translate(
        details.focalPointDelta.dx,
        details.focalPointDelta.dy,
      );

      _dragScale = _initialDragScale * details.scale;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (!_isDragging) return;

    setState(() {
      _isDragging = false;
    });
    _dragAnimationController.forward().whenCompleteOrCancel(() {
      _dragAnimationController.value = 0;
      //_dragOffset = Offset.zero;
    });
  }

  Offset _fitOffset({
    required Size spaceSize,
    required Size widgetSize,
    required EdgeInsets windowPadding,
    Offset? currentOffset,
  }) {
    final left = widget.borderSpacing.left + windowPadding.left;
    final top = widget.borderSpacing.top + windowPadding.top;
    final right = spaceSize.width -
        widgetSize.width -
        windowPadding.right -
        widget.borderSpacing.right;
    final bottom = spaceSize.height -
        widgetSize.height -
        windowPadding.bottom -
        widget.borderSpacing.bottom;

    if (currentOffset == null) {
      switch (widget.initialCorner) {
        case PIPViewCorner.topLeft:
          return Offset(left, top + widget.initialCornerTopPadding);
        case PIPViewCorner.topRight:
          return Offset(right, top + widget.initialCornerTopPadding);
        case PIPViewCorner.bottomLeft:
          return Offset(left, bottom - widget.initialCornerBottomPadding);
        case PIPViewCorner.bottomRight:
          return Offset(right, bottom - widget.initialCornerBottomPadding);
        default:
          throw UnimplementedError();
      }
    } else {
      double dx = currentOffset.dx, dy = currentOffset.dy;

      if (currentOffset.dx < left) {
        dx = left;
      } else if (currentOffset.dx > right) {
        dx = right;
      }

      if (currentOffset.dy > bottom) {
        dy = bottom;
      } else if (currentOffset.dy < top) {
        dy = top;
      }

      return Offset(dx, dy);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    var windowPadding = mediaQuery.padding;
    if (widget.avoidKeyboard) {
      windowPadding += mediaQuery.viewInsets.copyWith(
          bottom: mediaQuery.viewInsets.bottom > 0
              ? mediaQuery.viewInsets.bottom + widget.keyboardPadding
              : 0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomWidget = widget.bottomWidget ?? _bottomWidgetGhost;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        double? initialFloatingWidth = widget.floatingWidth;
        double? initialFloatingHeight = widget.floatingHeight;

        if (initialFloatingWidth == null && initialFloatingHeight != null) {
          initialFloatingWidth = width / height * initialFloatingHeight;
        }
        initialFloatingWidth ??= 100.0;
        initialFloatingHeight ??= height / width * initialFloatingWidth;

        double floatingWidth = _dragScale * initialFloatingWidth;
        double floatingHeight = _dragScale * initialFloatingHeight;

        if (!_isDragging) {
          final ratio = initialFloatingWidth / initialFloatingHeight;
          final maxWidth = width -
              windowPadding.left -
              windowPadding.right -
              widget.borderSpacing.left -
              widget.borderSpacing.right;
          final maxHeight = height -
              windowPadding.top -
              windowPadding.bottom -
              widget.borderSpacing.top -
              widget.borderSpacing.bottom;

          if (floatingWidth > maxWidth) {
            _dragScale *= maxWidth / floatingWidth;
            floatingWidth = maxWidth;
            floatingHeight = floatingWidth / ratio;
          }
          if (floatingHeight > maxHeight) {
            _dragScale *= maxHeight / floatingHeight;
            floatingHeight = maxHeight;
            floatingWidth = ratio * floatingHeight;
          }

          if (initialFloatingWidth < maxWidth &&
              initialFloatingHeight < maxHeight) {
            if (floatingWidth < initialFloatingWidth) {
              _dragScale *= initialFloatingWidth / floatingWidth;
              floatingWidth = initialFloatingWidth;
              floatingHeight = initialFloatingHeight;
            }
            if (floatingHeight < initialFloatingHeight) {
              _dragScale *= initialFloatingHeight / floatingHeight;
              floatingHeight = initialFloatingHeight;
              floatingWidth = initialFloatingWidth;
            }
          }

          _dragOffset = _fitOffset(
            spaceSize: Size(width, height),
            widgetSize: Size(floatingWidth, floatingHeight),
            windowPadding: windowPadding,
            currentOffset: _dragOffset,
          );
        }

        final floatingWidgetSize = Size(floatingWidth, floatingHeight);
        final fullWidgetSize = Size(width, height);

        // BoxFit.cover
        final widthRatio = floatingWidth / width;
        final heightRatio = floatingHeight / height;
        final scaledDownScale = widthRatio > heightRatio
            ? floatingWidgetSize.width / fullWidgetSize.width
            : floatingWidgetSize.height / fullWidgetSize.height;

        return Stack(
          children: <Widget>[
            if (bottomWidget != null) bottomWidget,
            if (widget.topWidget != null)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _toggleFloatingAnimationController,
                  _dragAnimationController,
                ]),
                builder: (context, child) {
                  final animationCurve = CurveTween(
                    curve: Curves.easeInOutQuad,
                  );
                  final dragAnimationValue = animationCurve.transform(
                    _dragAnimationController.value,
                  );
                  final toggleFloatingAnimationValue = animationCurve.transform(
                    _toggleFloatingAnimationController.value,
                  );

                  final floatingOffset = _isDragging
                      ? _dragOffset
                      : Tween<Offset>(
                          begin: _dragOffset,
                          end: _dragOffset,
                        ).transform(_dragAnimationController.isAnimating
                          ? dragAnimationValue
                          : toggleFloatingAnimationValue);
                  final borderRadius = Tween<double>(
                    begin: 0,
                    end: widget.floatingBorderRadius,
                  ).transform(toggleFloatingAnimationValue);
                  final width = Tween<double>(
                    begin: fullWidgetSize.width,
                    end: floatingWidgetSize.width,
                  ).transform(toggleFloatingAnimationValue);
                  final height = Tween<double>(
                    begin: fullWidgetSize.height,
                    end: floatingWidgetSize.height,
                  ).transform(toggleFloatingAnimationValue);
                  final scale = Tween<double>(
                    begin: 1,
                    end: scaledDownScale,
                  ).transform(toggleFloatingAnimationValue);
                  return Positioned(
                    left: floatingOffset.dx,
                    top: floatingOffset.dy,
                    child: GestureDetector(
                      onScaleStart: _isFloating ? _onScaleStart : null,
                      onScaleUpdate: _isFloating ? _onScaleUpdate : null,
                      onScaleEnd: _isFloating ? _onScaleEnd : null,
                      onTap: widget.onTapTopWidget,
                      child: Material(
                        elevation: 10,
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          width: width,
                          height: height,
                          child: Transform.scale(
                            scale: scale,
                            child: OverflowBox(
                              maxHeight: fullWidgetSize.height,
                              maxWidth: fullWidgetSize.width,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: widget.topWidget,
              ),
          ],
        );
      },
    );
  }
}
