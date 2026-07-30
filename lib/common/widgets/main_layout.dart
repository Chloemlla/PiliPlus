import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxParentData, BoxHitTestResult, ChildLayoutHelper;

enum MainType { sideBar, body, bottomNav }

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout();
  }
}

class _RenderMainLayout extends RenderBox
    with SlottedContainerRenderObjectMixin<MainType, RenderBox> {
  Offset _getOffset(RenderBox child) {
    return (child.parentData as BoxParentData).offset;
  }

  void _setOffset(RenderBox child, Offset offset) {
    (child.parentData as BoxParentData).offset = offset;
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final sideBar = childForSlot(.sideBar);
    if (sideBar != null) {
      final sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      _setOffset(sideBar, .zero);

      bodyOffset = Offset(sideBarWidth, 0);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth - sideBarWidth,
        height: constraints.maxHeight,
      );
    } else {
      final bottomNav = childForSlot(.bottomNav);
      if (bottomNav != null) {
        final bottomNavSize = ChildLayoutHelper.layoutChild(
          bottomNav,
          constraints.loosen(),
        );
        _setOffset(
          bottomNav,
          Offset(
            (constraints.maxWidth - bottomNavSize.width) / 2,
            constraints.maxHeight - bottomNavSize.height,
          ),
        );
      }

      bodyOffset = .zero;
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      );
    }

    final body = childForSlot(.body)!..layout(bodyConstraints);
    _setOffset(body, bodyOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, _getOffset(child) + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final type in MainType.values.reversed) {
      final child = childForSlot(type);
      if (child == null) continue;
      final bool isHit = result.addWithPaintOffset(
        offset: _getOffset(child),
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) {
        return true;
      }
    }
    return false;
  }
}
