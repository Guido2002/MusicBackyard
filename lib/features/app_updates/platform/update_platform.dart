import 'dart:io';

import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/update_info.dart';
import 'android_install_service.dart';

class InstalledRelease {
  const InstalledRelease(this.version, this.build, this.distribution);
  final String version, distribution;
  final int build;
}

abstract interface class UpdatePlatform {
  Future<InstalledRelease> installedRelease();
  Future<bool> checkPlay();
  Future<void> installPlay();
  Future<String> installApk(String path, UpdateInfo info);
  Future<void> openStore(Uri uri);
}

class DeviceUpdatePlatform implements UpdatePlatform {
  final installer = AndroidInstallService();
  @override
  Future<InstalledRelease> installedRelease() async {
    final info = await PackageInfo.fromPlatform();
    return InstalledRelease(
      info.version,
      int.tryParse(info.buildNumber) ?? 0,
      Platform.isAndroid
          ? await installer.distribution()
          : Platform.isIOS
          ? 'appstore'
          : 'unsupported',
    );
  }

  @override
  Future<bool> checkPlay() async =>
      (await InAppUpdate.checkForUpdate()).updateAvailability ==
      UpdateAvailability.updateAvailable;
  @override
  Future<void> installPlay() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
    } else {
      await openStore(
        Uri.https('play.google.com', '/store/apps/details', {
          'id': 'nl.musicbackyard.music_backyard',
        }),
      );
    }
  }

  @override
  Future<String> installApk(String path, UpdateInfo info) =>
      installer.install(path, info);
  @override
  Future<void> openStore(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Store unavailable');
    }
  }
}
