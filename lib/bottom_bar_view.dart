import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/tabIcon_data.dart';
import 'theme/app_theme.dart';

class BottomBarView extends StatefulWidget {
  const BottomBarView({
    super.key,
    this.tabIconsList,
    this.changeIndex,
    this.addClick,
    this.themeColor,
  });

  final Function(int index)? changeIndex;
  final Function()? addClick;
  final List<TabIconData>? tabIconsList;
  final Color? themeColor;
  static const double baseHeight = 100.0;

  @override
  State<BottomBarView> createState() => _BottomBarViewState();
}

class _BottomBarViewState extends State<BottomBarView>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;

  Color get _actionColor => widget.themeColor ?? AppTheme.nearlyDarkBlue;
  Color get _actionForegroundColor => _onColorFor(_actionColor);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _tabAt(int index) {
    final tabs = widget.tabIconsList ?? const <TabIconData>[];
    if (index >= tabs.length) {
      return const Expanded(child: SizedBox.shrink());
    }
    return Expanded(
      child: TabIcons(
        tabIconData: tabs[index],
        activeColor: _actionColor,
        removeAllSelect: () {
          _setRemoveAllSelection(tabs[index]);
          widget.changeIndex?.call(index);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: BottomBarView.baseHeight + safeBottom,
      child: Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: <Widget>[
          AnimatedBuilder(
            animation: _animationController,
            builder: (BuildContext context, Widget? child) {
              final radius = Tween<double>(begin: 0.0, end: 1.0)
                      .animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.fastOutSlowIn,
                        ),
                      )
                      .value *
                  38.0;
              return Transform(
                transform: Matrix4.translationValues(0.0, 0.0, 0.0),
                child: PhysicalShape(
                  color: AppTheme.white,
                  elevation: 16.0,
                  clipper: TabClipper(radius: radius),
                  child: Column(
                    children: <Widget>[
                      SizedBox(
                        height: 62,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            top: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              _tabAt(0),
                              _tabAt(1),
                              SizedBox(
                                width: Tween<double>(begin: 0.0, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: _animationController,
                                            curve: Curves.fastOutSlowIn,
                                          ),
                                        )
                                        .value *
                                    64.0,
                              ),
                              _tabAt(2),
                              _tabAt(3),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: safeBottom),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.only(bottom: safeBottom),
            child: SizedBox(
              width: 38 * 2.0,
              height: 38 + 62.0,
              child: Container(
                alignment: Alignment.topCenter,
                color: Colors.transparent,
                child: SizedBox(
                  width: 38 * 2.0,
                  height: 38 * 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ScaleTransition(
                      alignment: Alignment.center,
                      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.fastOutSlowIn,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _actionColor,
                          gradient: LinearGradient(
                            colors: <Color>[
                              _actionColor,
                              _lighter(_actionColor, 0.20),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _actionColor.withValues(alpha: 0.4),
                              offset: const Offset(8.0, 16.0),
                              blurRadius: 16.0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            splashColor:
                                _actionForegroundColor.withValues(alpha: 0.14),
                            highlightColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            onTap: widget.addClick,
                            child: Icon(
                              Icons.receipt_long,
                              color: _actionForegroundColor,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setRemoveAllSelection(TabIconData? tabIconData) {
    if (!mounted || tabIconData == null) return;
    setState(() {
      widget.tabIconsList?.forEach((TabIconData tab) {
        tab.isSelected = tabIconData.index == tab.index;
      });
    });
  }
}

class TabIcons extends StatefulWidget {
  const TabIcons({
    super.key,
    this.tabIconData,
    this.removeAllSelect,
    this.activeColor,
  });

  final TabIconData? tabIconData;
  final Function()? removeAllSelect;
  final Color? activeColor;

  @override
  State<TabIcons> createState() => _TabIconsState();
}

class _TabIconsState extends State<TabIcons> with TickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          if (!mounted) return;
          widget.removeAllSelect?.call();
          _animationController.reverse();
        }
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setAnimation() {
    _animationController.forward();
  }

  Widget _buildMainIcon() {
    final tab = widget.tabIconData;
    if (tab == null) return const SizedBox.shrink();
    final selected = tab.isSelected;
    final selectedPath = tab.selectedImagePath;
    final defaultPath = tab.imagePath;
    final path = selected && (selectedPath != null && selectedPath.isNotEmpty)
        ? selectedPath
        : defaultPath;

    if (path != null && path.isNotEmpty) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }

    if (tab.iconData != null) {
      return Icon(
        tab.iconData,
        size: 24,
        color: selected
            ? (widget.activeColor ?? AppTheme.nearlyDarkBlue)
            : AppTheme.grey,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tabIconData;
    if (tab == null) {
      return const SizedBox.shrink();
    }

    final dotColor = _readableAccentOnWhite(
      widget.activeColor ?? AppTheme.nearlyDarkBlue,
    );
    return Center(
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: () {
          if (!tab.isSelected) {
            _setAnimation();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IgnorePointer(
              child: SizedBox(
                width: 30,
                height: 30,
                child: Stack(
                  alignment: AlignmentDirectional.center,
                  children: <Widget>[
                    ScaleTransition(
                      alignment: Alignment.center,
                      scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(
                            0.1,
                            1.0,
                            curve: Curves.fastOutSlowIn,
                          ),
                        ),
                      ),
                      child: _buildMainIcon(),
                    ),
                    Positioned(
                      top: 4,
                      left: 6,
                      right: 0,
                      child: ScaleTransition(
                        alignment: Alignment.center,
                        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.2,
                              1.0,
                              curve: Curves.fastOutSlowIn,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 6,
                      bottom: 8,
                      child: ScaleTransition(
                        alignment: Alignment.center,
                        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.5,
                              0.8,
                              curve: Curves.fastOutSlowIn,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 8,
                      bottom: 0,
                      child: ScaleTransition(
                        alignment: Alignment.center,
                        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(
                              0.5,
                              0.6,
                              curve: Curves.fastOutSlowIn,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: tab.isSelected ? dotColor : AppTheme.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TabClipper extends CustomClipper<Path> {
  TabClipper({this.radius = 38.0});

  final double radius;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double v = radius * 2;
    path.lineTo(0, 0);
    path.arcTo(
      Rect.fromLTWH(0, 0, radius, radius),
      _degreeToRadians(180),
      _degreeToRadians(90),
      false,
    );
    path.arcTo(
      Rect.fromLTWH(
        ((size.width / 2) - v / 2) - radius + v * 0.04,
        0,
        radius,
        radius,
      ),
      _degreeToRadians(270),
      _degreeToRadians(70),
      false,
    );
    path.arcTo(
      Rect.fromLTWH((size.width / 2) - v / 2, -v / 2, v, v),
      _degreeToRadians(160),
      _degreeToRadians(-140),
      false,
    );
    path.arcTo(
      Rect.fromLTWH(
        (size.width - ((size.width / 2) - v / 2)) - v * 0.04,
        0,
        radius,
        radius,
      ),
      _degreeToRadians(200),
      _degreeToRadians(70),
      false,
    );
    path.arcTo(
      Rect.fromLTWH(size.width - radius, 0, radius, radius),
      _degreeToRadians(270),
      _degreeToRadians(90),
      false,
    );
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TabClipper oldClipper) => true;

  double _degreeToRadians(double degree) => (math.pi / 180) * degree;
}

Color _lighter(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final adjusted = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
  return adjusted.toColor();
}

Color _onColorFor(Color background) {
  return background.computeLuminance() > 0.62 ? Colors.black87 : Colors.white;
}

Color _readableAccentOnWhite(Color color) {
  if (color.computeLuminance() <= 0.55) {
    return color;
  }
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation + 0.10).clamp(0.0, 1.0))
      .withLightness(0.30)
      .toColor();
}
