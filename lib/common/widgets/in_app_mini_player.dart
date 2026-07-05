import 'dart:math' as math;

import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit_video/media_kit_video.dart';

typedef InAppMiniPlayerOpenSource = Future<void> Function(int progress);

class InAppMiniPlayerEntry {
  const InAppMiniPlayerEntry({
    required this.id,
    required this.controller,
    required this.title,
    required this.aspectRatio,
    required this.videoWidth,
    required this.videoHeight,
    this.onOpenSource,
  });

  final int id;
  final PlPlayerController controller;
  final String title;
  final double aspectRatio;
  final int videoWidth;
  final int videoHeight;
  final InAppMiniPlayerOpenSource? onOpenSource;
}

class InAppMiniPlayerService {
  InAppMiniPlayerService._();

  static final instance = InAppMiniPlayerService._();

  final Rxn<InAppMiniPlayerEntry> entry = Rxn<InAppMiniPlayerEntry>();
  int _id = 0;

  bool get isActive => entry.value != null;

  Future<bool> show({
    required PlPlayerController sourceController,
    required String title,
    required InAppMiniPlayerOpenSource? onOpenSource,
    bool isLive = false,
    bool pauseSource = true,
    int? aid,
    String? bvid,
    int? cid,
    int? epid,
    int? seasonId,
    int? pgcType,
    VideoType? videoType,
  }) async {
    final sourcePlayer = sourceController.videoPlayerController;
    if (sourcePlayer == null) {
      SmartDialog.showToast('播放器未就绪');
      return false;
    }

    late final DataSource dataSource;
    try {
      dataSource = sourceController.dataSource.copy();
    } catch (_) {
      SmartDialog.showToast('无法获取播放源');
      return false;
    }

    final wasPlaying =
        sourcePlayer.state.playing || sourceController.playerStatus.isPlaying;
    final position = isLive ? null : sourcePlayer.state.position;
    final duration = sourceController.durationInMilliseconds > 0
        ? Duration(milliseconds: sourceController.durationInMilliseconds)
        : sourcePlayer.state.duration;
    final playbackSpeed = sourceController.playbackSpeed;
    final videoWidth = sourcePlayer.state.width == 0
        ? sourceController.width ?? 16
        : sourcePlayer.state.width;
    final videoHeight = sourcePlayer.state.height == 0
        ? sourceController.height ?? 9
        : sourcePlayer.state.height;
    final aspectRatio = videoWidth > 0 && videoHeight > 0
        ? videoWidth / videoHeight
        : 16 / 9;

    await close();

    if (pauseSource && wasPlaying) {
      await sourceController.pause(notify: false, isInterrupt: true);
    }

    final controller = PlPlayerController.detached(isLive: isLive)
      ..volume.value = sourceController.volume.value
      ..onlyPlayAudio.value = sourceController.onlyPlayAudio.value
      ..videoFit.value = sourceController.videoFit.value;

    await controller.setDataSource(
      dataSource,
      isLive: isLive,
      autoplay: wasPlaying,
      seekTo: position,
      duration: isLive ? null : duration,
      isVertical: sourceController.isVertical,
      aid: aid,
      bvid: bvid,
      cid: cid,
      epid: epid,
      seasonId: seasonId,
      pgcType: pgcType,
      videoType: videoType,
      width: videoWidth,
      height: videoHeight,
    );

    if (controller.videoController == null) {
      controller.dispose();
      if (pauseSource && wasPlaying) {
        await sourceController.play();
      }
      SmartDialog.showToast('小窗创建失败');
      return false;
    }

    if (!isLive && playbackSpeed != controller.playbackSpeed) {
      await controller.setPlaybackSpeed(playbackSpeed);
    }

    entry.value = InAppMiniPlayerEntry(
      id: ++_id,
      controller: controller,
      title: title.trim().isEmpty ? '正在播放' : title,
      aspectRatio: aspectRatio,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      onOpenSource: onOpenSource,
    );
    return true;
  }

  Future<void> close() async {
    final current = entry.value;
    if (current == null) {
      return;
    }
    entry.value = null;
    current.controller.dispose();
  }

  Future<void> openSource() async {
    final current = entry.value;
    if (current == null) {
      return;
    }
    final progress = current.controller.positionInMilliseconds;
    final onOpenSource = current.onOpenSource;
    await close();
    await onOpenSource?.call(progress);
  }
}

class InAppMiniPlayerLayer extends StatelessWidget {
  const InAppMiniPlayerLayer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entry = InAppMiniPlayerService.instance.entry.value;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          child,
          if (entry != null) _MiniPlayerWindow(entry, key: ValueKey(entry.id)),
        ],
      );
    });
  }
}

class _MiniPlayerWindow extends StatefulWidget {
  const _MiniPlayerWindow(this.entry, {super.key});

  final InAppMiniPlayerEntry entry;

  @override
  State<_MiniPlayerWindow> createState() => _MiniPlayerWindowState();
}

class _MiniPlayerWindowState extends State<_MiniPlayerWindow> {
  static const _margin = 12.0;
  static const _buttonSize = 32.0;
  Offset? _offset;

  InAppMiniPlayerService get _service => InAppMiniPlayerService.instance;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.viewPadding;
    final windowSize = _calcWindowSize(screenSize, padding);
    final defaultOffset = Offset(
      screenSize.width - padding.right - windowSize.width - _margin,
      screenSize.height - padding.bottom - windowSize.height - 92,
    );
    final offset = _clampOffset(
      _offset ?? defaultOffset,
      screenSize,
      windowSize,
      padding,
    );
    _offset = offset;

    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: windowSize.width,
      height: windowSize.height,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = _clampOffset(
              offset + details.delta,
              screenSize,
              windowSize,
              padding,
            );
          });
        },
        child: Material(
          elevation: 10,
          color: Colors.black,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(child: _video),
              _topBar,
              _bottomBar,
            ],
          ),
        ),
      ),
    );
  }

  Widget get _video {
    final videoController = widget.entry.controller.videoController;
    if (videoController == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: widget.entry.videoWidth.toDouble(),
          height: widget.entry.videoHeight.toDouble(),
          child: SimpleVideo(controller: videoController, fill: Colors.black),
        ),
      ),
    );
  }

  Widget get _topBar {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 4),
                child: Text(
                  widget.entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (widget.entry.onOpenSource != null)
              _iconButton(
                tooltip: '打开',
                icon: Icons.open_in_full,
                onPressed: _service.openSource,
              ),
            _iconButton(
              tooltip: '关闭',
              icon: Icons.close,
              onPressed: _service.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget get _bottomBar {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.72), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 31,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Obx(() {
                  final isPlaying =
                      widget.entry.controller.playerStatus.isPlaying;
                  return _iconButton(
                    tooltip: isPlaying ? '暂停' : '播放',
                    icon: isPlaying ? Icons.pause : Icons.play_arrow,
                    onPressed: _togglePlay,
                  );
                }),
              ),
            ),
            Obx(() {
              final controller = widget.entry.controller;
              final duration = controller.duration.value;
              final position = controller.position.value;
              return LinearProgressIndicator(
                minHeight: 2,
                value: duration <= 0
                    ? null
                    : (position / duration).clamp(0.0, 1.0).toDouble(),
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                color: Colors.white,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox.square(
      dimension: _buttonSize,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Future<void> _togglePlay() {
    final controller = widget.entry.controller;
    if (controller.playerStatus.isPlaying) {
      return controller.pause();
    }
    return controller.play(repeat: controller.playerStatus.isCompleted);
  }

  Size _calcWindowSize(Size screenSize, EdgeInsets padding) {
    final maxWidth = math.max(
      120.0,
      screenSize.width - padding.left - padding.right - _margin * 2,
    );
    final baseWidth = screenSize.width < 600
        ? screenSize.width * 0.58
        : screenSize.width * 0.32;
    var width = baseWidth.clamp(180.0, math.min(360.0, maxWidth)).toDouble();
    var height = width / widget.entry.aspectRatio;
    final maxHeight = math.max(
      120.0,
      (screenSize.height - padding.top - padding.bottom) * 0.42,
    );
    if (height > maxHeight) {
      height = maxHeight;
      width = height * widget.entry.aspectRatio;
    }
    return Size(width, height);
  }

  Offset _clampOffset(
    Offset offset,
    Size screenSize,
    Size windowSize,
    EdgeInsets padding,
  ) {
    final minX = padding.left + _margin;
    final maxX = math.max(
      minX,
      screenSize.width - padding.right - windowSize.width - _margin,
    );
    final minY = padding.top + _margin;
    final maxY = math.max(
      minY,
      screenSize.height - padding.bottom - windowSize.height - _margin,
    );
    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }
}
