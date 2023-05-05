import 'package:flutter/material.dart';

import 'dismiss_keyboard.dart';
import 'raw_pip_view.dart';

class PIPView extends StatefulWidget {
  final PIPViewCorner initialCorner;
  final double initialCornerTopPadding;
  final double initialCornerBottomPadding;
  final double? floatingWidth;
  final double? floatingHeight;
  final double? floatingBorderRadius;
  final EdgeInsets borderSpacing;
  final bool avoidKeyboard;
  final double keyboardPadding;
  final VoidCallback? onExpanded;

  final Widget Function(
    BuildContext context,
    bool isFloating,
  ) builder;

  const PIPView({
    Key? key,
    required this.builder,
    this.initialCorner = PIPViewCorner.topRight,
    this.initialCornerTopPadding = 0.0,
    this.initialCornerBottomPadding = 0.0,
    this.floatingWidth,
    this.floatingHeight,
    this.floatingBorderRadius = 10.0,
    this.borderSpacing = const EdgeInsets.all(16.0),
    this.avoidKeyboard = true,
    this.keyboardPadding = 0,
    this.onExpanded,
  }) : super(key: key);

  @override
  PIPViewState createState() => PIPViewState();

  static PIPViewState? of(BuildContext context) {
    return context.findAncestorStateOfType<PIPViewState>();
  }
}

class PIPViewState extends State<PIPView> with TickerProviderStateMixin {
  Widget? _bottomWidget;

  void presentBelow(Widget widget) {
    dismissKeyboard(context);
    setState(() => _bottomWidget = widget);
  }

  void stopFloating() {
    dismissKeyboard(context);
    setState(() => _bottomWidget = null);
    if (widget.onExpanded != null) {
      widget.onExpanded!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFloating = _bottomWidget != null;
    return RawPIPView(
      avoidKeyboard: widget.avoidKeyboard,
      keyboardPadding: widget.keyboardPadding,
      bottomWidget: isFloating
          ? Navigator(
              onGenerateInitialRoutes: (navigator, initialRoute) => [
                MaterialPageRoute(builder: (context) => _bottomWidget!),
              ],
            )
          : null,
      onTapTopWidget: isFloating ? stopFloating : null,
      topWidget: IgnorePointer(
        ignoring: isFloating,
        child: Builder(
          builder: (context) => widget.builder(context, isFloating),
        ),
      ),
      floatingHeight: widget.floatingHeight,
      floatingWidth: widget.floatingWidth,
      floatingBorderRadius: widget.floatingBorderRadius,
      initialCorner: widget.initialCorner,
      initialCornerTopPadding: widget.initialCornerTopPadding,
      initialCornerBottomPadding: widget.initialCornerBottomPadding,
      borderSpacing: widget.borderSpacing,
    );
  }
}
