import 'package:pili_plus/common/widgets/custom_icon.dart';
import 'package:pili_plus/models/common/enum_with_label.dart';
import 'package:pili_plus/pages/dynamics/view.dart';
import 'package:pili_plus/pages/home/view.dart';
import 'package:pili_plus/pages/mine/view.dart';
import 'package:flutter/material.dart';

enum NavigationBarType implements EnumWithLabel {
  home(
    '首页',
    Icon(Icons.home_outlined),
    Icon(Icons.home),
    HomePage(),
  ),
  dynamics(
    '动态',
    Icon(CustomIcons.motion_photos_on_outlined),
    Icon(CustomIcons.motion_photos_on),
    DynamicsPage(),
  ),
  mine(
    '我的',
    Icon(Icons.person_outline),
    Icon(Icons.person),
    MinePage(),
  ),
  ;

  @override
  final String label;
  final Icon icon;
  final Icon selectIcon;
  final Widget page;

  const NavigationBarType(this.label, this.icon, this.selectIcon, this.page);
}
