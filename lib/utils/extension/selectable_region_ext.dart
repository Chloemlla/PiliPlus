import 'package:pili_plus/utils/extension/iterable_ext.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:flutter/material.dart';

extension SelectableRegionStateExt on SelectableRegionState {
  void addLaunchMenuIfNeeded(
    List<ContextMenuButtonItem> buttonItems, {
    required int index,
  }) {
    try {
      if (selectionEndpoints.first != selectionEndpoints[1]) {
        buttonItems.insertOrAdd(
          index,
          ContextMenuButtonItem(
            label: '打开',
            onPressed: () {
              final text = (this as dynamic).selectable
                  ?.getSelectedContent()
                  ?.plainText
                  .trim();
              hideToolbar();
              clearSelection();
              if (text != null && text.isNotEmpty) {
                PageUtils.launchURL(text);
              }
            },
          ),
        );
      }
    } catch (_) {}
  }
}
