import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/release_config.dart';
import '../data/update_manifest_model.dart';
import '../data/update_repository.dart';
import '../domain/release_track.dart';
import '../domain/update_info.dart';
import '../domain/update_status.dart';
import '../platform/update_platform.dart';

final updatesProvider = Provider<AppUpdatesController>((ref) {
  final c = AppUpdatesController();
  ref.onDispose(c.dispose);
  return c;
});

class UpdateNetwork {
  const UpdateNetwork({required this.online, required this.wifi});
  final bool online, wifi;
  static Future<UpdateNetwork> current() async {
    final states = await Connectivity().checkConnectivity();
    return UpdateNetwork(
      online: states.any((v) => v != ConnectivityResult.none),
      wifi: states.contains(ConnectivityResult.wifi),
    );
  }
}

class AppUpdatesController extends ChangeNotifier {
  AppUpdatesController({
    ReleaseConfig? config,
    UpdatePlatform? platform,
    Future<UpdateNetwork> Function()? network,
    Future<SharedPreferences> Function()? preferences,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
    this.repositories,
    this.enableScheduling = true,
  }) : config = config ?? ReleaseConfig.fromEnvironment(),
       platform = platform ?? DeviceUpdatePlatform(),
       network = network ?? UpdateNetwork.current,
       preferences = preferences ?? SharedPreferences.getInstance,
       temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       clock = clock ?? DateTime.now;
  final ReleaseConfig config;
  final UpdatePlatform platform;
  final Future<UpdateNetwork> Function() network;
  final Future<SharedPreferences> Function() preferences;
  final Future<Directory> Function() temporaryDirectory;
  final DateTime Function() clock;
  final UpdateRepository Function(ReleaseTrack)? repositories;
  final bool enableScheduling;
  final machine = UpdateStateMachine();
  UpdateStatus get status => machine.status;
  UpdateInfo? update;
  File? apk;
  CancelToken? cancellation, _checkingCancellation;
  SharedPreferences? prefs;
  String version = '', build = '', channel = '';
  ReleaseTrack track = ReleaseTrack.stable;
  bool automaticWifiDownload = false, initialized = false;
  bool _disposed = false,
      _foreground = true,
      _workingCheck = false,
      _downloadWasAutomatic = false;
  Future<void>? _initialization;
  Timer? _timer;
  DateTime? lastChecked;
  int received = 0, total = 0;
  double bytesPerSecond = 0;
  UpdateRepository? _repository;
  UpdateRepository get repository => _repository ??=
      repositories?.call(track) ??
      UpdateRepository(
        endpoint: config.endpoint(track),
        trustedHosts: config.downloadHosts,
        track: track,
        githubRepository: config.githubRepository,
      );
  String get _cacheKey => 'updates:v2:${track.name}:${config.endpoint(track)}';
  bool get busy =>
      !initialized ||
      _workingCheck ||
      [UpdateStatus.downloading, UpdateStatus.preparing].contains(status);
  bool get hasUpdate =>
      update != null && update!.buildNumber > (int.tryParse(build) ?? 0) ||
      channel == 'play' && status == UpdateStatus.available;
  bool get canChooseTrack => channel == 'direct' && config.hasBeta;

  void _emit() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void move(UpdateStatus next) {
    if (_disposed) {
      return;
    }
    machine.move(next);
    _emit();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final installed = await platform.installedRelease();
      if (_disposed) {
        return;
      }
      version = installed.version;
      build = '${installed.build}';
      channel = installed.distribution;
      prefs = await preferences();
      if (_disposed) {
        return;
      }
      track =
          ReleaseTrack.values
              .where((v) => v.name == prefs!.getString('updates:track'))
              .firstOrNull ??
          config.defaultTrack;
      if (!config.hasBeta) {
        track = ReleaseTrack.stable;
      }
      automaticWifiDownload =
          prefs!.getBool('updates:autoWifi') ?? config.automaticWifiDownload;
      initialized = true;
      _restoreCachedManifest();
      _emit();
      await check();
    } catch (_) {
      initialized = true;
      if (!_disposed && status == UpdateStatus.idle) {
        move(UpdateStatus.unconfigured);
      }
    }
  }

  void _restoreCachedManifest() {
    lastChecked = DateTime.tryParse(prefs?.getString('$_cacheKey:last') ?? '');
    if (lastChecked == null) {
      return;
    }
    try {
      if (channel == 'direct' && repository.configured) {
        update = UpdateManifestModel.parse(
          jsonDecode(prefs!.getString('$_cacheKey:manifest')!),
          platform: 'android',
          channel: 'direct',
          trustedHosts: config.downloadHosts,
          track: track,
          githubRepository: config.githubRepository,
        );
        move(UpdateStatus.checking);
        move(
          update!.buildNumber > (int.tryParse(build) ?? 0)
              ? UpdateStatus.available
              : UpdateStatus.upToDate,
        );
      } else if (channel == 'play') {
        move(UpdateStatus.checking);
        move(
          prefs!.getBool('$_cacheKey:playAvailable') == true
              ? UpdateStatus.available
              : UpdateStatus.upToDate,
        );
      }
    } catch (_) {
      lastChecked = null;
      update = null;
      machine.reset();
    }
  }

  Future<void> check({bool force = false}) async {
    if (_disposed) {
      return;
    }
    if (!initialized) {
      await initialize();
      return;
    }
    if (busy) {
      return;
    }
    if (channel == 'unsupported' ||
        channel == 'appstore' ||
        channel == 'direct' && !repository.configured) {
      if (status == UpdateStatus.idle || status == UpdateStatus.unconfigured) {
        move(UpdateStatus.unconfigured);
      }
      return;
    }
    _workingCheck = true;
    _timer?.cancel();
    _emit();
    try {
      final fresh =
          lastChecked != null &&
          clock().difference(lastChecked!) >= Duration.zero &&
          clock().difference(lastChecked!) < config.interval;
      if (force || !fresh) {
        final connection = await network();
        if (_disposed) {
          return;
        }
        move(UpdateStatus.checking);
        if (!connection.online) {
          throw const SocketException('Offline');
        }
        if (channel == 'play') {
          final available = await platform.checkPlay();
          if (_disposed) {
            return;
          }
          move(available ? UpdateStatus.available : UpdateStatus.upToDate);
          await prefs?.setBool('$_cacheKey:playAvailable', available);
        } else {
          final info = await repository.check(
            cancel: _checkingCancellation = CancelToken(),
          );
          if (_disposed) {
            return;
          }
          update = info;
          apk = null;
          move(
            info.buildNumber > (int.tryParse(build) ?? 0)
                ? UpdateStatus.available
                : UpdateStatus.upToDate,
          );
          await prefs?.setString(
            '$_cacheKey:manifest',
            jsonEncode(info.toJson()),
          );
        }
        lastChecked = clock();
        await prefs?.setString(
          '$_cacheKey:last',
          lastChecked!.toIso8601String(),
        );
      }
      if (channel == 'direct' && status == UpdateStatus.available) {
        await _restoreDownloadedApk();
      }
    } catch (_) {
      if (!_disposed && status == UpdateStatus.checking) {
        move(UpdateStatus.error);
      }
    } finally {
      _workingCheck = false;
      _emit();
    }
    if (!_disposed) {
      await _automaticDownload();
      _schedule();
    }
  }

  Future<File> _target() async {
    final root = await temporaryDirectory();
    return File(
      '${root.path}/musicbackyard-updates/update-${update!.buildNumber}.apk',
    );
  }

  Future<void> _restoreDownloadedApk() async {
    final file = await _target();
    if (!await file.exists()) {
      return;
    }
    try {
      await UpdateRepository.verify(file, update!);
      if (_disposed) {
        return;
      }
      apk = file;
      received = total = update!.sizeBytes;
      move(UpdateStatus.downloaded);
    } on FormatException {
      await file.delete();
    }
  }

  Future<void> _automaticDownload() async {
    if (_disposed ||
        busy ||
        !_foreground ||
        channel != 'direct' ||
        !automaticWifiDownload ||
        status != UpdateStatus.available ||
        update == null ||
        prefs?.getInt('$_cacheKey:cancelledBuild') == update!.buildNumber) {
      return;
    }
    try {
      final state = await network();
      if (state.online && state.wifi && !_disposed) {
        await download(automatic: true);
      }
    } catch (_) {
      /* Network discovery is best effort; manual updates remain available. */
    }
  }

  Future<void> download({bool automatic = false}) async {
    if (_disposed ||
        busy ||
        update == null ||
        channel != 'direct' ||
        ![
          UpdateStatus.available,
          UpdateStatus.interrupted,
          UpdateStatus.error,
        ].contains(status)) {
      return;
    }
    cancellation = CancelToken();
    _downloadWasAutomatic = automatic;
    received = 0;
    total = update!.sizeBytes;
    bytesPerSecond = 0;
    move(UpdateStatus.downloading);
    final watch = Stopwatch()..start();
    try {
      final target = await _target();
      apk = await repository.download(update!, target.parent, cancellation!, (
        count,
        size,
      ) {
        received = count;
        total = size;
        bytesPerSecond = watch.elapsedMilliseconds < 500
            ? 0
            : count / (watch.elapsedMilliseconds / 1000);
        _emit();
      });
      if (!_disposed) {
        move(UpdateStatus.downloaded);
      }
    } catch (error) {
      apk = null;
      if (!_disposed) {
        move(
          error is DioException && CancelToken.isCancel(error)
              ? UpdateStatus.interrupted
              : UpdateStatus.error,
        );
      }
    } finally {
      _downloadWasAutomatic = false;
    }
  }

  void cancel() {
    cancellation?.cancel('User cancelled');
    if (update != null) {
      unawaited(_rememberCancelledBuild(update!.buildNumber));
    }
  }

  Future<void> _rememberCancelledBuild(int buildNumber) async {
    try {
      await prefs?.setInt('$_cacheKey:cancelledBuild', buildNumber);
    } catch (_) {
      /* Cancellation must not depend on preference storage. */
    }
  }

  Future<void> setAutomaticDownloads(bool enabled) async {
    await prefs?.setBool('updates:autoWifi', enabled);
    automaticWifiDownload = enabled;
    if (!enabled && _downloadWasAutomatic) {
      cancel();
    }
    _emit();
    if (enabled) {
      await _automaticDownload();
    }
  }

  Future<void> setTrack(ReleaseTrack next) async {
    if (_disposed || busy || !canChooseTrack || next == track) {
      return;
    }
    await prefs?.setString('updates:track', next.name);
    _timer?.cancel();
    _repository?.dio.close(force: true);
    _repository = null;
    track = next;
    lastChecked = null;
    update = null;
    apk = null;
    machine.reset();
    _restoreCachedManifest();
    _emit();
    await check();
  }

  void onPause() {
    _foreground = false;
    _timer?.cancel();
  }

  Future<void> onResume() async {
    _foreground = true;
    await initialize();
    await check();
  }

  void _schedule() {
    if (!enableScheduling ||
        _disposed ||
        !_foreground ||
        channel != 'direct' && channel != 'play') {
      return;
    }
    _timer?.cancel();
    final remaining = lastChecked == null
        ? const Duration(minutes: 15)
        : config.interval - clock().difference(lastChecked!);
    final delay = remaining < const Duration(minutes: 1)
        ? const Duration(minutes: 1)
        : remaining;
    _timer = Timer(delay, () => unawaited(check()));
  }

  Future<void> install() async {
    if (_disposed || busy) {
      return;
    }
    if (channel == 'play') {
      if (status != UpdateStatus.available) {
        return;
      }
      move(UpdateStatus.preparing);
      try {
        await platform.installPlay();
        move(UpdateStatus.installStarted);
      } catch (_) {
        move(UpdateStatus.error);
      }
      return;
    }
    if (channel != 'direct' ||
        update == null ||
        apk == null ||
        ![
          UpdateStatus.downloaded,
          UpdateStatus.permissionRequired,
        ].contains(status)) {
      return;
    }
    move(UpdateStatus.preparing);
    try {
      await UpdateRepository.verify(apk!, update!);
      final result = await platform.installApk(apk!.path, update!);
      move(
        result == 'permissionRequired'
            ? UpdateStatus.permissionRequired
            : UpdateStatus.installStarted,
      );
    } catch (_) {
      move(UpdateStatus.error);
    }
  }

  bool get storeConfigured {
    final uri = Uri.tryParse(const String.fromEnvironment('APP_STORE_URL'));
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'apps.apple.com' &&
        uri.userInfo.isEmpty;
  }

  Future<void> openStore() async {
    if (storeConfigured) {
      await platform.openStore(
        Uri.parse(const String.fromEnvironment('APP_STORE_URL')),
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    cancellation?.cancel();
    _checkingCancellation?.cancel();
    _repository?.dio.close(force: true);
    super.dispose();
  }
}
