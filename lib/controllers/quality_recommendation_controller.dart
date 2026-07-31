import 'package:get/get.dart';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/services/quality_recommendation_service.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

class QualityRecommendationController extends GetxController {
  final _service = QualityRecommendationService.instance;

  /// Current quality mode
  final Rx<QualityMode> currentMode = QualityMode.auto.obs;

  /// Current recommended quality
  final Rxn<QualityRecommendation> currentRecommendation = Rxn<QualityRecommendation>();

  /// Available quality options for current video
  final RxList<int> availableQualities = <int>[].obs;

  /// Whether to show quality chip overlay
  final RxBool showQualityChip = false.obs;

  /// Last update time for quality chip
  DateTime? _lastChipShowTime;
  static const Duration _chipDisplayDuration = Duration(seconds: 3);

  @override
  void onInit() {
    super.onInit();
    _loadSavedMode();
  }

  void _loadSavedMode() {
    final savedIndex = GStorage.setting.get(
      SettingBoxKey.videoQualityMode,
      defaultValue: QualityMode.auto.index,
    );
    currentMode.value = QualityMode.values[savedIndex as int];
  }

  /// Save quality mode preference
  Future<void> _saveMode(QualityMode mode) async {
    await GStorage.setting.put(SettingBoxKey.videoQualityMode, mode.index);
  }

  /// Set quality mode
  void setMode(QualityMode mode) {
    currentMode.value = mode;
    _saveMode(mode);
    // Recalculate recommendation if available qualities are set
    if (availableQualities.isNotEmpty) {
      updateRecommendation();
    }
  }

  /// Set available quality options for current video
  void setAvailableQualities(List<int> qualities) {
    availableQualities.value = qualities;
    updateRecommendation();
  }

  /// Update quality recommendation
  Future<void> updateRecommendation() async {
    if (availableQualities.isEmpty) return;

    final recommendation = await _service.recommendQuality(
      mode: currentMode.value,
      availableQualities: availableQualities,
    );

    currentRecommendation.value = recommendation;

    // Show quality chip for auto mode
    if (recommendation.isAuto) {
      _showChipTemporarily();
    }
  }

  /// Show quality chip temporarily (3 seconds)
  void _showChipTemporarily() {
    showQualityChip.value = true;
    _lastChipShowTime = DateTime.now();

    // Hide after duration
    Future.delayed(_chipDisplayDuration, () {
      if (_lastChipShowTime != null &&
          DateTime.now().difference(_lastChipShowTime!) >= _chipDisplayDuration) {
        showQualityChip.value = false;
      }
    });
  }

  /// Get recommended quality code for current video
  int get recommendedQualityCode {
    return currentRecommendation.value?.qualityCode ?? VideoQualityCode.kAuto;
  }

  /// Get recommended quality label
  String get recommendedQualityLabel {
    return currentRecommendation.value?.qualityLabel ?? '自动';
  }

  /// Check if current recommendation is from auto mode
  bool get isAutoMode => currentMode.value == QualityMode.auto;

  /// Get reason for current recommendation
  String? get recommendationReason {
    return currentRecommendation.value?.reason;
  }

  /// Clear current recommendation (when video changes)
  void clearRecommendation() {
    currentRecommendation.value = null;
    availableQualities.clear();
    showQualityChip.value = false;
  }

  /// Get quality label for a code
  String getQualityLabel(int code) {
    return VideoQualityCode.getLabel(code);
  }

  /// Get all quality modes
  List<QualityMode> get allModes => QualityMode.values;

  /// Force show quality chip
  void forceShowChip() {
    _showChipTemporarily();
  }
}
