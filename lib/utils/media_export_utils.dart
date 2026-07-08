import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;

import 'package:pili_plus/common/constants.dart';
import 'package:pili_plus/http/init.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/video.dart';
import 'package:pili_plus/models/common/video/audio_quality.dart';
import 'package:pili_plus/models/video/play/url.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/pages/video/introduction/pgc/controller.dart';
import 'package:pili_plus/pages/video/introduction/ugc/controller.dart';
import 'package:pili_plus/utils/extension/file_ext.dart';
import 'package:pili_plus/utils/extension/iterable_ext.dart';
import 'package:pili_plus/utils/extension/string_ext.dart';
import 'package:pili_plus/utils/image_utils.dart';
import 'package:pili_plus/utils/path_utils.dart';
import 'package:pili_plus/utils/platform_utils.dart';
import 'package:pili_plus/utils/share_utils.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:pili_plus/utils/video_utils.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

/// 将当前视频下载为本地媒体文件：
/// - 音频：当前视频的 DASH 音频流，保存为 .m4a
/// - 视频：MP4 直链（durl，音视频合一，最高 1080P）
abstract final class MediaExportUtils {
  static const _dialogTag = 'media_export_progress';

  static bool _busy = false;

  static bool _prepare() {
    if (_busy) {
      SmartDialog.showToast('已有下载任务进行中');
      return false;
    }
    _busy = true;
    return true;
  }

  static Future<void> exportVideo(VideoDetailController ctr) async {
    if (!_prepare()) return;
    try {
      SmartDialog.showLoading(msg: '正在获取下载地址');
      final res = await VideoHttp.videoUrl(
        cid: ctr.cid.value,
        bvid: ctr.bvid,
        epid: ctr.epId,
        seasonId: ctr.seasonId,
        qn: ctr.currentVideoQa.value?.code,
        fnval: 1,
        tryLook: ctr.plPlayerController.tryLook,
        videoType: ctr.actualVideoType,
      );
      SmartDialog.dismiss(status: SmartStatus.loading);
      if (res case Success(:final response)) {
        final durl = response.durl;
        if (durl == null || durl.isEmpty) {
          SmartDialog.showToast('未获取到 MP4 直链，该内容暂不支持直接下载');
          return;
        }
        if (durl.length > 1) {
          SmartDialog.showToast('该视频包含多个分段，暂不支持直接下载');
          return;
        }
        final ext = response.format?.startsWith('flv') == true ? 'flv' : 'mp4';
        final qaDesc = response.supportFormats
            ?.firstWhereOrNull((e) => e.quality == response.quality)
            ?.newDesc;
        await _download(
          dialogTitle: '下载视频',
          url: VideoUtils.getCdnUrl(durl.first.playUrls),
          fileName:
              '${_fileTitle(ctr)}${qaDesc == null ? '' : '[$qaDesc]'}.$ext',
          isAudio: false,
        );
      } else {
        res.toast();
      }
    } catch (e) {
      SmartDialog.showToast('下载失败：$e');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      _busy = false;
    }
  }

  static Future<void> exportAudio(VideoDetailController ctr) async {
    if (!_prepare()) return;
    try {
      List<AudioItem>? audioList;
      if (ctr.videoUrl != null && !ctr.isQuerying) {
        audioList = ctr.data.dash?.audio;
      } else {
        SmartDialog.showLoading(msg: '正在获取下载地址');
        final res = await VideoHttp.videoUrl(
          cid: ctr.cid.value,
          bvid: ctr.bvid,
          epid: ctr.epId,
          seasonId: ctr.seasonId,
          tryLook: ctr.plPlayerController.tryLook,
          videoType: ctr.actualVideoType,
        );
        SmartDialog.dismiss(status: SmartStatus.loading);
        if (res case Success(:final response)) {
          audioList = response.dash?.audio;
        } else {
          res.toast();
          return;
        }
      }
      if (audioList == null || audioList.isEmpty) {
        SmartDialog.showToast('该视频没有独立音频流，暂不支持下载音频');
        return;
      }
      final audio = _selectAudio(audioList);
      final qaDesc = audio.id == null
          ? null
          : AudioQuality.fromCode(audio.id!).desc;
      await _download(
        dialogTitle: '下载音频',
        url: VideoUtils.getCdnUrl(audio.playUrls, isAudio: true),
        fileName: '${_fileTitle(ctr)}${qaDesc == null ? '' : '[$qaDesc]'}.m4a',
        isAudio: true,
      );
    } catch (e) {
      SmartDialog.showToast('下载失败：$e');
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
      _busy = false;
    }
  }

  /// 与播放/缓存一致：优先设置中的默认音质
  static AudioItem _selectAudio(List<AudioItem> audioList) {
    final preferAudioQa = Pref.defaultAudioQa;
    final audioIds = audioList.map((e) => e.id!).toList();
    int target = audioIds.findClosestTarget(
      (e) => e <= preferAudioQa,
      (a, b) => a > b ? a : b,
    );
    if (!audioIds.contains(preferAudioQa) &&
        audioIds.any((e) => e > preferAudioQa)) {
      target = AudioQuality.k192.code;
    }
    return audioList.firstWhere(
      (e) => e.id == target,
      orElse: () => audioList.first,
    );
  }

  static String _fileTitle(VideoDetailController ctr) {
    String? title;
    try {
      if (ctr.isUgc) {
        final videoDetail = Get.find<UgcIntroController>(
          tag: ctr.heroTag,
        ).videoDetail.value;
        title = videoDetail.title;
        final pages = videoDetail.pages;
        if (title != null && pages != null && pages.length > 1) {
          final part = pages.firstWhereOrNull((e) => e.cid == ctr.cid.value);
          if (part?.part case final String partTitle?) {
            title = '$title $partTitle';
          }
        }
      } else {
        final pgcItem = Get.find<PgcIntroController>(tag: ctr.heroTag).pgcItem;
        final episode = pgcItem.episodes?.firstWhereOrNull(
          (e) => e.cid == ctr.cid.value,
        );
        final epTitle = episode?.showTitle ?? episode?.title;
        title = '${pgcItem.title ?? ''}${epTitle == null ? '' : ' $epTitle'}';
      }
    } catch (_) {}
    title = title?.trim();
    if (title == null || title.isEmpty) {
      title = ctr.bvid;
    }
    return _sanitizeFileName(title);
  }

  static final _invalidFileNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

  static String _sanitizeFileName(String name) {
    name = name.replaceAll(_invalidFileNameChars, ' ').trim();
    if (name.length > 80) {
      name = String.fromCharCodes(name.runes.take(80)).trim();
    }
    while (name.endsWith('.')) {
      name = name.substring(0, name.length - 1);
    }
    return name.isEmpty ? 'video' : name;
  }

  static Future<void> _download({
    required String dialogTitle,
    required String url,
    required String fileName,
    required bool isAudio,
  }) async {
    final String savePath;
    final bool isMobile = PlatformUtils.isMobile;
    if (isMobile) {
      if (!await ImageUtils.checkPermissionDependOnSdkInt()) {
        return;
      }
      savePath =
          '$tmpDirPath/export_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    } else {
      final String? pickedPath;
      try {
        pickedPath = await FilePicker.saveFile(
          fileName: fileName,
          type: isAudio ? FileType.audio : FileType.video,
          bytes: Uint8List(0),
        );
      } catch (e) {
        SmartDialog.showToast('$e');
        return;
      }
      if (pickedPath == null) {
        SmartDialog.showToast('取消保存');
        return;
      }
      savePath = pickedPath;
    }

    final cancelToken = CancelToken();
    final progress = ValueNotifier<double?>(null);
    final progressText = ValueNotifier<String?>(null);
    _showProgressDialog(
      dialogTitle: dialogTitle,
      fileName: fileName,
      progress: progress,
      progressText: progressText,
      onCancel: cancelToken.cancel,
    );

    try {
      await Request.http11Dio.download(
        url.http2https,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            progress.value = count / total;
            progressText.value = '${_fmtBytes(count)} / ${_fmtBytes(total)}';
          } else {
            progressText.value = _fmtBytes(count);
          }
        },
      );
      SmartDialog.dismiss(tag: _dialogTag);
      if (isMobile) {
        await _saveOnMobile(savePath, fileName, isAudio);
      } else {
        SmartDialog.showToast('已保存至 $savePath');
      }
    } catch (e) {
      SmartDialog.dismiss(tag: _dialogTag);
      File(savePath).tryDel();
      if (e is DioException && CancelToken.isCancel(e)) {
        SmartDialog.showToast('已取消下载');
      } else {
        SmartDialog.showToast('下载失败：$e');
      }
    }
  }

  static Future<void> _saveOnMobile(
    String filePath,
    String fileName,
    bool isAudio,
  ) async {
    try {
      if (isAudio && Platform.isIOS) {
        // iOS 媒体库不支持音频，走系统分享保存
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(filePath)],
            sharePositionOrigin: await ShareUtils.sharePositionOrigin,
          ),
        );
        return;
      }
      final albumPath = Platform.isAndroid
          ? '${isAudio ? 'Music' : 'Movies'}/${Constants.appName}'
          : Constants.appName;
      final res = await SaverGallery.saveFile(
        filePath: filePath,
        fileName: fileName,
        albumPath: albumPath,
        skipIfExists: false,
      );
      if (res.isSuccess) {
        SmartDialog.showToast(
          Platform.isAndroid ? '已保存至 $albumPath' : ' 已保存 ',
        );
      } else {
        SmartDialog.showToast('保存失败，${res.errorMessage}');
      }
    } catch (e) {
      SmartDialog.showToast('保存失败：$e');
    } finally {
      File(filePath).tryDel();
    }
  }

  static void _showProgressDialog({
    required String dialogTitle,
    required String fileName,
    required ValueNotifier<double?> progress,
    required ValueNotifier<String?> progressText,
    required VoidCallback onCancel,
  }) {
    SmartDialog.show(
      tag: _dialogTag,
      clickMaskDismiss: false,
      backType: SmartBackType.block,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 14,
            children: [
              Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              ValueListenableBuilder(
                valueListenable: progress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
              ),
              ValueListenableBuilder(
                valueListenable: progressText,
                builder: (context, value, _) => Text(
                  value ?? '准备中...',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: onCancel,
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  static String _fmtBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= mb * 1024) {
      return '${(bytes / (mb * 1024)).toStringAsFixed(2)}GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)}MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  }
}
