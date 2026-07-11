import 'package:pili_plus/models_new/web_qr_auth/scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebQrAuthScene.fromJson', () {
    test('parses target, environment and risk fields', () {
      final scene = WebQrAuthScene.fromJson({
        'app': {
          'title': 'Chrome 浏览器',
          'description': 'Windows 网页端',
          'icon': 'https://example.com/icon.png',
        },
        'transient': true,
        'obtain_env': true,
        'env_show_list': [
          {'env_key': 'private', 'env_desc': '私人设备'},
          {'env_key': 'public', 'env_desc': '公共设备'},
        ],
        'location_diff': true,
        'qrcode_location': '上海市',
        'verify_tel': true,
      });

      expect(scene.target.title, 'Chrome 浏览器');
      expect(scene.target.description, 'Windows 网页端');
      expect(scene.allowTransient, isTrue);
      expect(scene.requiresEnvironment, isTrue);
      expect(scene.environments, hasLength(2));
      expect(scene.environments.last.key, 'public');
      expect(scene.locationDiffers, isTrue);
      expect(scene.location, '上海市');
      expect(scene.requiresPhoneVerification, isTrue);
    });

    test('uses safe defaults for optional fields', () {
      final scene = WebQrAuthScene.fromJson({
        'app': null,
        'env_show_list': [
          null,
          {'env_key': '', 'env_desc': 'invalid'},
        ],
      });

      expect(scene.target.title, '哔哩哔哩网页端');
      expect(scene.environments, isEmpty);
      expect(scene.allowTransient, isFalse);
      expect(scene.requiresPhoneVerification, isFalse);
    });

    test('rejects non-map response data', () {
      expect(
        () => WebQrAuthScene.fromJson(const ['invalid']),
        throwsFormatException,
      );
    });

    test('rejects required environment without valid options', () {
      expect(
        () => WebQrAuthScene.fromJson({
          'obtain_env': true,
          'env_show_list': const [],
        }),
        throwsFormatException,
      );
    });
  });
}
