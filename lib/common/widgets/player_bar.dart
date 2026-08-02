/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        ContainerRenderObjectMixin,
        MultiChildLayoutParentData,
        RenderBoxContainerDefaultsMixin,
        BoxHitTestResult,
        TransformLayer;

class PlayerBar extends MultiChildRenderObjectWidget {
  const PlayerBar({
    super.key,
    super.children,
  }) : assert(
         children.length == 2,
         'PlayerBar requires exactly two children: left and right controls.',
       );

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderBottomBar();
  }
}

class RenderBottomBar extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) {
      child.parentData = MultiChildLayoutParentData();
    }
  }

  Matrix4? _transform;

  @override
  void performLayout() {
    _transform = null;

    final childConstraints = constraints.copyWith(
      minWidth: 0.0,
      maxWidth: double.infinity,
    );
    final RenderBox first = firstChild!..layout(
      childConstraints,
      parentUsesSize: true,
    );
    final RenderBox last = lastChild!..layout(
      childConstraints,
      parentUsesSize: true,
    );

    final firstSize = first.size;
    final lastSize = last.size;

    final firstParentData = first.parentData as MultiChildLayoutParentData;
    final lastParentData = last.parentData as MultiChildLayoutParentData;

    final firstWidth = firstSize.width;
    final lastWidth = lastSize.width;
    final totalWidth = firstWidth + lastWidth;
    final desiredWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : totalWidth;
    final desiredHeight = math.max(firstSize.height, lastSize.height);
    size = constraints.constrainDimensions(
      desiredWidth.isFinite ? desiredWidth : 0.0,
      desiredHeight.isFinite ? desiredHeight : 0.0,
    );

    final barWidth = size.width;
    final barHeight = size.height;
    final firstDy = (barHeight - firstSize.height) / 2;
    final lastDy = (barHeight - lastSize.height) / 2;
    firstParentData.offset = Offset(0.0, firstDy.isFinite ? firstDy : 0.0);

    if (totalWidth.isFinite && totalWidth <= barWidth) {
      final lastDx = barWidth - lastWidth;
      lastParentData.offset = Offset(
        lastDx.isFinite ? lastDx : 0.0,
        lastDy.isFinite ? lastDy : 0.0,
      );
    } else if (barWidth > 0.0 && totalWidth.isFinite) {
      final scale = barWidth / totalWidth;
      _transform = Matrix4.identity()
        ..translateByDouble(0.0, barHeight * (1 - scale) / 2, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0);
      final lastDx = (barWidth - lastWidth * scale) / scale;
      lastParentData.offset = Offset(
        lastDx.isFinite ? lastDx : 0.0,
        lastDy.isFinite ? lastDy : 0.0,
      );
    } else {
      lastParentData.offset = Offset(0.0, lastDy.isFinite ? lastDy : 0.0);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_transform != null) {
      layer = context.pushTransform(
        needsCompositing,
        offset,
        _transform!,
        defaultPaint,
        oldLayer: layer as TransformLayer?,
      );
    } else {
      defaultPaint(context, offset);
      layer = null;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return defaultHitTestChildren(result, position: position);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final MultiChildLayoutParentData childParentData =
        child.parentData! as MultiChildLayoutParentData;
    final Offset childOffset = childParentData.offset;
    if (_transform != null) {
      transform.multiply(_transform!);
    }
    transform.translateByDouble(childOffset.dx, childOffset.dy, 0, 1);
  }
}