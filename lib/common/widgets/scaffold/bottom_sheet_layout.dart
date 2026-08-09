import 'package:pili_plus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox, ChildLayoutHelper;

enum BottomSheetType { bottomSheet, body }

class BottomSheetLayout
    extends SlottedMultiChildRenderObjectWidget<BottomSheetType, RenderBox> {
  const BottomSheetLayout({
    super.key,
    this.bottomSheet,
    required this.body,
  });

  final Widget? bottomSheet;
  final Widget body;

  @override
  Iterable<BottomSheetType> get slots => BottomSheetType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .bottomSheet => bottomSheet,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<BottomSheetType, RenderBox>
  createRenderObject(
    BuildContext context,
  ) {
    return _RenderBottomSheetLayout();
  }
}

class _RenderBottomSheetLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<BottomSheetType, RenderBox>,
        SlottedLayoutMixin {
  RenderBox? get bottomSheet => childForSlot(.bottomSheet);
  RenderBox get body => childForSlot(.body)!;

  @override
  Iterable<BottomSheetType> get slots => BottomSheetType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final body = this.body..layout(BoxConstraints.tight(size));
    setSlotOffset(body, .zero);

    final bottomSheet = this.bottomSheet;
    if (bottomSheet != null) {
      final sheetSize = ChildLayoutHelper.layoutChild(
        bottomSheet,
        constraints.loosen(),
      );
      setSlotOffset(
        bottomSheet,
        Offset(0, constraints.maxHeight - sheetSize.height),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, slotOffsetOf(child) + offset);
      }
    }

    doPaint(body);
    doPaint(bottomSheet);
  }
}
