import 'package:pili_plus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:pili_plus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:pili_plus/pages/video/controller.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_sheet.dart';
import 'package:pili_plus/pages/video/introduction/pgc/controller.dart';
import 'package:pili_plus/pages/video/introduction/ugc/controller.dart';
import 'package:pili_plus/plugin/pl_player/controller.dart';
import 'package:pili_plus/plugin/pl_player/view/view.dart';
import 'package:pili_plus/utils/extension/theme_ext.dart';
import 'package:pili_plus/utils/feed_back.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.maxWidth,
    required this.isFullScreen,
    required this.controller,
    required this.buildBottomControl,
    required this.videoDetailController,
  });

  final double maxWidth;
  final bool isFullScreen;
  final PlPlayerController controller;
  final ValueGetter<Widget> buildBottomControl;
  final VideoDetailController videoDetailController;

  static double _widgetWidth(bool isFullScreen) =>
      PlatformUtils.isMobile ? (isFullScreen ? 48 : 40) : (isFullScreen ? 42 : 35);
  static const double _widgetHeight = 36.0;

  void onDragStart(ThumbDragDetails duration) {
    feedBack();
    controller
      ..position.value = duration.seconds
      ..isSeeking.value = true;
  }

  void onDragUpdate(ThumbDragDetails duration) {
    if (!controller.isFileSource && controller.showSeekPreview) {
      controller.updatePreviewIndex(duration.seconds);
    }
    controller.position.value = duration.seconds;
  }

  void onSeek(int milliseconds) {
    controller
      ..onSeekEnd()
      ..seekTo(Duration(milliseconds: milliseconds), isSeek: false);
  }

  ({String title, int? authorMid}) _bookmarkMetadata() {
    String? title = videoDetailController.args['title'] as String?;
    int? authorMid;
    try {
      if (videoDetailController.isUgc) {
        final detail = Get.find<UgcIntroController>(
          tag: videoDetailController.heroTag,
        ).videoDetail.value;
        title = detail.title ?? title;
        authorMid = detail.owner?.mid;
      } else {
        final intro = Get.find<PgcIntroController>(
          tag: videoDetailController.heroTag,
        );
        title = intro.videoDetail.value.title ?? intro.pgcItem.title ?? title;
        authorMid = intro.pgcItem.upInfo?.mid;
      }
    } catch (_) {}

    final normalizedTitle = title?.trim();
    return (
      title: normalizedTitle == null || normalizedTitle.isEmpty
          ? videoDetailController.bvid
          : normalizedTitle,
      authorMid: authorMid,
    );
  }

  void _showBookmarkSheet(BuildContext context) {
    final metadata = _bookmarkMetadata();
    PageUtils.showVideoBottomSheet(
      context,
      child: VideoBookmarkSheet(
        bvid: videoDetailController.bvid,
        videoTitle: metadata.title,
        authorMid: metadata.authorMid,
        currentTimestamp: controller.position.value,
        onBookmarkTap: (bookmark) => controller.seekTo(
          Duration(seconds: bookmark.timestampSeconds),
          isSeek: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final primary = colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    final thumbGlowColor = primary.withAlpha(80);
    final bufferedBarColor = primary.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
            child: Obx(
              () => Offstage(
                offstage: !controller.showControls.value,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Obx(
                      () => ProgressBar(
                        progress: controller.position.value,
                        buffered: controller.buffered.value,
                        total: controller.duration.value,
                        progressBarColor: primary,
                        baseBarColor: const Color(0x33FFFFFF),
                        bufferedBarColor: bufferedBarColor,
                        thumbColor: primary,
                        thumbGlowColor: thumbGlowColor,
                        barHeight: 3.5,
                        thumbRadius: 7,
                        thumbGlowRadius: 25,
                        onDragStart: onDragStart,
                        onDragUpdate: onDragUpdate,
                        onSeek: onSeek,
                      ),
                    ),
                    if (controller.enableBlock &&
                        videoDetailController.segmentProgressList.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 5.25,
                        child: SegmentProgressBar(
                          segments: videoDetailController.segmentProgressList,
                        ),
                      ),
                    if (controller.showViewPoints &&
                        videoDetailController.viewPointList.isNotEmpty &&
                        videoDetailController.showVP.value)
                      Padding(
                        padding: const .only(bottom: 8.75),
                        child: ViewPointSegmentProgressBar(
                          segments: videoDetailController.viewPointList,
                          onSeek: PlatformUtils.isDesktop
                              ? (position) =>
                                    controller.seekTo(position, isSeek: false)
                              : null,
                        ),
                      ),
                    if (videoDetailController.showDmTrendChart.value)
                      if (videoDetailController.dmTrend.value?.dataOrNull
                          case final list?)
                        buildDmChart(primary, list, videoDetailController, 4.5),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: buildBottomControl()),
              if (!controller.isFileSource && !controller.isDesktopPip)
                SizedBox(
                  width: _widgetWidth(isFullScreen),
                  height: _widgetHeight,
                  child: IconButton(
                    tooltip: '视频标记',
                    padding: EdgeInsets.zero,
                    onPressed: () => _showBookmarkSheet(context),
                    icon: const Icon(
                      Icons.bookmark_add_outlined,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
