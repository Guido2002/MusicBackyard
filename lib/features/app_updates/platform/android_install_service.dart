import 'package:flutter/services.dart';

import '../domain/update_info.dart';

class AndroidInstallService {
  static const channel = MethodChannel('nl.musicbackyard/updates');
  Future<String> distribution() async =>
      await channel.invokeMethod<String>('distribution') ?? 'play';
  Future<String> install(String path, UpdateInfo info) async =>
      await channel.invokeMethod<String>('install', {
        'path': path,
        'sha256': info.sha256,
        'buildNumber': info.buildNumber,
      }) ??
      'error';
}
