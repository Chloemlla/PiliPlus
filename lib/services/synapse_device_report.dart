import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pili_plus/utils/device_utils.dart';
import 'package:pili_plus/utils/permission_handler.dart';

/// Collects the device snapshot and the granted-permission list that the
/// Synapse vault attaches to each bound Bilibili account.
///
/// Everything here is best-effort: an unavailable channel or an unreadable
/// identifier degrades to a missing key instead of failing the whole upload.
abstract final class SynapseDeviceReport {
  static Future<Map<String, dynamic>> collectDeviceInfo() async {
    final result = <String, dynamic>{};
    try {
      final info = await PackageInfo.fromPlatform();
      result.addAll(<String, dynamic>{
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'appVersion': info.version,
        'appBuild': info.buildNumber,
        'packageName': info.packageName,
      });
    } catch (_) {}
    try {
      result['formFactor'] = DeviceUtils.platformName;
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      result['screenWidth'] = size.width.round();
      result['screenHeight'] = size.height.round();
      result['pixelRatio'] = view.devicePixelRatio;
    } catch (_) {}
    try {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;
      if (locales.isNotEmpty) result['locale'] = locales.first.toLanguageTag();
    } catch (_) {}

    try {
      if (Platform.isAndroid) {
        result.addAll(_androidSnapshot(await DeviceInfoPlugin().androidInfo));
      } else if (Platform.isIOS || Platform.isMacOS) {
        result.addAll(_iosSnapshot(await DeviceInfoPlugin().iosInfo));
      } else if (Platform.isWindows) {
        result.addAll(_windowsSnapshot(await DeviceInfoPlugin().windowsInfo));
      } else if (Platform.isLinux) {
        result.addAll(_linuxSnapshot(await DeviceInfoPlugin().linuxInfo));
      }
    } catch (_) {}

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isNotEmpty) {
        result['networkType'] = connectivity.map((c) => c.name).join(',');
      }
    } catch (_) {}

    return result;
  }

  static Future<Map<String, String>> collectGrantedPermissions() async {
    if (!Platform.isAndroid) return const {};
    const permissions = <Permission>[
      Permission.notification,
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
      Permission.camera,
      Permission.microphone,
      Permission.contacts,
      Permission.location,
      Permission.phone,
      Permission.sms,
      Permission.calendar,
      Permission.bluetooth,
      Permission.sensors,
      Permission.nearbyWifiDevices,
      Permission.manageExternalStorage,
      Permission.systemAlertWindow,
      Permission.requestInstallPackages,
      Permission.ignoreBatteryOptimizations,
      Permission.accessNotificationPolicy,
    ];
    final result = <String, String>{};
    for (final permission in permissions) {
      try {
        result[permission.toString()] = (await permission.status).toString();
      } catch (_) {
        // A permission not declared in the manifest (or unsupported on this
        // SDK level) is skipped rather than reported as denied.
      }
    }
    return result;
  }

  static Map<String, dynamic> _androidSnapshot(AndroidDeviceInfo info) => <String, dynamic>{
    'model': info.model,
    'brand': info.brand,
    'manufacturer': info.manufacturer,
    'device': info.device,
    'hardware': info.hardware,
    'product': info.product,
    'androidId': info.id,
    'serial': info.serialNumber,
    'fingerprint': info.fingerprint,
    'baseOS': info.version.baseOS,
    'sdkInt': info.version.sdkInt,
    'osRelease': info.version.release,
    'osCodename': info.version.codename,
    'supportedAbis': info.supportedAbis,
    'isPhysicalDevice': info.isPhysicalDevice,
    'isLowRamDevice': info.isLowRamDevice,
    'display': info.display,
    'type': info.type,
  };

  static Map<String, dynamic> _iosSnapshot(IosDeviceInfo info) => <String, dynamic>{
    'model': info.model,
    'systemName': info.systemName,
    'systemVersion': info.systemVersion,
    'identifierForVendor': info.identifierForVendor,
    'isPhysicalDevice': info.isPhysicalDevice,
    'utsnameMachine': info.utsname.machine,
  };

  static Map<String, dynamic> _windowsSnapshot(WindowsDeviceInfo info) => <String, dynamic>{
    'computerName': info.computerName,
    'deviceId': info.deviceId,
    'systemManufacturer': info.systemManufacturer,
    'systemProductName': info.systemProductName,
    'windowsBuild': info.windowsVersion.build,
  };

  static Map<String, dynamic> _linuxSnapshot(LinuxDeviceInfo info) => <String, dynamic>{
    'name': info.name,
    'versionId': info.versionId,
    'prettyName': info.prettyName,
    'machineId': info.machineId,
  };
}
