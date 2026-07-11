import 'package:pili_plus/common/widgets/view_safe_area.dart';
import 'package:pili_plus/pages/web_qr_auth/controller.dart';
import 'package:pili_plus/pages/web_qr_auth/widgets/auth_scene_panel.dart';
import 'package:pili_plus/pages/web_qr_auth/widgets/scan_source_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class WebQrAuthPage extends StatefulWidget {
  const WebQrAuthPage({super.key});

  @override
  State<WebQrAuthPage> createState() => _WebQrAuthPageState();
}

class _WebQrAuthPageState extends State<WebQrAuthPage> {
  late final WebQrAuthController controller = Get.put(WebQrAuthController());

  @override
  void dispose() {
    Get.delete<WebQrAuthController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描网页登录'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: '手动粘贴二维码链接',
              onPressed: controller.canStartInput ? _showManualInput : null,
              icon: const Icon(Icons.content_paste_outlined),
            ),
          ),
        ],
      ),
      body: ViewSafeArea(
        child: Obx(
          () => AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _buildBody(controller.stage.value),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(WebQrAuthStage stage) {
    return switch (stage) {
      .idle => _scrollable(
        key: const ValueKey('idle'),
        children: [
          Icon(
            Icons.qr_code_2_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '登录电脑上的哔哩哔哩网页',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'PiliPlus 将使用当前主账号读取登录目标，只有在你确认后才会授权。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          _sourcePanel(),
        ],
      ),
      .loading || .confirming => Center(
        key: ValueKey(stage),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Obx(() => Text(controller.message.value)),
          ],
        ),
      ),
      .ready => _scrollable(
        key: const ValueKey('ready'),
        children: [
          if (controller.scene.value case final scene?)
            WebQrAuthScenePanel(controller: controller, scene: scene),
          const SizedBox(height: 18),
          _sourcePanel(),
        ],
      ),
      .success => Center(
        key: const ValueKey('success'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                controller.message.value,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      .error => _scrollable(
        key: const ValueKey('error'),
        children: [
          Icon(
            Icons.error_outline,
            size: 68,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 14),
          Obx(
            () => Text(
              controller.message.value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: controller.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('重新选择二维码'),
          ),
          const SizedBox(height: 18),
          _sourcePanel(),
        ],
      ),
    };
  }

  Widget _sourcePanel() => WebQrScanSourcePanel(
    onCamera: controller.scanCamera,
    onImage: controller.scanImage,
    onManual: _showManualInput,
    enabled: controller.canStartInput,
  );

  Widget _scrollable({required Key key, required List<Widget> children}) {
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      children: children,
    );
  }

  Future<void> _showManualInput() async {
    final textController = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴网页登录二维码链接'),
        content: TextField(
          controller: textController,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            hintText:
                'https://account.bilibili.com/h5/account-h5/auth/scan-web?...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: '从剪贴板粘贴',
              onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text case final text?) {
                  textController.text = text;
                  textController.selection = TextSelection.collapsed(
                    offset: text.length,
                  );
                }
              },
              icon: const Icon(Icons.content_paste_outlined),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (value != null) {
      await controller.submitManualUrl(value);
    }
  }
}
