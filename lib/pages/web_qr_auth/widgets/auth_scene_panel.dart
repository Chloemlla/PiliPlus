import 'package:pili_plus/common/widgets/image/network_img_layer.dart';
import 'package:pili_plus/models_new/web_qr_auth/scene.dart';
import 'package:pili_plus/pages/web_qr_auth/controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WebQrAuthScenePanel extends StatelessWidget {
  const WebQrAuthScenePanel({
    super.key,
    required this.controller,
    required this.scene,
  });

  final WebQrAuthController controller;
  final WebQrAuthScene scene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    NetworkImgLayer(
                      src: scene.target.iconUrl,
                      width: 48,
                      height: 48,
                      getPlaceHolder: () => CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.secondaryContainer,
                        child: const Icon(Icons.computer_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scene.target.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            scene.target.description ?? '请求登录哔哩哔哩网页端',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _InfoRow(label: '授权账号', value: 'UID ${controller.accountMid}'),
                if (scene.location != null)
                  _InfoRow(label: '登录位置', value: scene.location!),
              ],
            ),
          ),
        ),
        if (scene.locationDiffers) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '检测到登录位置不同。请确认电脑在你身边，避免账号被他人登录。',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (scene.environments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      scene.requiresEnvironment ? '选择登录环境' : '登录环境',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Obx(
                    () => RadioGroup<String>(
                      groupValue: controller.selectedEnvironment.value,
                      onChanged: (value) =>
                          controller.selectedEnvironment.value = value,
                      child: Column(
                        children: scene.environments
                            .map(
                              (environment) => RadioListTile<String>(
                                value: environment.key,
                                title: Text(environment.description),
                                dense: true,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (scene.allowTransient) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Obx(
              () => SwitchListTile(
                value: controller.transientLogin.value,
                onChanged: (value) => controller.transientLogin.value = value,
                title: const Text('短期登录'),
                subtitle: const Text('本次网页登录仅保持 24 小时，适合临时或公共设备。'),
                secondary: const Icon(Icons.timer_outlined),
              ),
            ),
          ),
        ],
        if (scene.requiresPhoneVerification) ...[
          const SizedBox(height: 12),
          _PhoneVerificationCard(controller: controller),
        ],
        const SizedBox(height: 20),
        Obx(
          () => FilledButton.icon(
            onPressed: controller.stage.value == WebQrAuthStage.ready
                ? controller.confirm
                : null,
            icon: const Icon(Icons.login_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('确认网页登录'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '确认后，二维码所在的网页将获得当前账号的登录状态。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _PhoneVerificationCard extends StatelessWidget {
  const _PhoneVerificationCard({required this.controller});

  final WebQrAuthController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 8),
                Text('手机号验证', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Obx(
              () => Text(
                controller.maskedPhone.value == null
                    ? 'B 站要求验证当前账号绑定的手机号。'
                    : '验证码将发送至 ${controller.maskedPhone.value}',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.smsCodeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '短信验证码',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(
                  () => OutlinedButton(
                    onPressed:
                        controller.smsSending.value ||
                            controller.smsCooldown.value > 0
                        ? null
                        : controller.sendSms,
                    child: Text(
                      controller.smsCooldown.value > 0
                          ? '${controller.smsCooldown.value}s'
                          : controller.smsSending.value
                          ? '发送中'
                          : '发送验证码',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Obx(
              () => SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      controller.phoneVerified.value ||
                          controller.smsVerifying.value
                      ? null
                      : controller.verifySms,
                  icon: Icon(
                    controller.phoneVerified.value
                        ? Icons.check_circle_outline
                        : Icons.sms_outlined,
                  ),
                  label: Text(
                    controller.phoneVerified.value
                        ? '手机号已验证'
                        : controller.smsVerifying.value
                        ? '验证中'
                        : '验证短信验证码',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
