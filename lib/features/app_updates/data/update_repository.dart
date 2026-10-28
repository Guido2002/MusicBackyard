import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../domain/release_track.dart';
import '../domain/update_info.dart';
import 'update_manifest_model.dart';
import 'update_url_policy.dart';

class UpdateRepository {
  UpdateRepository({
    required this.endpoint,
    required this.trustedHosts,
    this.track = ReleaseTrack.stable,
    this.githubRepository,
    Dio? dio,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 12),
               receiveTimeout: const Duration(seconds: 45),
               followRedirects: false,
             ),
           );
  final Uri? endpoint;
  final Set<String> trustedHosts;
  final ReleaseTrack track;
  final String? githubRepository;
  final Dio dio;
  UpdateUrlPolicy get policy => UpdateUrlPolicy(
    downloadHosts: trustedHosts,
    githubRepository: githubRepository,
  );
  bool get configured =>
      endpoint != null && policy.secure(endpoint!) && trustedHosts.isNotEmpty;

  Future<Response<ResponseBody>> _open(
    Uri origin, {
    CancelToken? cancel,
  }) async {
    var url = origin;
    for (var hop = 0; hop <= 3; hop++) {
      final response = await dio.getUri<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          followRedirects: false,
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'application/octet-stream',
            'Cache-Control': 'no-cache',
          },
          validateStatus: (status) =>
              status == 200 || const [301, 302, 303, 307, 308].contains(status),
        ),
      );
      if (response.statusCode == 200) {
        return response;
      }
      await response.data!.stream.listen(null).cancel();
      final location = response.headers.value('location');
      if (location == null || hop == 3) {
        throw const FormatException('Missing or excessive redirects');
      }
      final destination = url.resolve(location);
      if (!policy.allowsRedirect(origin, destination)) {
        throw const FormatException('Untrusted redirect');
      }
      url = destination;
    }
    throw const FormatException('Excessive redirects');
  }

  Future<UpdateInfo> check({CancelToken? cancel}) async {
    if (!configured) {
      throw StateError('Update source not configured');
    }
    final response = await _open(endpoint!, cancel: cancel);
    final bytes = <int>[];
    await for (final chunk in response.data!.stream) {
      if (bytes.length + chunk.length > 1024 * 1024) {
        throw const FormatException('Manifest too large');
      }
      bytes.addAll(chunk);
    }
    return UpdateManifestModel.parse(
      jsonDecode(utf8.decode(bytes)),
      platform: 'android',
      channel: 'direct',
      trustedHosts: trustedHosts,
      track: track,
      githubRepository: githubRepository,
    );
  }

  Future<File> download(
    UpdateInfo info,
    Directory directory,
    CancelToken cancel,
    void Function(int, int) progress,
  ) async {
    if (!policy.allowsDownload(info.downloadUrl) || info.track != track.name) {
      throw const FormatException('Untrusted download');
    }
    await directory.create(recursive: true);
    final file = File('${directory.path}/update-${info.buildNumber}.apk');
    try {
      final response = await _open(info.downloadUrl, cancel: cancel);
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.data!.stream) {
          if (cancel.isCancelled) {
            throw cancel.cancelError!;
          }
          received += chunk.length;
          if (received > info.sizeBytes) {
            throw const FormatException('Size exceeds manifest');
          }
          sink.add(chunk);
          progress(received, info.sizeBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (cancel.isCancelled) {
        throw cancel.cancelError!;
      }
      await verify(file, info);
      return file;
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  static Future<void> verify(File file, UpdateInfo info) async {
    if (!await file.exists() || await file.length() != info.sizeBytes) {
      throw const FormatException('Invalid APK size');
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != info.sha256) {
      throw const FormatException('APK integrity check failed');
    }
  }
}
