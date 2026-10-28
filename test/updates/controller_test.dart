import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_backyard/features/app_updates/data/release_config.dart';
import 'package:music_backyard/features/app_updates/data/update_repository.dart';
import 'package:music_backyard/features/app_updates/domain/release_track.dart';
import 'package:music_backyard/features/app_updates/domain/update_info.dart';
import 'package:music_backyard/features/app_updates/domain/update_status.dart';
import 'package:music_backyard/features/app_updates/platform/update_platform.dart';
import 'package:music_backyard/features/app_updates/presentation/app_updates_controller.dart';

class FakePlatform implements UpdatePlatform {
  InstalledRelease installed = const InstalledRelease('1.0.0', 1, 'direct');
  int installs = 0;
  String installResult = 'started';
  bool playAvailable = false;
  @override
  Future<InstalledRelease> installedRelease() async => installed;
  @override
  Future<bool> checkPlay() async => playAvailable;
  @override
  Future<void> installPlay() async {
    installs++;
  }

  @override
  Future<String> installApk(String path, UpdateInfo info) async {
    installs++;
    return installResult;
  }

  @override
  Future<void> openStore(Uri uri) async {}
}

class FeedAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final bytes = utf8.encode('signed fixture content');
  int status = 200;
  bool stallDownload = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    if (options.uri.path.endsWith('.apk')) {
      if (stallDownload) {
        final stream = StreamController<Uint8List>();
        stream.onListen = () =>
            stream.add(Uint8List.fromList(bytes.sublist(0, 3)));
        stream.onCancel = () => stream.close();
        return ResponseBody(stream.stream, 200);
      }
      return ResponseBody.fromBytes(bytes, 200);
    }
    final beta = options.uri.path.contains('beta');
    return ResponseBody.fromString(
      jsonEncode({
        'version': beta ? '1.2.0-beta.1' : '1.1.1',
        'buildNumber': beta ? 12 : 11,
        'platform': 'android',
        'channel': 'direct',
        'track': beta ? 'beta' : 'stable',
        'downloadUrl':
            'https://releases.example.test/${beta ? 'beta' : 'stable'}.apk',
        'sha256': sha256.convert(bytes).toString(),
        'sizeBytes': bytes.length,
        'releaseNotes': ['Verbeterd'],
        'mandatory': false,
      }),
      status,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FeedAdapter feed;
  late FakePlatform platform;
  late List<AppUpdatesController> controllers;
  var now = DateTime.utc(2026, 10, 28, 12);
  var connected = const UpdateNetwork(online: true, wifi: true);
  AppUpdatesController create({bool automatic = false}) {
    final config = ReleaseConfig(
      stableEndpoint: Uri.parse('https://releases.example.test/stable.json'),
      betaEndpoint: Uri.parse('https://releases.example.test/beta.json'),
      downloadHosts: {'releases.example.test'},
      automaticWifiDownload: automatic,
    );
    final controller = AppUpdatesController(
      config: config,
      platform: platform,
      network: () async => connected,
      temporaryDirectory: () async => root,
      clock: () => now,
      enableScheduling: false,
      repositories: (track) => UpdateRepository(
        endpoint: config.endpoint(track),
        trustedHosts: config.downloadHosts,
        track: track,
        dio: Dio()..httpClientAdapter = feed,
      ),
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('musicbackyard-controller');
    feed = FeedAdapter();
    platform = FakePlatform();
    controllers = [];
    now = DateTime.utc(2026, 10, 28, 12);
    connected = const UpdateNetwork(online: true, wifi: true);
  });
  tearDown(() async {
    for (final c in controllers) {
      c.dispose();
    }
    await root.delete(recursive: true);
  });
  test('Automatic wifi downloads verify content and never install without an action', () async {
    final c = create(automatic: true);
    await c.initialize();
    expect(c.status, UpdateStatus.downloaded);
    expect(c.received, feed.bytes.length);
    expect(platform.installs, 0);
    expect(await c.apk!.readAsBytes(), feed.bytes);
    await c.install();
    expect(platform.installs, 1);
    expect(c.status, UpdateStatus.installStarted);
  });
  test('Cellular checks do not automatically download APKs', () async {
    connected = const UpdateNetwork(online: true, wifi: false);
    final c = create(automatic: true);
    await c.initialize();
    expect(c.status, UpdateStatus.available);
    expect(feed.requests.length, 1);
    await c.download();
    expect(c.status, UpdateStatus.downloaded);
  });
  test(
    'Interval is respected across resume; manual check bypasses it',
    () async {
      final c = create();
      await c.initialize();
      await c.onResume();
      expect(feed.requests.length, 1);
      await c.check(force: true);
      expect(feed.requests.length, 2);
      now = now.add(const Duration(hours: 7));
      await c.onResume();
      expect(feed.requests.length, 3);
    },
  );
  test(
    'Track changes fetch only the selected feed and persist the choice',
    () async {
      final c = create();
      await c.initialize();
      await c.setTrack(ReleaseTrack.beta);
      expect(c.track, ReleaseTrack.beta);
      expect(c.update!.track, 'beta');
      expect(c.update!.buildNumber, 12);
      final other = create();
      await other.initialize();
      expect(other.track, ReleaseTrack.beta);
      expect(feed.requests.length, 2);
      expect(other.status, UpdateStatus.available);
    },
  );
  test(
    'A beta installation never downgrades to an older stable build',
    () async {
      platform.installed = const InstalledRelease('1.2.0-beta.1', 12, 'direct');
      final c = create();
      await c.initialize();
      expect(c.status, UpdateStatus.upToDate);
      expect(c.hasUpdate, isFalse);
      await c.download();
      expect(feed.requests.length, 1);
    },
  );
  test('Valid downloaded APK is recovered after restarting without a network fetch', () async {
    final first = create(automatic: true);
    await first.initialize();
    expect(first.status, UpdateStatus.downloaded);
    final second = create();
    await second.initialize();
    expect(second.status, UpdateStatus.downloaded);
    expect(second.apk, isNotNull);
    expect(feed.requests.length, 2);
  });
  test('Offline failures preserve last successful timestamp and keep app controllable', () async {
    final c = create();
    await c.initialize();
    final successful = c.lastChecked;
    connected = const UpdateNetwork(online: false, wifi: false);
    await c.check(force: true);
    expect(c.status, UpdateStatus.error);
    expect(c.lastChecked, successful);
    expect(c.busy, isFalse);
    expect(platform.installs, 0);
  });
  test(
    'Play installations use the Play gateway and do not request APK feeds',
    () async {
      platform.installed = const InstalledRelease('1.0.0', 1, 'play');
      platform.playAvailable = true;
      final c = create();
      await c.initialize();
      expect(c.status, UpdateStatus.available);
      await c.download();
      expect(feed.requests, isEmpty);
      await c.install();
      expect(platform.installs, 1);
    },
  );
  test(
    'Source-install permission denial keeps the verified APK for retry',
    () async {
      final c = create(automatic: true);
      await c.initialize();
      platform.installResult = 'permissionRequired';
      await c.install();
      expect(c.status, UpdateStatus.permissionRequired);
      platform.installResult = 'started';
      await c.install();
      expect(c.status, UpdateStatus.installStarted);
      expect(platform.installs, 2);
    },
  );
  test('Cancellation interrupts a stalled download and prevents auto retry on resume', () async {
    feed.stallDownload = true;
    final c = create();
    await c.initialize();
    final downloading = c.download();
    for (var i = 0; i < 100 && c.received == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(c.received, greaterThan(0));
    c.cancel();
    await downloading.timeout(const Duration(seconds: 3));
    expect(c.status, UpdateStatus.interrupted);
    expect(c.apk, isNull);
    expect(await root.list(recursive: true).where((f) => f is File).length, 0);
    await c.setAutomaticDownloads(true);
    await c.onResume();
    expect(c.status, UpdateStatus.interrupted);
  });
}
