import 'package:pili_plus/common/widgets/flutter/list_tile.dart';
import 'package:pili_plus/common/widgets/loading_widget/http_error.dart';
import 'package:pili_plus/common/widgets/view_sliver_safe_area.dart';
import 'package:pili_plus/models/common/setting_type.dart';
import 'package:pili_plus/pages/search/controller.dart' show DebounceStreamState;
import 'package:pili_plus/pages/setting/common_setting.dart';
import 'package:pili_plus/pages/setting/models/model.dart';
import 'package:pili_plus/utils/grid.dart';
import 'package:pili_plus/utils/waterfall.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart'
    hide SliverWaterfallFlowDelegateWithMaxCrossAxisExtent;

class _SearchableSetting {
  const _SearchableSetting({
    required this.type,
    required this.model,
  });

  final SettingType type;
  final SettingsModel model;
}

class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState
    extends DebounceStreamState<SettingsSearchPage, String> {
  final _textEditingController = TextEditingController();
  final RxList<_SearchableSetting> _list = <_SearchableSetting>[].obs;

  static const _searchableTypes = <SettingType>[
    SettingType.privacySetting,
    SettingType.recommendSetting,
    SettingType.videoSetting,
    SettingType.playSetting,
    SettingType.styleSetting,
    SettingType.extraSetting,
  ];

  late final List<_SearchableSetting> _settings = [
    for (final type in _searchableTypes)
      for (final model in type.settings)
        _SearchableSetting(type: type, model: model),
  ];

  @override
  void onValueChanged(String value) {
    if (value.isEmpty) {
      _list.clear();
    } else {
      value = value.toLowerCase();
      _list.value = _settings
          .where(
            (item) =>
                item.model.effectiveTitle.toLowerCase().contains(value) ||
                item.model.effectiveSubtitle?.toLowerCase().contains(value) ==
                    true,
          )
          .toList();
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _openSetting(_SearchableSetting entry) {
    Get.to(
      () => CommonSetting(
        settingType: entry.type,
        highlightSettingsId: entry.model.settingsId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium!;
    final subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              if (_textEditingController.text.isNotEmpty) {
                _textEditingController.clear();
                _list.clear();
              } else {
                Get.back();
              }
            },
            icon: const Icon(Icons.clear),
          ),
          const SizedBox(width: 10),
        ],
        title: TextField(
          autofocus: true,
          controller: _textEditingController,
          textAlignVertical: TextAlignVertical.center,
          onChanged: ctr!.add,
          decoration: const InputDecoration(
            isDense: true,
            hintText: '搜索',
            visualDensity: .standard,
            border: InputBorder.none,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          ViewSliverSafeArea(
            sliver: Obx(
              () => _list.isEmpty
                  ? const HttpError()
                  : SliverWaterfallFlow(
                      gridDelegate:
                          SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: Grid.smallCardWidth * 2,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (_, index) {
                          final entry = _list[index];
                          final model = entry.model;
                          final subtitle = model.effectiveSubtitle;
                          return ListTile(
                            leading: model.leading,
                            title: Text(
                              model.effectiveTitle,
                              style: titleStyle,
                            ),
                            subtitle: subtitle == null
                                ? Text(entry.type.title, style: subTitleStyle)
                                : Text(
                                    '${entry.type.title} · $subtitle',
                                    style: subTitleStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: Icon(
                              Icons.my_location_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () => _openSetting(entry),
                          );
                        },
                        childCount: _list.length,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}