import 'package:pili_plus/utils/extension/iterable_ext.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Selectable;

extension SelectableRegionStateExt on SelectableRegionState {
  void addLaunchMenuIfNeeded(
    List<ContextMenuButtonItem> buttonItems, {
    required int index,
  }) {
    if (isUncollapsed) {
      buttonItems.insertOrAdd(
        index,
        ContextMenuButtonItem(
          label: '打开',
          onPressed: () {
            onMenuPressed(
              PageUtils.launchURL,
              content: () => selectedText?.trim(),
            );
          },
        ),
      );
    }
  }

  // Patched getters from lib/scripts/selectable_region.patch; dynamic keeps analyzer green before patch applies.
  String? get selectedText => ((this as dynamic).selectable as Selectable?)
      ?.getSelectedContent()
      ?.plainText;

  bool get isUncollapsed =>
      ((this as dynamic).selectionDelegate as StaticSelectionContainerDelegate)
          .value
          .status ==
      .uncollapsed;

  void onMenuPressed(
    ValueChanged<String> callback, {
    ValueGetter<String?>? content,
  }) {
    final text = content?.call() ?? selectedText;
    hideAndClear();
    if (text != null && text.isNotEmpty) {
      callback(text);
    }
  }

  void hideAndClear() {
    hideToolbar();
    clearSelection();
  }
}
