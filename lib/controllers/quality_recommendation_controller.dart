import 'dart:async';

import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/services/quality_recommendation_service.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:get/get.dart';

typedef QualityModeReader = Object? Function();
typedef QualityModeWriter = Future<void> Function(String value);
typedef RecommendedQualityApplier = FutureOr<bool> Function(int qualityCode);

/// Owns the persistent recommendation mode and current-player recommendation.
class QualityRecommendationController {
  QualityRecommendationController({
    QualityRecommendationService? service,
    QualityModeReader? modeReader,
    QualityModeWriter? modeWriter,
    this._onApplyQuality,
    this._chipDisplayDuration = const Duration(seconds: 3),
  }) : _service = service ?? QualityRecommendationService.instance,
       _modeReader = modeReader ?? _readStoredMode,
       _modeWriter = modeWriter ?? _writeStoredMode {
    _loadSavedMode();
  }

  final QualityRecommendationService _service;
  final QualityModeReader _modeReader;
  final QualityModeWriter _modeWriter;
  final RecommendedQualityApplier? _onApplyQuality;
  final Duration _chipDisplayDuration;

  final Rx<QualityMode> currentMode = QualityMode.auto.obs;
  final Rxn<QualityRecommendation> currentRecommendation =
      Rxn<QualityRecommendation>();
  final RxList<int> availableQualities = <int>[].obs;
  final RxBool showQualityChip = false.obs;
  final RxString qualityChipMessage = ''.obs;

  Uri? _probeUri;
  int? _currentQualityCode;
  int? _previousQualityCode;
  Timer? _chipTimer;
  var _requestGeneration = 0;
  var _disposed = false;
  var _pendingAutoChip = false;

  static Object? _readStoredMode() => GStorage.setting.get(
    SettingBoxKey.videoQualityMode,
    defaultValue: QualityMode.auto.storageValue,
  );

  static Future<void> _writeStoredMode(String value) =>
      GStorage.setting.put(SettingBoxKey.videoQualityMode, value);

  void _loadSavedMode() {
    try {
      currentMode.value = QualityModeCodec.decode(_modeReader());
    } catch (_) {
      currentMode.value = QualityMode.auto;
    }
  }

  /// Persists the mode before publishing it to the UI.
  Future<void> setMode(QualityMode mode) async {
    if (_disposed || currentMode.value == mode) return;
    await _modeWriter(mode.storageValue);
    if (_disposed) return;
    currentMode.value = mode;
    if (mode != QualityMode.auto) {
      _hideChip();
    }
    if (availableQualities.isNotEmpty) {
      await updateRecommendation(
        currentQualityCode: _currentQualityCode,
        applyToPlayer: true,
      );
    }
  }

  /// Supplies the actual qn values present in the current DASH response.
  Future<QualityRecommendation?> setAvailableQualities(
    Iterable<int> qualities, {
    Uri? probeUri,
    int? currentQualityCode,
    bool applyToPlayer = false,
  }) {
    final normalized = qualities.where((code) => code > 0).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    availableQualities.assignAll(normalized);
    _probeUri = probeUri;
    _currentQualityCode = currentQualityCode;
    if (normalized.isEmpty) {
      clearRecommendation();
      return Future<QualityRecommendation?>.value();
    }
    return updateRecommendation(
      currentQualityCode: currentQualityCode,
      applyToPlayer: applyToPlayer,
    );
  }

  Future<QualityRecommendation?> updateRecommendation({
    int? currentQualityCode,
    bool applyToPlayer = false,
  }) async {
    if (_disposed || availableQualities.isEmpty) return null;
    final generation = ++_requestGeneration;
    final recommendation = await _service.recommendQuality(
      mode: currentMode.value,
      availableQualities: availableQualities.toList(growable: false),
      probeUri: _probeUri,
    );
    if (_disposed || generation != _requestGeneration) return null;

    currentRecommendation.value = recommendation;
    _previousQualityCode = currentQualityCode ?? _currentQualityCode;
    _pendingAutoChip = recommendation.isAuto;

    if (!applyToPlayer) return recommendation;
    if (recommendation.qualityCode == _previousQualityCode) {
      onPlaybackReady(recommendation.qualityCode);
      return recommendation;
    }

    final applier = _onApplyQuality;
    if (applier == null || !await applier(recommendation.qualityCode)) {
      _pendingAutoChip = false;
      return recommendation;
    }
    _currentQualityCode = recommendation.qualityCode;
    return recommendation;
  }

  /// Called after the player has opened the selected DASH stream.
  void onPlaybackReady(int? appliedQualityCode) {
    if (_disposed || appliedQualityCode == null) return;
    _currentQualityCode = appliedQualityCode;
    final recommendation = currentRecommendation.value;
    if (!_pendingAutoChip ||
        recommendation == null ||
        !recommendation.isAuto ||
        recommendation.qualityCode != appliedQualityCode) {
      return;
    }
    _pendingAutoChip = false;
    _showChip(
      previousQualityCode: _previousQualityCode,
      recommendation: recommendation,
    );
  }

  void _showChip({
    required int? previousQualityCode,
    required QualityRecommendation recommendation,
  }) {
    final previousLabel = previousQualityCode == null
        ? null
        : VideoQualityCode.getLabel(previousQualityCode);
    qualityChipMessage.value =
        previousLabel != null &&
            previousLabel != '未知' &&
            previousQualityCode != recommendation.qualityCode
        ? '自动：$previousLabel → ${recommendation.qualityLabel}'
        : '自动：${recommendation.qualityLabel}';
    showQualityChip.value = true;
    _chipTimer?.cancel();
    _chipTimer = Timer(_chipDisplayDuration, _hideChip);
  }

  void _hideChip() {
    _chipTimer?.cancel();
    _chipTimer = null;
    showQualityChip.value = false;
  }

  int get recommendedQualityCode =>
      currentRecommendation.value?.qualityCode ?? VideoQualityCode.kAuto;

  String get recommendedQualityLabel =>
      currentRecommendation.value?.qualityLabel ?? '自动';

  bool get isAutoMode => currentMode.value == QualityMode.auto;

  String? get recommendationReason => currentRecommendation.value?.reason;

  String getQualityLabel(int code) => VideoQualityCode.getLabel(code);

  List<QualityMode> get allModes => QualityMode.values;

  void clearRecommendation() {
    _requestGeneration++;
    currentRecommendation.value = null;
    availableQualities.clear();
    _probeUri = null;
    _currentQualityCode = null;
    _previousQualityCode = null;
    _pendingAutoChip = false;
    qualityChipMessage.value = '';
    _hideChip();
  }

  void forceShowChip() {
    final recommendation = currentRecommendation.value;
    if (recommendation case QualityRecommendation(isAuto: true)) {
      _showChip(
        previousQualityCode: _currentQualityCode,
        recommendation: recommendation,
      );
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requestGeneration++;
    _chipTimer?.cancel();
  }
}
