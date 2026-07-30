import 'package:pili_plus/utils/extension/theme_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

class SimpleAppBar extends StatelessWidget {
  const SimpleAppBar({
    super.key,
    required this.height,
    required this.brightness,
    Brightness? statusBarIconBrightness,
    this.backgroundColor = Colors.black,
  }) : statusBarIconBrightness = statusBarIconBrightness ?? .light;

  final double height;
  final Brightness brightness;
  final Brightness statusBarIconBrightness;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarBrightness: .light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: statusBarIconBrightness,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness.reverse,
      ),
      child: ColoredBox(
        color: backgroundColor,
        child: SizedBox(height: height, width: .infinity),
      ),
    );
  }
}
