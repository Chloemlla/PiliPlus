import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/services/live_alert_service.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/follow.dart';
import 'package:pili_plus/models_new/follow/data.dart';

class LiveAlertController extends GetxController {
  LiveAlertService get _service => LiveAlertService.instance;

  final RxBool isLoading = true.obs;
  final RxList<LiveKeywordRule> rules = <LiveKeywordRule>[].obs;

  // For following list
  final RxBool isLoadingFollowings = false.obs;
  final RxList<Following> followings = <Following>[].obs;

  // Form state
  final selectedMid = RxnInt();
  final selectedUpName = ''.obs;
  final keywordController = TextEditingController();
  final selectedMatchTarget = MatchTarget.titleOnly.obs;
  final isRuleEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    _initService();
  }

  Future<void> _initService() async {
    await _service.init();
    await loadRules();
    await loadFollowings();
  }

  Future<void> loadRules() async {
    isLoading.value = true;
    try {
      rules.value = _service.getAllRules();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadFollowings() async {
    isLoadingFollowings.value = true;
    try {
      // Load first page of followings
      final result = await FollowHttp.followings(ps: 50);
      if (result case Success(:final response)) {
        followings.value = response.list ?? [];
      }
    } finally {
      isLoadingFollowings.value = false;
    }
  }

  void selectUp(int mid, String uname) {
    selectedMid.value = mid;
    selectedUpName.value = uname;
  }

  void setMatchTarget(MatchTarget target) {
    selectedMatchTarget.value = target;
  }

  void setEnabled(bool enabled) {
    isRuleEnabled.value = enabled;
  }

  void clearForm() {
    selectedMid.value = null;
    selectedUpName.value = '';
    keywordController.clear();
    selectedMatchTarget.value = MatchTarget.titleOnly;
    isRuleEnabled.value = true;
  }

  Future<bool> addRule() async {
    if (selectedMid.value == null || keywordController.text.isEmpty) {
      return false;
    }

    final rule = LiveKeywordRule(
      id: _service.generateRuleId(),
      mid: selectedMid.value!,
      upName: selectedUpName.value,
      keyword: keywordController.text.trim(),
      matchTargetIndex: selectedMatchTarget.value.index,
      enabled: isRuleEnabled.value,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    await _service.addRule(rule);
    await loadRules();
    clearForm();
    return true;
  }

  Future<void> updateRule(LiveKeywordRule rule) async {
    await _service.updateRule(rule);
    await loadRules();
  }

  Future<void> deleteRule(String ruleId) async {
    await _service.deleteRule(ruleId);
    await loadRules();
  }

  Future<void> toggleRule(String ruleId) async {
    await _service.toggleRule(ruleId);
    await loadRules();
  }

  void startPolling() {
    _service.startPolling();
  }

  void stopPolling() {
    _service.stopPolling();
  }

  String getMatchTargetLabel(MatchTarget target) {
    switch (target) {
      case MatchTarget.titleOnly:
        return '仅标题';
      case MatchTarget.areaOnly:
        return '仅分区';
      case MatchTarget.both:
        return '标题和分区';
    }
  }

  @override
  void onClose() {
    keywordController.dispose();
    super.onClose();
  }
}
