import 'package:pili_plus/models/common/setting_type.dart';
import 'package:pili_plus/pages/setting/models/model.dart';
import 'package:pili_plus/pages/setting/widgets/settings_highlight_flash.dart';
import 'package:flutter/material.dart';

class CommonSetting extends StatefulWidget {
  const CommonSetting({
    super.key,
    required this.settingType,
    this.showAppBar = true,
    this.highlightSettingsId,
  });

  final bool showAppBar;
  final SettingType settingType;

  /// When set (e.g. from settings search), scroll to and flash this item once.
  final String? highlightSettingsId;

  @override
  State<CommonSetting> createState() => _CommonSettingState();
}

class _CommonSettingState extends State<CommonSetting> {
  late EdgeInsets padding;
  late List<SettingsModel> settings;
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToHighlight = false;

  /// Approximate tile height for first jump when the target is off-screen.
  static const double _approxTileExtent = 72;

  void _initSetting() {
    settings = widget.settingType.settings;
  }

  @override
  void initState() {
    super.initState();
    _initSetting();
    if (widget.highlightSettingsId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight();
      });
    }
  }

  @override
  void didUpdateWidget(CommonSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settingType != oldWidget.settingType) {
      _initSetting();
      _didScrollToHighlight = false;
    }
    if (widget.highlightSettingsId != oldWidget.highlightSettingsId &&
        widget.highlightSettingsId != null) {
      _didScrollToHighlight = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToHighlight();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    padding = MediaQuery.viewPaddingOf(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlight() {
    if (_didScrollToHighlight || !mounted) return;
    final highlightId = widget.highlightSettingsId;
    if (highlightId == null) return;

    final index = settings.indexWhere((m) => m.settingsId == highlightId);
    if (index < 0) return;

    void ensureVisibleIfPossible() {
      final ctx = _highlightKey.currentContext;
      if (ctx == null || !mounted) return;
      _didScrollToHighlight = true;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    }

    final ctx = _highlightKey.currentContext;
    if (ctx != null) {
      ensureVisibleIfPossible();
      return;
    }

    // Target not laid out yet (lazy ListView): jump near index first.
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final target = (index * _approxTileExtent).clamp(0.0, max);
      _scrollController.jumpTo(target);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didScrollToHighlight) return;
      if (_highlightKey.currentContext != null) {
        ensureVisibleIfPossible();
        return;
      }
      // One more frame if layout still pending.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didScrollToHighlight) return;
        ensureVisibleIfPossible();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = widget.showAppBar;
    final highlightId = widget.highlightSettingsId;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? AppBar(title: Text(widget.settingType.title)) : null,
      body: ListView.builder(
        key: ValueKey(widget.settingType),
        controller: _scrollController,
        padding: EdgeInsets.only(
          left: showAppBar ? padding.left : 0,
          right: showAppBar ? padding.right : 0,
          bottom: padding.bottom + 100,
        ),
        itemCount: settings.length,
        itemBuilder: (context, index) {
          final model = settings[index];
          final child = model.widget;
          if (highlightId != null && model.settingsId == highlightId) {
            return SettingsHighlightFlash(
              key: _highlightKey,
              child: child,
            );
          }
          return child;
        },
      ),
    );
  }
}