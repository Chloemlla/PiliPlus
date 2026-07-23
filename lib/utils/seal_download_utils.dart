import 'dart:async';
import 'dart:convert' show jsonEncode;
import 'dart:io' show Platform;
import 'dart:math' show min;

import 'package:pili_plus/common/style.dart';
import 'package:pili_plus/http/constants.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/sponsor_block.dart';
import 'package:pili_plus/models/common/sponsor_block/segment_type.dart';
import 'package:pili_plus/models/common/sponsor_block/strip_removal_report.dart';
import 'package:pili_plus/models_new/sponsor_block/segment_item.dart';
import 'package:pili_plus/models_new/video/video_detail/page.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/pages/video/introduction/ugc/controller.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/extension/context_ext.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/segment_strip_math.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// Delegates video/audio downloads to Seal via the L3 external download protocol.
///
/// The entire lifecycle is presented by a compact self-owned status panel
/// (waiting → accepted → completed/failed/canceled), instead of bare toasts.
abstract final class SealDownloadUtils {
  static const _channel = MethodChannel('pili_plus/seal_download');
  static const releasesUrl = 'https://github.com/Chloemlla/Seal/releases';
  static const _panelTag = 'seal_download_panel';

  static bool _listening = false;
  static final Set<String> _handledEvents = <String>{};
  static final Map<String, _SealSession> _sessions = <String, _SealSession>{};
  static String? _activeRequestId;

  static bool get isSupported => Platform.isAndroid;

  /// Wire MethodChannel callbacks as early as possible on Android.
  static void ensureListening() {
    if (!isSupported) return;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onMethodCall);
      if (kDebugMode) {
        debugPrint('SealDownloadUtils: listening for DOWNLOAD_STATUS');
      }
    }
    unawaited(
      _channel.invokeMethod<void>('readyForStatus').catchError((Object _) {}),
    );
  }

  static Future<void> downloadVideo(VideoDetailController ctr) {
    return promptDownload(ctr, extractAudio: false);
  }

  static Future<void> downloadAudio(VideoDetailController ctr) {
    return promptDownload(ctr, extractAudio: true);
  }

  /// Force strip using 空降助手 marks (multi-P supported).
  static Future<void> downloadVideoStripMarked(VideoDetailController ctr) {
    return promptDownload(ctr, extractAudio: false, forceStrip: true);
  }

  /// Multi-P UGC: show 当前P / 选择分P… / 全部; otherwise delegate immediately.
  ///
  /// Strip uses **空降助手** segments per cid (`SponsorBlock.getSkipSegments`).
  /// Multi-P with strip launches one Seal task per part (keep_sections is per-cid).
  static Future<void> promptDownload(
    VideoDetailController ctr, {
    required bool extractAudio,
    bool forceStrip = false,
  }) async {
    if (!isSupported) return;
    final pages = _ugcMultiPages(ctr);
    if (pages == null || pages.length <= 1) {
      await _download(ctr, extractAudio: extractAudio, forceStrip: forceStrip);
      return;
    }

    final choice = await _showMultiPChoiceSheet(
      extractAudio: extractAudio,
      pageCount: pages.length,
      forceStrip: forceStrip,
    );
    if (choice == null) return;

    Future<void> launchParts(List<int> indices) async {
      final wantStrip = forceStrip || Pref.stripMarkedSegmentsEnabled;
      if (wantStrip) {
        await _downloadPartsWithStrip(
          ctr,
          extractAudio: extractAudio,
          pages: pages,
          indices: indices,
          forceStrip: forceStrip,
        );
        return;
      }
      final urls = [
        for (final i in indices) pageUrlForPart(ctr.bvid, pages[i], i),
      ];
      await _download(
        ctr,
        extractAudio: extractAudio,
        urls: urls,
        itemCount: urls.length,
      );
    }

    switch (choice) {
      case _MultiPChoice.current:
        final currentIndex = pages.indexWhere((e) => e.cid == ctr.cid.value);
        if (currentIndex >= 0) {
          await launchParts([currentIndex]);
        } else {
          await _download(
            ctr,
            extractAudio: extractAudio,
            forceStrip: forceStrip,
          );
        }
      case _MultiPChoice.all:
        await launchParts([for (var i = 0; i < pages.length; i++) i]);
      case _MultiPChoice.select:
        final selectedIndices = await _pickPartIndices(
          ctr: ctr,
          parts: pages,
          extractAudio: extractAudio,
        );
        if (selectedIndices == null || selectedIndices.isEmpty) return;
        await launchParts(selectedIndices);
    }
  }

  static Future<void> _download(
    VideoDetailController ctr, {
    required bool extractAudio,
    List<String>? urls,
    int? itemCount,
    bool forceStrip = false,
    int? stripCid,
    int? stripDurationMs,
    String? stripPageLabel,
    Set<String>? stripCategories,
    bool askStripCategories = true,
  }) async {
    ensureListening();
    final List<String> resolvedUrls;
    if (urls == null || urls.isEmpty) {
      final single = pageUrlOf(ctr);
      resolvedUrls = (single != null && single.isNotEmpty)
          ? <String>[single]
          : const <String>[];
    } else {
      resolvedUrls = urls
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false);
    }
    if (resolvedUrls.isEmpty) {
      await _showErrorPanel(
        title: '无法委托下载',
        message: '无法构造视频链接',
      );
      return;
    }

    final primaryUrl = resolvedUrls.first;
    final count = itemCount ?? resolvedUrls.length;

    final wantStrip = forceStrip || Pref.stripMarkedSegmentsEnabled;
    StripRemovalReport? stripReport;
    String? keepSectionsJson;
    var stripSegments = false;
    if (wantStrip && count == 1) {
      final prepared = await _prepareStripPlan(
        ctr,
        cidOverride: stripCid,
        durationMsOverride: stripDurationMs,
        pageLabel: stripPageLabel,
        categories: stripCategories,
        askCategories: askStripCategories,
      );
      if (prepared != null) {
        switch (prepared) {
          case _StripPrepareOk(:final report, :final keepJson):
            stripReport = report;
            keepSectionsJson = keepJson;
            stripSegments = true;
          case _StripPrepareSkip(:final message):
            SmartDialog.showToast(message);
          case _StripPrepareFail(:final message):
            if (forceStrip) {
              await _showErrorPanel(title: '无法去除空降助手标记', message: message);
              return;
            }
            SmartDialog.showToast(message);
        }
      }
    } else if (wantStrip && count > 1) {
      SmartDialog.showToast('空降助手去除标记仅支持按分 P 独立处理，已按普通下载处理');
    }

    // Cookie account selection (after multi-P, before launch).
    final cookieChoice = await _resolveCookiePayload();
    if (cookieChoice == _CookieChoice.canceled) {
      return;
    }

    final requestId =
        'piliplus-${extractAudio ? 'audio' : 'video'}-${DateTime.now().microsecondsSinceEpoch}';
    final title = _titleOf(ctr);
    final session = _SealSession(
      requestId: requestId,
      extractAudio: extractAudio,
      pageUrl: primaryUrl,
      mediaTitle: title,
      autoStart: Pref.sealAutoStart,
      itemCount: count,
      stripReport: stripReport,
    );
    _sessions[requestId] = session;
    _activeRequestId = requestId;
    // Skip launching UX: go straight to wait-confirm / auto-queue panel.
    final initialBusy = Pref.sealAutoStart
        ? SealPanelPhase.waitingAuto
        : SealPanelPhase.waitingUi;
    session.phase.value = initialBusy;
    final stripHint = stripSegments && stripReport != null
        ? '正在去除空降助手标记 ${stripReport.removedCount} 段…'
        : null;
    session.message.value = stripHint ??
        (Pref.sealAutoStart
            ? (count > 1
                  ? '已委托 Seal（$count 项），正在自动入队…'
                  : '已委托 Seal，正在自动入队…')
            : (count > 1
                  ? '已打开 Seal（$count 项），请在 Seal 中确认下载'
                  : '已打开 Seal，请在 Seal 中确认下载'));
    // Non-blocking: must not await SmartDialog dismiss Future (R1).
    unawaited(_showOrUpdatePanel(session));
    if (stripReport != null) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (session.phase.value.isBusy ||
            session.phase.value == SealPanelPhase.completed) {
          _showStripReportSheet(stripReport!);
        }
      }));
    }

    try {
      final args = <String, dynamic>{
        'url': primaryUrl,
        'urls': resolvedUrls,
        'extractAudio': extractAudio,
        'autoStart': Pref.sealAutoStart,
        'openUi': true,
        'requestId': requestId,
      };
      if (stripSegments && keepSectionsJson != null) {
        args['stripSegments'] = true;
        args['keepSections'] = keepSectionsJson;
      }
      if (cookieChoice is _CookieChoiceUse) {
        args['cookiesFormat'] = 'json_map';
        args['cookies'] = cookieChoice.cookiesJson;
        args['cookiesMid'] = cookieChoice.mid;
        args['cookiesDomainHint'] = '.bilibili.com';
        args['useCookies'] = true;
        // Soft: Seal may ignore cookies if accept-external is off.
        args['cookiesRequired'] = false;
        if (kDebugMode) {
          // Never print cookie values — mid + size only.
          debugPrint(
            'SealDownload cookie mid=${cookieChoice.mid} '
            'keys=${cookieChoice.keyCount} bytes=${cookieChoice.cookiesJson.length}',
          );
        }
      }
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'delegateDownload',
        args,
      );
      if (result == null) {
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: '未收到 Seal 启动结果',
        );
        return;
      }
      final status = SealDownloadStatus.fromMap(result);
      if (status.status == 'launched') {
        // Already showing waitingUi/waitingAuto; only refresh message if needed.
        if (session.phase.value != SealPanelPhase.accepted &&
            !session.phase.value.isTerminal) {
          session.phase.value = Pref.sealAutoStart
              ? SealPanelPhase.waitingAuto
              : SealPanelPhase.waitingUi;
          session.message.value = Pref.sealAutoStart
              ? (count > 1
                    ? '已委托 Seal（$count 项），正在自动入队…'
                    : '已委托 Seal，正在自动入队…')
              : (count > 1
                    ? '已打开 Seal（$count 项），请在 Seal 中确认下载'
                    : '已打开 Seal，请在 Seal 中确认下载');
          unawaited(_showOrUpdatePanel(session));
        }
      } else {
        await _applyStatusToSession(session, status);
      }
    } on PlatformException catch (error) {
      if (error.code == 'not_installed') {
        session.phase.value = SealPanelPhase.notInstalled;
        session.message.value = '请先安装 Seal 后再下载';
        unawaited(_showOrUpdatePanel(session));
        return;
      }
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: error.message ?? '委托 Seal 失败',
      );
    } catch (error) {
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: '委托 Seal 失败：$error',
      );
    }
  }

  /// Same-bvid multi-page list when UGC and pages.length > 1; bangumi/ep excluded.
  static List<Part>? _ugcMultiPages(VideoDetailController ctr) {
    if (ctr.isFileSource || !ctr.isUgc || ctr.epId != null) return null;
    try {
      final ugc = Get.find<UgcIntroController>(tag: ctr.heroTag);
      final pages = ugc.videoDetail.value.pages;
      if (pages == null || pages.length <= 1) return null;
      return pages;
    } catch (_) {
      return null;
    }
  }

  /// Build strip plan from **空降助手** segments for one bvid+cid.
  ///
  /// Data source is always [SponsorBlock.getSkipSegments] (空降助手 API), not
  /// Seal built-in SponsorBlock and not the playback-only filtered segment list.
  static Future<_StripPrepareResult?> _prepareStripPlan(
    VideoDetailController ctr, {
    int? cidOverride,
    int? durationMsOverride,
    String? pageLabel,
    Set<String>? categories,
    bool askCategories = true,
    bool showLoading = true,
  }) async {
    final bvid = ctr.bvid;
    final cid = cidOverride ?? ctr.cid.value;
    if (bvid.isEmpty || cid == 0) {
      return const _StripPrepareFail('无法解析视频标识');
    }

    final durationMs = durationMsOverride ?? _resolveDurationMs(ctr);
    if (durationMs == null || durationMs <= 0) {
      return const _StripPrepareFail('视频时长未知，无法去除空降助手标记片段');
    }

    var cats = categories ?? Pref.stripSegmentCategories;
    if (cats.isEmpty) {
      cats = const {'sponsor', 'selfpromo'};
    }
    cats = {...cats}..remove('poi_highlight');

    if (askCategories && Pref.stripAlwaysAskCategories) {
      final picked = await _pickStripCategories(cats);
      if (picked == null) {
        return const _StripPrepareSkip('已取消去除标记片段');
      }
      cats = picked;
      if (cats.isEmpty) {
        return const _StripPrepareSkip('未选择剥离类别，已按普通下载处理');
      }
    }

    if (showLoading) {
      SmartDialog.showLoading(msg: '获取空降助手标记…');
    }
    LoadingState<List<SegmentItemModel>> state;
    try {
      // 空降助手 / BilibiliSponsorBlock — authoritative mark source for strip.
      state = await SponsorBlock.getSkipSegments(bvid: bvid, cid: cid);
    } finally {
      if (showLoading) {
        SmartDialog.dismiss();
      }
    }

    if (state is! Success<List<SegmentItemModel>>) {
      final msg = state is Error ? (state.errMsg ?? '获取标记失败') : '获取标记失败';
      return _StripPrepareSkip('空降助手无可用标记（$msg），已按普通下载处理');
    }

    final items = state.response;
    if (items.isEmpty) {
      return const _StripPrepareSkip('空降助手无标记广告片段，已按普通下载处理');
    }

    final inputs = <SegmentStripInput>[
      for (final item in items)
        SegmentStripInput(
          category: item.category,
          startMs: item.segment.isNotEmpty ? item.segment[0] : 0,
          endMs: item.segment.length > 1 ? item.segment[1] : 0,
          uuid: item.uuid.isEmpty ? null : item.uuid,
          source: item.uuid.isEmpty ? 'pgc' : '空降助手',
        ),
    ];

    var effectiveDuration = durationMs;
    for (final item in items) {
      final vd = item.videoDuration;
      if (vd != null && vd > effectiveDuration) {
        effectiveDuration = vd.round();
      }
    }

    final plan = SegmentStripMath.plan(
      segments: inputs,
      durationMs: effectiveDuration,
      categories: cats,
      minMs: Pref.stripMinSegmentMs,
    );

    if (plan.failure == SegmentStripFailure.durationUnknown) {
      return const _StripPrepareFail('视频时长未知，无法去除空降助手标记片段');
    }
    if (plan.failure == SegmentStripFailure.fullCover ||
        plan.failure == SegmentStripFailure.emptyKeep) {
      return const _StripPrepareFail('空降助手标记覆盖全片，无法剥离（无剩余正片）');
    }
    if (!plan.hasRemovals) {
      return const _StripPrepareSkip('空降助手无标记广告片段，已按普通下载处理');
    }
    if (!plan.shouldStrip) {
      return const _StripPrepareSkip('空降助手无可剥离片段，已按普通下载处理');
    }

    final report = StripRemovalReport.fromPlan(
      bvid: bvid,
      cid: cid,
      plan: plan,
      pageLabel: pageLabel,
    );
    final keepJson = jsonEncode(report.keepSectionsSeconds());
    return _StripPrepareOk(report: report, keepJson: keepJson);
  }

  /// Multi-P strip: one 空降助手 plan + Seal task per selected part.
  static Future<void> _downloadPartsWithStrip(
    VideoDetailController ctr, {
    required bool extractAudio,
    required List<Part> pages,
    required List<int> indices,
    bool forceStrip = false,
  }) async {
    if (indices.isEmpty) return;
    if (indices.length == 1) {
      final i = indices.first;
      final part = pages[i];
      final cid = part.cid ?? 0;
      final url = pageUrlForPart(ctr.bvid, part, i);
      final durSec = part.duration;
      await _download(
        ctr,
        extractAudio: extractAudio,
        urls: [url],
        forceStrip: forceStrip,
        stripCid: cid == 0 ? null : cid,
        stripDurationMs: (durSec != null && durSec > 0) ? durSec * 1000 : null,
        stripPageLabel: _partLabel(part, i),
      );
      return;
    }

    var categories = Pref.stripSegmentCategories;
    if (categories.isEmpty) {
      categories = const {'sponsor', 'selfpromo'};
    }
    categories = {...categories}..remove('poi_highlight');
    if (Pref.stripAlwaysAskCategories) {
      final picked = await _pickStripCategories(categories);
      if (picked == null) {
        SmartDialog.showToast('已取消去除标记片段');
        return;
      }
      categories = picked;
      if (categories.isEmpty) {
        final urls = [
          for (final i in indices) pageUrlForPart(ctr.bvid, pages[i], i),
        ];
        await _download(
          ctr,
          extractAudio: extractAudio,
          urls: urls,
          itemCount: urls.length,
        );
        return;
      }
    }

    final cookieChoice = await _resolveCookiePayload();
    if (cookieChoice == _CookieChoice.canceled) return;

    final reports = <StripRemovalReport>[];
    var launched = 0;
    var stripped = 0;
    var plain = 0;
    var failed = 0;

    SmartDialog.showLoading(msg: '按分 P 读取空降助手标记…');
    try {
      for (final i in indices) {
        final part = pages[i];
        final cid = part.cid ?? 0;
        if (cid == 0) {
          failed++;
          continue;
        }
        final url = pageUrlForPart(ctr.bvid, part, i);
        final durSec = part.duration;
        final prepared = await _prepareStripPlan(
          ctr,
          cidOverride: cid,
          durationMsOverride:
              (durSec != null && durSec > 0) ? durSec * 1000 : null,
          pageLabel: _partLabel(part, i),
          categories: categories,
          askCategories: false,
          showLoading: false,
        );

        String? keepJson;
        StripRemovalReport? report;
        var doStrip = false;
        if (prepared is _StripPrepareOk) {
          keepJson = prepared.keepJson;
          report = prepared.report;
          doStrip = true;
          reports.add(report);
          stripped++;
        } else if (prepared is _StripPrepareFail && forceStrip) {
          failed++;
          continue;
        } else {
          if (prepared is _StripPrepareSkip) {
            // keep silent-ish; count as plain
          }
          plain++;
        }

        final ok = await _launchSingleDelegate(
          ctr,
          extractAudio: extractAudio,
          url: url,
          cookieChoice: cookieChoice,
          stripReport: report,
          keepSectionsJson: keepJson,
          stripSegments: doStrip,
          mediaTitleSuffix: _partLabel(part, i),
        );
        if (ok) {
          launched++;
        } else {
          failed++;
        }
      }
    } finally {
      SmartDialog.dismiss();
    }

    if (launched == 0) {
      await _showErrorPanel(
        title: '无法委托下载',
        message: forceStrip
            ? '所选分 P 均无可用空降助手标记或启动失败'
            : '未能启动任何 Seal 下载任务',
      );
      return;
    }

    SmartDialog.showToast(
      '已委托 Seal：$launched 项'
      '${stripped > 0 ? '（空降助手去除 $stripped）' : ''}'
      '${plain > 0 ? '，普通 $plain' : ''}'
      '${failed > 0 ? '，跳过 $failed' : ''}',
    );

    if (reports.isNotEmpty) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 400), () {
        _showCombinedStripReports(reports);
      }));
    }
  }

  static String _partLabel(Part part, int index) {
    final pageNo = part.page ?? (index + 1);
    final title = part.part?.trim();
    if (title != null && title.isNotEmpty) {
      return 'P$pageNo · $title';
    }
    return 'P$pageNo';
  }

  static Future<void> _showCombinedStripReports(
    List<StripRemovalReport> reports,
  ) async {
    if (reports.isEmpty) return;
    if (reports.length == 1) {
      await _showStripReportSheet(reports.first);
      return;
    }
    final context = Get.context;
    if (context == null) return;
    final totalRemoved =
        reports.fold<int>(0, (s, r) => s + r.removedCount);
    final totalDurSec =
        (reports.fold<int>(0, (s, r) => s + r.removedDurationMs) / 1000)
            .round();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
        maxHeight: context.mediaQuerySize.height * 0.8,
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '空降助手去除标记报告',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '共 ${reports.length} 个分 P，去除 $totalRemoved 段（约 ${totalDurSec}s）',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    return ListTile(
                      dense: true,
                      title: Text(r.pageLabel ?? '分 P ${index + 1}'),
                      subtitle: Text(r.summaryLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showStripReportSheet(r),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Launch one Seal delegate without re-prompting cookies / multi-P.
  static Future<bool> _launchSingleDelegate(
    VideoDetailController ctr, {
    required bool extractAudio,
    required String url,
    required _CookieChoice cookieChoice,
    StripRemovalReport? stripReport,
    String? keepSectionsJson,
    bool stripSegments = false,
    String? mediaTitleSuffix,
  }) async {
    ensureListening();
    final requestId =
        'piliplus-${extractAudio ? 'audio' : 'video'}-${DateTime.now().microsecondsSinceEpoch}';
    final baseTitle = _titleOf(ctr);
    final title = mediaTitleSuffix == null || mediaTitleSuffix.isEmpty
        ? baseTitle
        : '$baseTitle · $mediaTitleSuffix';
    final session = _SealSession(
      requestId: requestId,
      extractAudio: extractAudio,
      pageUrl: url,
      mediaTitle: title,
      autoStart: Pref.sealAutoStart,
      itemCount: 1,
      stripReport: stripReport,
    );
    _sessions[requestId] = session;
    _activeRequestId = requestId;
    session.phase.value = Pref.sealAutoStart
        ? SealPanelPhase.waitingAuto
        : SealPanelPhase.waitingUi;
    session.message.value = stripSegments && stripReport != null
        ? '正在去除空降助手标记 ${stripReport.removedCount} 段…'
        : (Pref.sealAutoStart
              ? '已委托 Seal，正在自动入队…'
              : '已打开 Seal，请在 Seal 中确认下载');
    unawaited(_showOrUpdatePanel(session));

    try {
      final args = <String, dynamic>{
        'url': url,
        'urls': <String>[url],
        'extractAudio': extractAudio,
        'autoStart': Pref.sealAutoStart,
        'openUi': true,
        'requestId': requestId,
      };
      if (stripSegments && keepSectionsJson != null) {
        args['stripSegments'] = true;
        args['keepSections'] = keepSectionsJson;
      }
      if (cookieChoice is _CookieChoiceUse) {
        args['cookiesFormat'] = 'json_map';
        args['cookies'] = cookieChoice.cookiesJson;
        args['cookiesMid'] = cookieChoice.mid;
        args['cookiesDomainHint'] = '.bilibili.com';
        args['useCookies'] = true;
        args['cookiesRequired'] = false;
      }
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'delegateDownload',
        args,
      );
      if (result == null) {
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: '未收到 Seal 启动结果',
        );
        return false;
      }
      final status = SealDownloadStatus.fromMap(result);
      if (status.status == 'launched') {
        session.phase.value = Pref.sealAutoStart
            ? SealPanelPhase.waitingAuto
            : SealPanelPhase.waitingUi;
        return true;
      }
      if (status.status == 'not_installed' ||
          status.errorCode == 'not_installed') {
        _finishSession(
          session,
          SealPanelPhase.notInstalled,
          message: status.errorMessage ?? '请先安装 Seal',
        );
        return false;
      }
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: status.errorMessage ?? status.errorCode ?? 'Seal 启动失败',
      );
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'not_installed') {
        _finishSession(
          session,
          SealPanelPhase.notInstalled,
          message: e.message ?? '请先安装 Seal',
        );
      } else {
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: e.message ?? e.code,
        );
      }
      return false;
    } catch (e) {
      _finishSession(
        session,
        SealPanelPhase.failed,
        message: e.toString(),
      );
      return false;
    }
  }


  static int? _resolveDurationMs(VideoDetailController ctr) {
    final fromPlay = ctr.timeLength;
    if (fromPlay != null && fromPlay > 0) return fromPlay;
    try {
      final ugc = Get.find<UgcIntroController>(tag: ctr.heroTag);
      final detail = ugc.videoDetail.value;
      final pages = detail.pages;
      if (pages != null) {
        for (final part in pages) {
          if (part.cid == ctr.cid.value) {
            final sec = part.duration;
            if (sec != null && sec > 0) return sec * 1000;
            break;
          }
        }
      }
      final dur = detail.duration;
      if (dur != null && dur > 0) return dur * 1000;
    } catch (_) {}
    return null;
  }

  static Future<Set<String>?> _pickStripCategories(
    Set<String> initial,
  ) async {
    final context = Get.context;
    if (context == null) return initial;
    final options = SegmentType.values
        .where((t) => t != SegmentType.poi_highlight)
        .toList();
    final selected = {...initial};
    return showModalBottomSheet<Set<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
        maxHeight: context.mediaQuerySize.height * 0.7,
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '选择要剥离的标记类别',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in options)
                          CheckboxListTile(
                            dense: true,
                            value: selected.contains(t.name),
                            controlAffinity: ListTileControlAffinity.leading,
                            secondary: Icon(
                              Icons.circle,
                              size: 12,
                              color: t.color,
                            ),
                            title: Text(t.title),
                            subtitle: Text(
                              t.shortTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selected.add(t.name);
                                } else {
                                  selected.remove(t.name);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(selected),
                            child: Text('确认（${selected.length}）'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showStripReportSheet(StripRemovalReport report) async {
    final context = Get.context;
    if (context == null) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
        maxHeight: context.mediaQuerySize.height * 0.75,
      ),
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  '空降助手去除标记报告',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  report.summaryLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: report.removed.length,
                  itemBuilder: (context, index) {
                    final item = report.removed[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.circle,
                        size: 12,
                        color: item.type.color,
                      ),
                      title: Text(item.typeTitle),
                      subtitle: Text(
                        '${item.timeRangeLabel}'
                        '${item.uuid != null && item.uuid!.isNotEmpty ? ' · ${item.uuid}' : ''}'
                        ' · ${item.source}',
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String? pageUrlOf(VideoDetailController ctr) {
    if (ctr.isFileSource) return null;
    final epId = ctr.epId;
    if (epId != null) {
      return '${HttpString.baseUrl}/bangumi/play/ep$epId';
    }
    final bvid = ctr.bvid;
    if (bvid.isEmpty) return null;
    final pageNo = _currentPageNo(ctr);
    if (pageNo != null && pageNo > 0) {
      return '${HttpString.baseUrl}/video/$bvid?p=$pageNo';
    }
    return '${HttpString.baseUrl}/video/$bvid';
  }

  static int? _currentPageNo(VideoDetailController ctr) {
    if (!ctr.isUgc || ctr.epId != null) return null;
    try {
      final ugc = Get.find<UgcIntroController>(tag: ctr.heroTag);
      final pages = ugc.videoDetail.value.pages;
      if (pages == null || pages.isEmpty) return null;
      final currentCid = ctr.cid.value;
      final index = pages.indexWhere((e) => e.cid == currentCid);
      if (index >= 0) {
        return pages[index].page ?? (index + 1);
      }
      if (pages.length == 1) {
        return pages.first.page ?? 1;
      }
    } catch (_) {}
    return null;
  }

  static String pageUrlForPart(String bvid, Part part, int index) {
    final page = part.page ?? (index + 1);
    return '${HttpString.baseUrl}/video/$bvid?p=$page';
  }

  static List<String> pageUrlsForParts(String bvid, List<Part> parts) {
    if (bvid.isEmpty || parts.isEmpty) return const [];
    return [
      for (var i = 0; i < parts.length; i++) pageUrlForPart(bvid, parts[i], i),
    ];
  }

  static Future<_MultiPChoice?> _showMultiPChoiceSheet({
    required bool extractAudio,
    required int pageCount,
    bool forceStrip = false,
  }) async {
    final context = Get.context;
    if (context == null) return null;
    final kind = extractAudio ? '音频' : '视频';
    final title = forceStrip
        ? '下载并去除空降助手标记 · $pageCount 个分 P'
        : '下载$kind · $pageCount 个分 P';
    return showModalBottomSheet<_MultiPChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('当前 P'),
                onTap: () => Navigator.of(context).pop(_MultiPChoice.current),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded),
                title: const Text('选择分 P…'),
                onTap: () => Navigator.of(context).pop(_MultiPChoice.select),
              ),
              ListTile(
                leading: const Icon(Icons.select_all_rounded),
                title: Text('全部（$pageCount）'),
                onTap: () => Navigator.of(context).pop(_MultiPChoice.all),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Returns sorted indices into [parts] (original multi-P list).
  static Future<List<int>?> _pickPartIndices({
    required VideoDetailController ctr,
    required List<Part> parts,
    required bool extractAudio,
  }) async {
    final context = Get.context;
    if (context == null) return null;
    final currentCid = ctr.cid.value;
    final initial = <int>{
      for (var i = 0; i < parts.length; i++)
        if (parts[i].cid == currentCid) i,
    };
    if (initial.isEmpty) initial.add(0);

    return showModalBottomSheet<List<int>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
        maxHeight: context.mediaQuerySize.height * 0.75,
      ),
      builder: (context) {
        return _SealPartPickerSheet(
          parts: parts,
          initialSelected: initial,
          extractAudio: extractAudio,
        );
      },
    );
  }

  static String _titleOf(VideoDetailController ctr) {
    try {
      final args = Get.arguments;
      if (args is Map) {
        final t = args['title']?.toString().trim();
        if (t != null && t.isNotEmpty) return t;
        final fav = args['favTitle']?.toString().trim();
        if (fav != null && fav.isNotEmpty) return fav;
      }
    } catch (_) {}
    if (ctr.watchLaterTitle.trim().isNotEmpty) {
      return ctr.watchLaterTitle.trim();
    }
    return ctr.bvid;
  }

  /// Resolve optional cookie payload for Seal v2.
  /// Returns [_CookieChoice.anonymous] when passthrough off / no login / user skips.
  /// Returns [_CookieChoice.canceled] when sheet dismissed.
  static Future<_CookieChoice> _resolveCookiePayload() async {
    if (!Pref.sealCookiePassthrough) {
      return _CookieChoice.anonymous;
    }
    final accounts = _loginAccounts();
    if (accounts.isEmpty) {
      return _CookieChoice.anonymous;
    }

    LoginAccount? selected;
    // Remembered mid wins when still valid and not always-ask.
    if (!Pref.sealCookieAlwaysAsk && Pref.sealCookieRemember) {
      final mid = Pref.sealCookieRememberMid;
      if (mid != 0) {
        for (final a in accounts) {
          if (a.mid == mid && a.hasRequiredCookies) {
            selected = a;
            break;
          }
        }
      }
    }

    // Single login: auto-use without sheet unless always-ask.
    if (selected == null && accounts.length == 1 && !Pref.sealCookieAlwaysAsk) {
      selected = accounts.first;
    }

    if (selected == null) {
      final pick = await _showCookieAccountSheet(accounts);
      if (pick == null) return _CookieChoice.canceled;
      if (pick.anonymous) return _CookieChoice.anonymous;
      selected = pick.account;
      if (selected == null) return _CookieChoice.anonymous;
      if (pick.remember) {
        await Pref.setSealCookieRemember(remember: true, mid: selected.mid);
      } else {
        // User left remember off — clear any previous binding.
        await Pref.clearSealCookieRemember();
      }
    }

    return _cookieChoiceFromAccount(selected);
  }

  static _CookieChoice _cookieChoiceFromAccount(LoginAccount selected) {
    final map = selected.cookieJar.toJson();
    if (map.isEmpty ||
        (map['DedeUserID']?.toString().isEmpty ?? true) ||
        (map['bili_jct']?.toString().isEmpty ?? true)) {
      SmartDialog.showToast('账号凭证不完整，将匿名委托');
      return _CookieChoice.anonymous;
    }
    final json = jsonEncode(map);
    // Soft size guard (Seal hard-caps 256 KiB). Never log cookie values.
    if (json.length > 200 * 1024) {
      SmartDialog.showToast('Cookie 数据过大，将匿名委托');
      return _CookieChoice.anonymous;
    }
    return _CookieChoiceUse(
      mid: selected.mid,
      cookiesJson: json,
      keyCount: map.length,
    );
  }

  static List<LoginAccount> _loginAccounts() {
    final list = <LoginAccount>[];
    final seen = <int>{};
    for (final a in Accounts.account.values) {
      if (!a.shouldKeep || !a.hasRequiredCookies) continue;
      if (!seen.add(a.mid)) continue;
      list.add(a);
    }
    // Prefer video / main order for single-account default.
    list.sort((a, b) {
      int rank(LoginAccount x) {
        if (identical(x, Accounts.video) || x.mid == Accounts.video.mid) {
          return 0;
        }
        if (identical(x, Accounts.main) || x.mid == Accounts.main.mid) {
          return 1;
        }
        return 2;
      }

      return rank(a).compareTo(rank(b));
    });
    return list;
  }

  static Future<_CookieSheetResult?> _showCookieAccountSheet(
    List<LoginAccount> accounts,
  ) async {
    final context = Get.context;
    if (context == null) return null;
    var selectedMid = accounts.first.mid;
    // Prefer remembered highlight even when always-ask.
    final remembered = Pref.sealCookieRememberMid;
    if (remembered != 0 && accounts.any((a) => a.mid == remembered)) {
      selectedMid = remembered;
    } else if (Accounts.video is LoginAccount &&
        Accounts.video.isLogin &&
        accounts.any((a) => a.mid == Accounts.video.mid)) {
      selectedMid = Accounts.video.mid;
    } else if (Accounts.main is LoginAccount &&
        Accounts.main.isLogin &&
        accounts.any((a) => a.mid == Accounts.main.mid)) {
      selectedMid = Accounts.main.mid;
    }
    var remember = Pref.sealCookieRemember;

    return showModalBottomSheet<_CookieSheetResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: min(640, context.mediaQueryShortestSide),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      '使用 B 站账号下载',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '将把所选账号的登录凭证临时交给 Seal，仅用于本次下载；'
                      '不会写入 Seal 登录状态，也不会上传网络。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final a in accounts)
                    ListTile(
                      leading: Icon(
                        selectedMid == a.mid
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: selectedMid == a.mid
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(_accountLabel(a)),
                      subtitle: Text('UID ${a.mid}'),
                      onTap: () => setModalState(() => selectedMid = a.mid),
                    ),
                  SwitchListTile(
                    value: remember,
                    onChanged: (v) => setModalState(() => remember = v),
                    title: const Text('记住此账号'),
                    subtitle: const Text('下次委托时跳过选择（可在设置中清除）'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(
                            const _CookieSheetResult(anonymous: true),
                          ),
                          child: const Text('匿名委托'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            LoginAccount? acc;
                            for (final a in accounts) {
                              if (a.mid == selectedMid) {
                                acc = a;
                                break;
                              }
                            }
                            Navigator.of(context).pop(
                              _CookieSheetResult(
                                account: acc,
                                remember: remember,
                              ),
                            );
                          },
                          child: const Text('使用账号下载'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _accountLabel(LoginAccount account) {
    final badges = <String>[];
    if (account.mid == Accounts.main.mid && Accounts.main.isLogin) {
      badges.add('主账号');
    }
    if (account.mid == Accounts.video.mid && Accounts.video.isLogin) {
      badges.add('视频取流');
    }
    final uname = Pref.userInfoCache?.mid == account.mid
        ? Pref.userInfoCache?.uname?.trim()
        : null;
    final namePart = (uname != null && uname.isNotEmpty)
        ? uname
        : 'UID ${account.mid}';
    if (badges.isEmpty) {
      return uname != null && uname.isNotEmpty
          ? '$uname · UID ${account.mid}'
          : namePart;
    }
    return '${badges.join(' · ')} · $namePart';
  }

  static Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onDownloadStatus') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final status = SealDownloadStatus.fromMap(args);
    await _handleStatusEvent(status);
    return null;
  }

  static Future<void> _handleStatusEvent(SealDownloadStatus status) async {
    final key = _eventKey(status);
    if (!_handledEvents.add(key)) return;
    if (_handledEvents.length > 120) {
      _handledEvents.remove(_handledEvents.first);
    }

    if (kDebugMode) {
      debugPrint(
        'SealDownload status=${status.status} '
        'code=${status.errorCode} '
        'task=${status.taskId} '
        'req=${status.callerRequestId} '
        'source=${status.source}',
      );
    }

    final session = _resolveSession(status);
    if (session != null) {
      // Keep active pointer so late events still map after 后台等待.
      _activeRequestId ??= session.requestId;
      await _applyStatusToSession(session, status);
      return;
    }

    // Orphan terminal event (e.g. after app restart): still show panel.
    if (status.isTerminal ||
        status.status == 'accepted' ||
        status.status == 'rejected') {
      final orphan = _SealSession(
        requestId:
            status.callerRequestId ??
            'orphan-${DateTime.now().microsecondsSinceEpoch}',
        extractAudio: status.isAudioHint,
        pageUrl: '',
        mediaTitle: status.displayName ?? 'Seal 下载',
        autoStart: false,
      );
      _sessions[orphan.requestId] = orphan;
      _activeRequestId = orphan.requestId;
      await _applyStatusToSession(orphan, status);
    }
  }

  static _SealSession? _resolveSession(SealDownloadStatus status) {
    final requestId = status.callerRequestId;
    if (requestId != null && _sessions.containsKey(requestId)) {
      return _sessions[requestId];
    }
    if (_activeRequestId != null && _sessions.containsKey(_activeRequestId)) {
      return _sessions[_activeRequestId!];
    }
    if (_sessions.length == 1) return _sessions.values.first;
    return null;
  }

  static Future<void> _applyStatusToSession(
    _SealSession session,
    SealDownloadStatus status,
  ) async {
    final current = session.phase.value;
    switch (status.status) {
      case 'accepted':
        // Never regress from a successful terminal phase.
        if (current == SealPanelPhase.completed) break;
        session.taskId = status.taskId ?? session.taskId;
        session.phase.value = SealPanelPhase.accepted;
        session.message.value = session.stripReport != null
            ? '已交给 Seal 下载（空降助手去除 ${session.stripReport!.removedCount} 段），完成后将在此更新'
            : '已交给 Seal 下载，完成后将在此更新';
      case 'needs_ui':
        // Activity Result often arrives after the user already confirmed in Seal
        // (QuickDownloadActivity finishes later). Do not overwrite accepted/terminal.
        if (current == SealPanelPhase.accepted ||
            current.isTerminal ||
            current == SealPanelPhase.waitingAuto) {
          break;
        }
        session.phase.value = SealPanelPhase.waitingUi;
        session.message.value = '已打开 Seal，请确认下载配置';
      case 'rejected':
        if (current == SealPanelPhase.completed ||
            current == SealPanelPhase.accepted) {
          break;
        }
        _finishSession(
          session,
          SealPanelPhase.rejected,
          message: status.userFacingErrorMessage ?? 'Seal 拒绝了下载请求',
        );
      case 'completed':
        session.taskId = status.taskId ?? session.taskId;
        session.contentUri = status.contentUri ?? session.contentUri;
        session.displayName = status.displayName ?? session.displayName;
        session.mimeType = status.mimeType ?? session.mimeType;
        session.phase.value = SealPanelPhase.completed;
        if (session.stripReport != null) {
          session.message.value = session.stripReport!.summaryLabel;
          final name = session.displayName;
          if (name != null &&
              name.isNotEmpty &&
              !name.contains('[去广告]')) {
            session.displayName = '$name [去广告]';
          }
        } else {
          session.message.value = (session.contentUri?.isNotEmpty == true)
              ? '下载完成，可打开或分享文件'
              : '下载完成（文件在 Seal 中查看）';
        }
        await _showOrUpdatePanel(session);
        if (session.stripReport != null) {
          unawaited(_showStripReportSheet(session.stripReport!));
        }
        return;
      case 'failed':
        if (current == SealPanelPhase.completed) break;
        _finishSession(
          session,
          SealPanelPhase.failed,
          message: status.userFacingErrorMessage ?? 'Seal 下载失败',
        );
      case 'canceled':
        // Empty-session cancel (UI closed without enqueue) must not clobber
        // a real accepted/completed task that already reported.
        if (current == SealPanelPhase.accepted ||
            current == SealPanelPhase.completed ||
            current == SealPanelPhase.failed) {
          break;
        }
        // If we already have a task id, prefer keeping in-progress over empty cancel.
        if (session.taskId != null &&
            session.taskId!.isNotEmpty &&
            (status.taskId == null || status.taskId!.isEmpty)) {
          break;
        }
        _finishSession(
          session,
          SealPanelPhase.canceled,
          message: '已取消 Seal 下载',
        );
      case 'launched':
        if (current == SealPanelPhase.accepted ||
            current.isTerminal ||
            current == SealPanelPhase.waitingUi ||
            current == SealPanelPhase.waitingAuto) {
          break;
        }
        session.phase.value = session.autoStart
            ? SealPanelPhase.waitingAuto
            : SealPanelPhase.waitingUi;
      default:
        if (status.status.isNotEmpty) {
          session.message.value = 'Seal 状态：${status.status}';
        }
    }
    await _showOrUpdatePanel(session);
  }


  static void _finishSession(
    _SealSession session,
    SealPanelPhase phase, {
    required String message,
  }) {
    session.phase.value = phase;
    session.message.value = message;
    unawaited(_showOrUpdatePanel(session));
  }

  static String _eventKey(SealDownloadStatus status) {
    final request = status.callerRequestId ?? '';
    final task = status.taskId ?? '';
    final uri = status.contentUri ?? '';
    final source = status.source ?? '';
    return '$request|$task|${status.status}|${status.errorCode ?? ''}|$uri|$source';
  }

  static Future<void> _showErrorPanel({
    required String title,
    required String message,
  }) async {
    final session = _SealSession(
      requestId: 'error-${DateTime.now().microsecondsSinceEpoch}',
      extractAudio: false,
      pageUrl: '',
      mediaTitle: title,
      autoStart: false,
    );
    session.phase.value = SealPanelPhase.failed;
    session.message.value = message;
    _sessions[session.requestId] = session;
    _activeRequestId = session.requestId;
    await _showOrUpdatePanel(session);
  }

  static Future<void> _showOrUpdatePanel(_SealSession session) async {
    final isOpen = SmartDialog.checkExist(tag: _panelTag);
    if (isOpen) {
      // ValueNotifiers drive the already-open panel.
      return;
    }
    // Fire-and-forget: SmartDialog.show completes only when dismissed.
    // Awaiting it would block delegateDownload until the user taps 后台等待 (R1).
    unawaited(
      SmartDialog.show(
        tag: _panelTag,
        keepSingle: true,
        clickMaskDismiss: false,
        backType: SmartBackType.normal,
        animationType: SmartAnimationType.centerFade_otherSlide,
        animationTime: const Duration(milliseconds: 220),
        builder: (context) {
          return _SealStatusPanel(
            session: session,
            onClose: () => _closePanel(session),
            onInstall: () async {
              await PageUtils.launchURL(releasesUrl);
            },
            onOpen: () async {
              final uri = session.contentUri;
              if (uri == null || uri.isEmpty) return;
              await openContentUri(uri: uri, mimeType: session.mimeType);
            },
            onShare: () async {
              final uri = session.contentUri;
              if (uri == null || uri.isEmpty) return;
              await shareContentUri(
                uri: uri,
                mimeType: session.mimeType,
                displayName: session.displayName,
              );
            },
            onRetry: () async {
              await _closePanel(session);
              // Re-delegate with same mode; caller should re-tap menu if needed.
            },
          );
        },
      ),
    );
  }

  static Future<void> _closePanel(_SealSession session) async {
    await SmartDialog.dismiss(tag: _panelTag);
    // Keep mapping for late accepted/completed after user taps 后台等待.
    _activeRequestId ??= session.requestId;
    // Only drop terminal sessions after the user dismisses the final UI.
    if (session.phase.value.isTerminal) {
      _sessions.remove(session.requestId);
      if (_activeRequestId == session.requestId) {
        _activeRequestId = null;
      }
    }
  }


  static Future<void> openContentUri({
    required String uri,
    String? mimeType,
  }) async {
    try {
      await _channel.invokeMethod<bool>('openContentUri', <String, dynamic>{
        'uri': uri,
        'mimeType': mimeType,
      });
    } on PlatformException catch (error) {
      SmartDialog.showToast(error.message ?? '无法打开文件');
    } catch (error) {
      SmartDialog.showToast('无法打开文件：$error');
    }
  }

  static Future<void> shareContentUri({
    required String uri,
    String? mimeType,
    String? displayName,
  }) async {
    try {
      await _channel.invokeMethod<bool>('shareContentUri', <String, dynamic>{
        'uri': uri,
        'mimeType': mimeType,
        'displayName': displayName,
      });
    } on PlatformException catch (error) {
      SmartDialog.showToast(error.message ?? '无法分享文件');
    } catch (error) {
      SmartDialog.showToast('无法分享文件：$error');
    }
  }
}

enum SealPanelPhase {
  launching,
  waitingUi,
  waitingAuto,
  accepted,
  completed,
  failed,
  rejected,
  canceled,
  notInstalled;

  bool get isBusy =>
      this == launching ||
      this == waitingUi ||
      this == waitingAuto ||
      this == accepted;

  bool get isTerminal =>
      this == completed ||
      this == failed ||
      this == rejected ||
      this == canceled ||
      this == notInstalled;

  bool get isSuccess => this == completed;

  bool get isError =>
      this == failed || this == rejected || this == notInstalled;
}

enum _MultiPChoice { current, select, all }

final class _SealSession {
  _SealSession({
    required this.requestId,
    required this.extractAudio,
    required this.pageUrl,
    required this.mediaTitle,
    required this.autoStart,
    this.itemCount = 1,
    this.stripReport,
  });

  final String requestId;
  final bool extractAudio;
  final String pageUrl;
  final String mediaTitle;
  final bool autoStart;
  final int itemCount;
  final StripRemovalReport? stripReport;

  final ValueNotifier<SealPanelPhase> phase = ValueNotifier(
    SealPanelPhase.waitingUi,
  );
  final ValueNotifier<String> message = ValueNotifier('请在 Seal 中确认下载');

  String? taskId;
  String? contentUri;
  String? displayName;
  String? mimeType;

  String get kindLabel => extractAudio ? '音频' : '视频';

  String get metaLabel {
    final stripTag = stripReport != null ? ' · 去广告' : '';
    if (itemCount > 1) {
      return '$kindLabel · $mediaTitle (${itemCount}P)$stripTag';
    }
    return '$kindLabel · $mediaTitle$stripTag';
  }
}

sealed class _StripPrepareResult {
  const _StripPrepareResult();
}

final class _StripPrepareOk extends _StripPrepareResult {
  const _StripPrepareOk({required this.report, required this.keepJson});
  final StripRemovalReport report;
  final String keepJson;
}

final class _StripPrepareSkip extends _StripPrepareResult {
  const _StripPrepareSkip(this.message);
  final String message;
}

final class _StripPrepareFail extends _StripPrepareResult {
  const _StripPrepareFail(this.message);
  final String message;
}

final class SealDownloadStatus {
  const SealDownloadStatus({
    required this.status,
    this.errorCode,
    this.errorMessage,
    this.taskId,
    this.callerRequestId,
    this.contentUri,
    this.displayName,
    this.mimeType,
    this.source,
  });

  factory SealDownloadStatus.fromMap(Map<dynamic, dynamic> map) {
    return SealDownloadStatus(
      status: map['status']?.toString() ?? '',
      errorCode: map['error_code']?.toString(),
      errorMessage: map['error_message']?.toString(),
      taskId: map['task_id']?.toString(),
      callerRequestId: map['caller_request_id']?.toString(),
      contentUri: map['content_uri']?.toString(),
      displayName: map['display_name']?.toString(),
      mimeType: map['mime_type']?.toString(),
      source: map['source']?.toString(),
    );
  }

  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String? taskId;
  final String? callerRequestId;
  final String? contentUri;
  final String? displayName;
  final String? mimeType;
  final String? source;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'canceled';

  bool get isAudioHint {
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('audio/') ||
        name.endsWith('.m4a') ||
        name.endsWith('.mp3') ||
        name.endsWith('.opus') ||
        name.endsWith('.flac');
  }

  bool get isVideoHint {
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm');
  }

  String? get userFacingErrorMessage {
    final message = errorMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    return switch (errorCode) {
      'disabled' => 'Seal 已关闭外部下载委托',
      'auto_start_denied' => 'Seal 未允许自动开始下载',
      'invalid_url' => '无效的下载链接',
      'unsupported_version' => 'Seal 协议版本不兼容',
      'caller_denied' => 'Seal 白名单拒绝了当前应用',
      'queue_rejected' => 'Seal 请求过于频繁，请稍后再试',
      'internal_error' => 'Seal 内部错误',
      'download_failed' => 'Seal 下载失败',
      'canceled' => '已取消 Seal 下载',
      'cookie_denied' || 'cookies_disabled' =>
        'Seal 未允许外部 Cookie（请在 Seal → 外部下载中开启）',
      'cookie_invalid' || 'cookies_invalid' => 'Cookie 无效，请重新登录后重试',
      'cookie_too_large' || 'cookies_too_large' => 'Cookie 数据过大',
      'cookies_uri_denied' => '无法将 Cookie 交给 Seal',
      'cookies_unsupported' => 'Seal 不支持当前 Cookie 格式',
      _ => null,
    };
  }
}

sealed class _CookieChoice {
  const _CookieChoice();
  static const anonymous = _CookieChoiceAnonymous();
  static const canceled = _CookieChoiceCanceled();
}

final class _CookieChoiceAnonymous extends _CookieChoice {
  const _CookieChoiceAnonymous();
}

final class _CookieChoiceCanceled extends _CookieChoice {
  const _CookieChoiceCanceled();
}

final class _CookieChoiceUse extends _CookieChoice {
  const _CookieChoiceUse({
    required this.mid,
    required this.cookiesJson,
    required this.keyCount,
  });
  final int mid;
  final String cookiesJson;
  final int keyCount;
}

final class _CookieSheetResult {
  const _CookieSheetResult({
    this.account,
    this.anonymous = false,
    this.remember = false,
  });
  final LoginAccount? account;
  final bool anonymous;
  final bool remember;
}

class _SealStatusPanel extends StatefulWidget {
  const _SealStatusPanel({
    required this.session,
    required this.onClose,
    required this.onInstall,
    required this.onOpen,
    required this.onShare,
    required this.onRetry,
  });

  final _SealSession session;
  final FutureOr<void> Function() onClose;
  final FutureOr<void> Function() onInstall;
  final FutureOr<void> Function() onOpen;
  final FutureOr<void> Function() onShare;
  final FutureOr<void> Function() onRetry;

  @override
  State<_SealStatusPanel> createState() => _SealStatusPanelState();
}

class _SealStatusPanelState extends State<_SealStatusPanel>
    with SingleTickerProviderStateMixin {
  static const _panelRadius = BorderRadius.all(Radius.circular(18));
  static const _stepLabels = <String>['确认', '下载', '完成'];

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _enter,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    widget.session.phase.addListener(_onChanged);
    widget.session.message.addListener(_onChanged);
    _enter.forward();
  }

  @override
  void dispose() {
    widget.session.phase.removeListener(_onChanged);
    widget.session.message.removeListener(_onChanged);
    _enter.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final session = widget.session;
    final phase = session.phase.value;
    final hasUri = session.contentUri?.isNotEmpty == true;
    final statusColor = _statusColor(cs, phase);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Style.safeSpace),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: _panelRadius,
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusBadge(
                              icon: _iconFor(phase),
                              color: statusColor,
                              busy: phase.isBusy,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    child: Text(
                                      _headline(phase),
                                      key: ValueKey('h-$phase'),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      session.message.value,
                                      key: ValueKey(session.message.value),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _metaChip(theme, cs, session),
                        if (phase == SealPanelPhase.completed &&
                            (session.displayName?.isNotEmpty == true ||
                                hasUri)) ...[
                          const SizedBox(height: 10),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      session.displayName ?? '已完成文件',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (!phase.isError &&
                            phase != SealPanelPhase.canceled) ...[
                          const SizedBox(height: 14),
                          _StepTrack(
                            activeIndex: _stepIndex(phase),
                            labels: _stepLabels,
                            color: statusColor,
                            completed: phase.isSuccess,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _buildActions(theme, cs, phase, hasUri),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaChip(ThemeData theme, ColorScheme cs, _SealSession session) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                session.extractAudio
                    ? Icons.music_note_rounded
                    : Icons.movie_outlined,
                size: 15,
                color: cs.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  session.metaLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    ThemeData theme,
    ColorScheme cs,
    SealPanelPhase phase,
    bool hasUri,
  ) {
    if (phase == SealPanelPhase.notInstalled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => widget.onInstall(),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('前往安装 Seal'),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: () => widget.onClose(), child: const Text('关闭')),
        ],
      );
    }

    if (phase == SealPanelPhase.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasUri)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => widget.onOpen(),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('打开'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => widget.onShare(),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('分享'),
                  ),
                ),
              ],
            )
          else
            Text(
              '可在 Seal 下载列表中查看文件',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          if (widget.session.stripReport != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                SealDownloadUtils._showStripReportSheet(
                  widget.session.stripReport!,
                );
              },
              icon: const Icon(Icons.playlist_remove_rounded, size: 18),
              label: Text(
                '查看空降助手去除报告（${widget.session.stripReport!.removedCount} 段）',
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(onPressed: () => widget.onClose(), child: const Text('关闭')),
        ],
      );
    }

    if (phase.isBusy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            phase == SealPanelPhase.waitingUi
                ? '确认后可返回本页，完成后会自动更新'
                : phase == SealPanelPhase.accepted
                ? '可继续浏览，下载完成后会自动更新'
                : '请稍候，状态会自动刷新',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
          ),
          TextButton(
            onPressed: () => widget.onClose(),
            child: const Text('后台等待'),
          ),
        ],
      );
    }

    return FilledButton.tonal(
      onPressed: () => widget.onClose(),
      child: const Text('知道了'),
    );
  }

  int _stepIndex(SealPanelPhase phase) {
    return switch (phase) {
      SealPanelPhase.launching ||
      SealPanelPhase.waitingUi ||
      SealPanelPhase.waitingAuto =>
        0,
      SealPanelPhase.accepted => 1,
      SealPanelPhase.completed => 2,
      _ => 0,
    };
  }

  String _headline(SealPanelPhase phase) {
    return switch (phase) {
      SealPanelPhase.launching => '等待在 Seal 中确认',
      SealPanelPhase.waitingUi => '等待在 Seal 中确认',
      SealPanelPhase.waitingAuto => '正在自动入队',
      SealPanelPhase.accepted => 'Seal 下载进行中',
      SealPanelPhase.completed => 'Seal 下载完成',
      SealPanelPhase.failed => '下载失败',
      SealPanelPhase.rejected => '请求被拒绝',
      SealPanelPhase.canceled => '已取消下载',
      SealPanelPhase.notInstalled => '未安装 Seal',
    };
  }

  IconData _iconFor(SealPanelPhase phase) {
    return switch (phase) {
      SealPanelPhase.launching => Icons.touch_app_rounded,
      SealPanelPhase.waitingUi => Icons.touch_app_rounded,
      SealPanelPhase.waitingAuto => Icons.hourglass_top_rounded,
      SealPanelPhase.accepted => Icons.cloud_download_rounded,
      SealPanelPhase.completed => Icons.check_rounded,
      SealPanelPhase.failed => Icons.error_outline_rounded,
      SealPanelPhase.rejected => Icons.block_rounded,
      SealPanelPhase.canceled => Icons.cancel_outlined,
      SealPanelPhase.notInstalled => Icons.install_mobile_rounded,
    };
  }

  Color _statusColor(ColorScheme cs, SealPanelPhase phase) {
    if (phase.isSuccess) return cs.primary;
    if (phase.isError) return cs.error;
    if (phase == SealPanelPhase.canceled) return cs.outline;
    return cs.primary;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.color,
    required this.busy,
  });

  final IconData icon;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: color.withValues(alpha: 0.55),
                ),
              ),
            Icon(icon, size: 22, color: color),
          ],
        ),
      ),
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({
    required this.activeIndex,
    required this.labels,
    required this.color,
    required this.completed,
  });

  final int activeIndex;
  final List<String> labels;
  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 2,
                      decoration: BoxDecoration(
                        color: (completed || i <= activeIndex)
                            ? color.withValues(alpha: 0.75)
                            : cs.outlineVariant.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              _StepDot(
                index: i,
                activeIndex: activeIndex,
                color: color,
                completed: completed,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == labels.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: (completed || i <= activeIndex)
                        ? cs.onSurface
                        : cs.outline,
                    fontWeight: (completed || i == activeIndex)
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.activeIndex,
    required this.color,
    required this.completed,
  });

  final int index;
  final int activeIndex;
  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = completed || index < activeIndex;
    final active = !completed && index == activeIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 12,
      height: active ? 18 : 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? color : cs.surfaceContainerHighest,
        border: Border.all(
          color: done || active
              ? color
              : cs.outlineVariant.withValues(alpha: 0.8),
          width: active ? 2 : 1,
        ),
      ),
      child: done
          ? Icon(
              Icons.check_rounded,
              size: active ? 12 : 10,
              color: cs.onPrimary,
            )
          : active
          ? Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: cs.onPrimary,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _SealPartPickerSheet extends StatefulWidget {
  const _SealPartPickerSheet({
    required this.parts,
    required this.initialSelected,
    required this.extractAudio,
  });

  final List<Part> parts;
  final Set<int> initialSelected;
  final bool extractAudio;

  @override
  State<_SealPartPickerSheet> createState() => _SealPartPickerSheetState();
}

class _SealPartPickerSheetState extends State<_SealPartPickerSheet> {
  late final Set<int> _selected = {...widget.initialSelected};

  bool get _allSelected => _selected.length == widget.parts.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(List<int>.generate(widget.parts.length, (i) => i));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.extractAudio ? '音频' : '视频';
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '选择分 P · 下载$kind',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _toggleAll,
                  child: Text(_allSelected ? '取消全选' : '全选'),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.parts.length,
              itemBuilder: (context, index) {
                final part = widget.parts[index];
                final pageNo = part.page ?? (index + 1);
                final title = (part.part?.trim().isNotEmpty == true)
                    ? part.part!
                    : 'P$pageNo';
                final checked = _selected.contains(index);
                return CheckboxListTile(
                  dense: true,
                  value: checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'P$pageNo · $title',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(index);
                      } else {
                        _selected.remove(index);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () {
                            // Pop original indices (not Part copies) so
                            // pageUrlForPart can use list index as ?p= fallback.
                            final ordered = _selected.toList()..sort();
                            Navigator.of(context).pop(ordered);
                          },
                    child: Text('确认（${_selected.length}）'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
