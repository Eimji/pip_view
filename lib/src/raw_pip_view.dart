import 'package:flutter/material.dart';

import 'constants.dart';

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
  late PIPViewCorner _corner;
  Offset _dragOffset = Offset.zero;
  double _dragScale = 1.0;
  double _initialDragScale = 1.0;
  var _isDragging = false;
  var _isFloating = false;
  Widget? _bottomWidgetGhost;
  Map<PIPViewCorner, Offset> _offsets = {};

  @override
  void initState() {
    super.initState();

    _corner = widget.initialCorner;

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

  void _updateCornersOffsets({
    required Size spaceSize,
    required Size widgetSize,
    required EdgeInsets windowPadding,
    required Offset currentOffset,
  }) {
    _offsets = _calculateOffsets(
      spaceSize: spaceSize,
      widgetSize: widgetSize,
      windowPadding: windowPadding,
      currentOffset: currentOffset,
    );
  }

  bool _isAnimating() {
    return _toggleFloatingAnimationController.isAnimating ||
        _dragAnimationController.isAnimating;
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isAnimating()) return;

    _initialDragScale = _dragScale;

    setState(() {
      _dragOffset = _offsets[_corner]!;
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

    final nearestCorner = _calculateNearestCorner(
      offset: _dragOffset,
      offsets: _offsets,
    );
    setState(() {
      _corner = nearestCorner;
      _isDragging = false;
    });
    _dragAnimationController.forward().whenCompleteOrCancel(() {
      _dragAnimationController.value = 0;
      //_dragOffset = Offset.zero;
    });
  }

  PIPViewCorner _calculateNearestCorner({
    required Offset offset,
    required Map<PIPViewCorner, Offset> offsets,
  }) {
    _CornerDistance calculateDistance(PIPViewCorner corner) {
      final distance = offsets[corner]!
          .translate(
            -offset.dx,
            -offset.dy,
          )
          .distanceSquared;
      return _CornerDistance(
        corner: corner,
        distance: distance,
      );
    }

    final distances = [PIPViewCorner.left, PIPViewCorner.right]
        .map(calculateDistance)
        .toList();

    distances.sort((cd0, cd1) => cd0.distance.compareTo(cd1.distance));

    return distances.first.corner;
  }

  Map<PIPViewCorner, Offset> _calculateOffsets({
    required Size spaceSize,
    required Size widgetSize,
    required EdgeInsets windowPadding,
    required Offset currentOffset,
  }) {
    Offset getOffsetForCorner(PIPViewCorner corner) {
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

      switch (corner) {
        case PIPViewCorner.topLeft:
          return Offset(left, top + widget.initialCornerTopPadding);
        case PIPViewCorner.topRight:
          return Offset(right, top + widget.initialCornerTopPadding);
        case PIPViewCorner.bottomLeft:
          return Offset(left, bottom - widget.initialCornerBottomPadding);
        case PIPViewCorner.bottomRight:
          return Offset(right, bottom - widget.initialCornerBottomPadding);
        case PIPViewCorner.left:
          if (currentOffset.dy < top) {
            return Offset(left, top);
          } else if (currentOffset.dy > bottom) {
            return Offset(left, bottom);
          } else {
            return Offset(left, currentOffset.dy);
          }
        case PIPViewCorner.right:
          if (currentOffset.dy < top) {
            return Offset(right, top);
          } else if (currentOffset.dy > bottom) {
            return Offset(right, bottom);
          } else {
            return Offset(right, currentOffset.dy);
          }
        default:
          throw UnimplementedError();
      }
    }

    final corners = _dragOffset == Offset.zero
        ? PIPViewCorner.values
        : [PIPViewCorner.left, PIPViewCorner.right];
    final Map<PIPViewCorner, Offset> offsets = {};
    for (final corner in corners) {
      offsets[corner] = getOffsetForCorner(corner);
    }

    return offsets;
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

        final floatingWidgetSize = Size(floatingWidth, floatingHeight);
        final fullWidgetSize = Size(width, height);

        _updateCornersOffsets(
          spaceSize: fullWidgetSize,
          widgetSize: floatingWidgetSize,
          windowPadding: windowPadding,
          currentOffset: _dragOffset,
        );

        final calculatedOffset = _offsets[_corner];

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
                          end: calculatedOffset,
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

enum PIPViewCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  right,
}

class _CornerDistance {
  final PIPViewCorner corner;
  final double distance;

  _CornerDistance({
    required this.corner,
    required this.distance,
  });
}
