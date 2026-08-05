import 'package:flutter/material.dart';

class WebQrScanSourcePanel extends StatelessWidget {
  const WebQrScanSourcePanel({
    super.key,
    required this.onCamera,
    required this.onImage,
    required this.onManual,
    this.enabled = true,
  });

  final VoidCallback onCamera;
  final VoidCallback onImage;
  final VoidCallback onManual;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('读取网页登录二维码', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '仅接受 B 站官方网页生成的登录二维码，扫码后仍需你手动确认授权。',
              style: TextStyle(color: colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: enabled ? onCamera : null,
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: const Text('摄像头扫描'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onImage : null,
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('从相册识别'),
                ),
                OutlinedButton.icon(
                  onPressed: enabled ? onManual : null,
                  icon: const Icon(Icons.content_paste_outlined),
                  label: const Text('手动粘贴'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
