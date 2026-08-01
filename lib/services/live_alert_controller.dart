import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/http/follow.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/models_new/follow/list.dart';
import 'package:pili_plus/services/account_service.dart';
import 'package:pili_plus/services/live_alert_data_source.dart';
import 'package:pili_plus/services/live_alert_service.dart';
import 'package:pili_plus/utils/accounts.dart';

enum LiveAlertResolveResult {
  resolved,
  notLoggedIn,
  invalidMid,
  upNotFound,
  accountChanged,
}

enum LiveAlertSaveResult {
  saved,
  notLoggedIn,
  invalidMid,
  keywordRequired,
  keywordTooLong,
  upNotFound,
  duplicate,
  accountChanged,
  failed,
}

class LiveAlertController extends GetxController with AccountMixin {
  static const int _followingsPageSize = 50;

  LiveAlertService get _service => LiveAlertService.instance;

  final RxBool isLoading = true.obs;
  final RxBool isLoggedIn = Accounts.main.isLogin.obs;
  final RxList<LiveKeywordRule> rules = <LiveKeywordRule>[].obs;

  final RxBool isLoadingFollowings = false.obs;
  final RxBool hasMoreFollowings = true.obs;
  final RxnString followingsError = RxnString();
  final RxList<FollowItemModel> followings = <FollowItemModel>[].obs;

  final selectedMid = RxnInt();
  final selectedUpName = ''.obs;
  final selectedAvatarUrl = ''.obs;
  final keywordController = TextEditingController();
  final manualMidController = TextEditingController();
  final selectedMatchTarget = MatchTarget.titleOnly.obs;
  final isRuleEnabled = true.obs;
  final editingRule = Rxn<LiveKeywordRule>();
  final RxBool isResolvingMid = false.obs;
  final RxBool isSaving = false.obs;

  int _nextFollowingsPage = 1;
  int _followingsRequestToken = 0;

  bool get isEditing => editingRule.value != null;

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _service.init();
      await refreshCurrentAccount();
    } on Exception {
      isLoading.value = false;
      followingsError.value = '直播提醒初始化失败';
    }
  }

  @override
  void onChangeAccount(bool isLogin) {
    isLoggedIn.value = isLogin && Accounts.main.isLogin;
    clearForm();
    unawaited(refreshCurrentAccount());
  }

  Future<void> refreshCurrentAccount() async {
    isLoggedIn.value = Accounts.main.isLogin;
    if (!isLoggedIn.value) {
      rules.clear();
      followings.clear();
      hasMoreFollowings.value = false;
      isLoading.value = false;
      return;
    }

    try {
      await _service.activateCurrentAccount();
      await Future.wait([
        loadRules(),
        loadFollowings(),
      ]);
    } on Exception {
      isLoading.value = false;
      followingsError.value = '直播提醒数据刷新失败';
    }
  }

  Future<void> loadRules() async {
    final accountMid = _service.currentAccountMid;
    isLoading.value = true;
    try {
      await _service.activateCurrentAccount();
      if (accountMid == _service.currentAccountMid) {
        rules.value = _service.getAllRules();
      }
    } on Exception {
      return;
    } finally {
      if (accountMid == _service.currentAccountMid) {
        isLoading.value = false;
      }
    }
  }

  Future<void> loadFollowings({bool reset = true}) async {
    if (!reset && isLoadingFollowings.value) return;
    final accountMid = _service.currentAccountMid;
    if (accountMid <= 0) {
      followings.clear();
      hasMoreFollowings.value = false;
      return;
    }

    final requestToken = ++_followingsRequestToken;
    if (reset) {
      _nextFollowingsPage = 1;
      followings.clear();
      hasMoreFollowings.value = true;
    }
    isLoadingFollowings.value = true;
    followingsError.value = null;

    try {
      final result = await FollowHttp.followings(
        vmid: accountMid,
        pn: _nextFollowingsPage,
        ps: _followingsPageSize,
      );
      if (requestToken != _followingsRequestToken ||
          accountMid != _service.currentAccountMid) {
        return;
      }

      if (result case Success(:final response)) {
        final incoming = response.list ?? const <FollowItemModel>[];
        final byMid = <int, FollowItemModel>{
          for (final item in followings) item.mid: item,
          for (final item in incoming) item.mid: item,
        };
        followings.value = byMid.values.toList();
        _nextFollowingsPage++;
        hasMoreFollowings.value = response.total != null
            ? followings.length < response.total!
            : incoming.length == _followingsPageSize;
      } else {
        followingsError.value = result.toString();
        hasMoreFollowings.value = false;
      }
    } on Exception {
      if (requestToken == _followingsRequestToken) {
        followingsError.value = '关注列表加载失败';
        hasMoreFollowings.value = false;
      }
    } finally {
      if (requestToken == _followingsRequestToken) {
        isLoadingFollowings.value = false;
      }
    }
  }

  Future<void> loadMoreFollowings() => loadFollowings(reset: false);

  void selectFollowing(FollowItemModel following) {
    _selectUp(
      mid: following.mid,
      upName: following.uname ?? '',
      avatarUrl: following.face ?? '',
    );
  }

  void _selectUp({
    required int mid,
    required String upName,
    required String avatarUrl,
  }) {
    selectedMid.value = mid;
    selectedUpName.value = upName.trim();
    selectedAvatarUrl.value = avatarUrl.trim();
    manualMidController.text = mid.toString();
  }

  Future<LiveAlertResolveResult> resolveManualMid() async {
    if (!_service.hasActiveAccount) return LiveAlertResolveResult.notLoggedIn;
    final mid = int.tryParse(manualMidController.text.trim());
    if (mid == null || mid <= 0) return LiveAlertResolveResult.invalidMid;

    final accountMid = _service.currentAccountMid;
    isResolvingMid.value = true;
    try {
      final LiveAlertRoomSnapshot? snapshot = await _service.resolveUp(mid);
      if (accountMid != _service.currentAccountMid) {
        return LiveAlertResolveResult.accountChanged;
      }
      if (snapshot == null || snapshot.upName.isEmpty) {
        return LiveAlertResolveResult.upNotFound;
      }
      _selectUp(
        mid: snapshot.mid,
        upName: snapshot.upName,
        avatarUrl: snapshot.avatarUrl,
      );
      return LiveAlertResolveResult.resolved;
    } finally {
      if (accountMid == _service.currentAccountMid) {
        isResolvingMid.value = false;
      }
    }
  }

  void setMatchTarget(MatchTarget target) {
    selectedMatchTarget.value = target;
  }

  void setEnabled(bool enabled) {
    isRuleEnabled.value = enabled;
  }

  void beginCreate() => clearForm();

  void beginEdit(LiveKeywordRule rule) {
    editingRule.value = rule;
    selectedMid.value = rule.mid;
    selectedUpName.value = rule.upName;
    selectedAvatarUrl.value = '';
    manualMidController.text = rule.mid.toString();
    keywordController.text = rule.keyword;
    selectedMatchTarget.value = rule.matchTarget;
    isRuleEnabled.value = rule.enabled;
  }

  void clearForm() {
    editingRule.value = null;
    selectedMid.value = null;
    selectedUpName.value = '';
    selectedAvatarUrl.value = '';
    manualMidController.clear();
    keywordController.clear();
    selectedMatchTarget.value = MatchTarget.titleOnly;
    isRuleEnabled.value = true;
    isResolvingMid.value = false;
    isSaving.value = false;
  }

  Future<LiveAlertSaveResult> saveRule() async {
    if (!_service.hasActiveAccount) return LiveAlertSaveResult.notLoggedIn;
    final keyword = keywordController.text.trim();
    if (keyword.isEmpty) return LiveAlertSaveResult.keywordRequired;
    if (keyword.length > 50) return LiveAlertSaveResult.keywordTooLong;

    final enteredMid = int.tryParse(manualMidController.text.trim());
    if (enteredMid == null || enteredMid <= 0) {
      return LiveAlertSaveResult.invalidMid;
    }
    if (selectedMid.value != enteredMid || selectedUpName.value.isEmpty) {
      final resolveResult = await resolveManualMid();
      switch (resolveResult) {
        case LiveAlertResolveResult.resolved:
          break;
        case LiveAlertResolveResult.notLoggedIn:
          return LiveAlertSaveResult.notLoggedIn;
        case LiveAlertResolveResult.invalidMid:
          return LiveAlertSaveResult.invalidMid;
        case LiveAlertResolveResult.upNotFound:
          return LiveAlertSaveResult.upNotFound;
        case LiveAlertResolveResult.accountChanged:
          return LiveAlertSaveResult.accountChanged;
      }
    }

    final mid = selectedMid.value;
    if (mid == null || mid <= 0) return LiveAlertSaveResult.invalidMid;
    final editing = editingRule.value;
    final normalizedKeyword = keyword.toLowerCase();
    final isDuplicate = rules.any(
      (rule) =>
          rule.id != editing?.id &&
          rule.mid == mid &&
          rule.keyword.trim().toLowerCase() == normalizedKeyword &&
          rule.matchTarget == selectedMatchTarget.value,
    );
    if (isDuplicate) return LiveAlertSaveResult.duplicate;

    final accountMid = _service.currentAccountMid;
    isSaving.value = true;
    try {
      final midChanged = editing != null && editing.mid != mid;
      final rule = LiveKeywordRule(
        id: editing?.id ?? _service.generateRuleId(),
        mid: mid,
        upName: selectedUpName.value,
        keyword: keyword,
        matchTargetIndex: selectedMatchTarget.value.index,
        enabled: isRuleEnabled.value,
        createdAt:
            editing?.createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        lastNotifiedAt: midChanged ? 0 : editing?.lastNotifiedAt ?? 0,
        accountMid: accountMid,
      );
      final saved = editing == null
          ? await _service.addRule(rule)
          : await _service.updateRule(rule);
      if (accountMid != _service.currentAccountMid) {
        return LiveAlertSaveResult.accountChanged;
      }
      if (!saved) return LiveAlertSaveResult.failed;
      await loadRules();
      return LiveAlertSaveResult.saved;
    } on Exception {
      return LiveAlertSaveResult.failed;
    } finally {
      if (accountMid == _service.currentAccountMid) {
        isSaving.value = false;
      }
    }
  }

  Future<bool> deleteRule(String ruleId) async {
    try {
      final deleted = await _service.deleteRule(ruleId);
      if (deleted) await loadRules();
      return deleted;
    } on Exception {
      return false;
    }
  }

  Future<bool> toggleRule(String ruleId) async {
    try {
      final toggled = await _service.toggleRule(ruleId);
      if (toggled) await loadRules();
      return toggled;
    } on Exception {
      return false;
    }
  }

  String getMatchTargetLabel(MatchTarget target) => switch (target) {
    MatchTarget.titleOnly => '仅标题',
    MatchTarget.areaOnly => '仅分区',
    MatchTarget.both => '标题或分区',
  };

  @override
  void onClose() {
    keywordController.dispose();
    manualMidController.dispose();
    super.onClose();
  }
}
