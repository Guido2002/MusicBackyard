import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/app_updates/data/update_manifest_model.dart';
import 'package:music_backyard/features/app_updates/data/update_repository.dart';
import 'package:music_backyard/features/app_updates/data/update_url_policy.dart';
import 'package:music_backyard/features/app_updates/domain/release_track.dart';

class Redirects implements HttpClientAdapter {
  Redirects(this.destination);
  final String destination;
  final urls = <String>[];
  final bytes = utf8.encode('verified download');
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    urls.add(options.uri.toString());
    if (options.uri.host == 'github.com') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [destination],
        },
      );
    }
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const policy = UpdateUrlPolicy(
    downloadHosts: {'github.com'},
    githubRepository: 'Guido2002/MusicBackyard',
  );
  final origin = Uri.parse(
    'https://github.com/Guido2002/MusicBackyard/releases/download/v1.1.1/app.apk',
  );
  test('Only this repository may provide the initial GitHub APK URL', () {
    expect(policy.allowsDownload(origin), isTrue);
    for (final uri in [
      'https://github.com/other/repo/releases/download/v1/app.apk',
      'https://github.com/Guido2002/MusicBackyard/releases/download/../app.apk',
      'http://github.com/Guido2002/MusicBackyard/releases/download/v1/app.apk',
    ]) {
      expect(policy.allowsDownload(Uri.parse(uri)), isFalse);
    }
  });
  test(
    'Redirects require exact GitHub CDN hostname, HTTPS and no URL credentials',
    () {
      expect(
        policy.allowsRedirect(
          origin,
          Uri.parse(
            'https://release-assets.githubusercontent.com/asset?sig=test',
          ),
        ),
        isTrue,
      );
      for (final uri in [
        'http://release-assets.githubusercontent.com/asset',
        'https://release-assets.githubusercontent.com.evil.test/asset',
        'https://user@release-assets.githubusercontent.com/asset',
        'https://evil.test/asset',
        'https://release-assets.githubusercontent.com:444/asset',
      ]) {
        expect(policy.allowsRedirect(origin, Uri.parse(uri)), isFalse);
      }
      expect(
        const UpdateUrlPolicy(downloadHosts: {'custom.example'}).allowsRedirect(
          Uri.parse('https://custom.example/app.apk'),
          Uri.parse('https://custom.example/new.apk'),
        ),
        isFalse,
      );
    },
  );
  test('A validated GitHub redirect is streamed and hash checked', () async {
    final adapter = Redirects(
      'https://release-assets.githubusercontent.com/asset',
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final info = UpdateManifestModel.parse(
      {
        'version': '1.1.1',
        'buildNumber': 4,
        'platform': 'android',
        'channel': 'direct',
        'track': 'stable',
        'downloadUrl': origin.toString(),
        'sha256': sha256.convert(adapter.bytes).toString(),
        'sizeBytes': adapter.bytes.length,
        'releaseNotes': [],
        'mandatory': false,
      },
      platform: 'android',
      channel: 'direct',
      trustedHosts: {'github.com'},
      githubRepository: 'Guido2002/MusicBackyard',
    );
    final root = await Directory.systemTemp.createTemp('musicbackyard-cdn');
    try {
      final r = UpdateRepository(
        endpoint: Uri.parse(
          'https://raw.githubusercontent.com/Guido2002/MusicBackyard/update-channels/stable.json',
        ),
        trustedHosts: {'github.com'},
        githubRepository: 'Guido2002/MusicBackyard',
        dio: dio,
      );
      final file = await r.download(info, root, CancelToken(), (a, b) {});
      expect(await file.readAsBytes(), adapter.bytes);
      expect(adapter.urls.length, 2);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('Stable/beta mismatches are rejected before an update is offered', () {
    final value = {
      'version': '1.2.0-beta.1',
      'buildNumber': 4,
      'platform': 'android',
      'channel': 'direct',
      'track': 'beta',
      'downloadUrl': 'https://releases.test/app.apk',
      'sha256': 'a' * 64,
      'sizeBytes': 5,
      'releaseNotes': [],
      'mandatory': false,
    };
    expect(
      () => UpdateManifestModel.parse(
        value,
        platform: 'android',
        channel: 'direct',
        trustedHosts: {'releases.test'},
      ),
      throwsFormatException,
    );
    expect(
      UpdateManifestModel.parse(
        value,
        platform: 'android',
        channel: 'direct',
        trustedHosts: {'releases.test'},
        track: ReleaseTrack.beta,
      ).track,
      'beta',
    );
  });
  test('Malformed semantic versions and invalid Android build numbers are rejected', () {
    for (final version in [
      '1.2.3-beta..1',
      '1.2.3-beta.01',
      '01.2.3',
      '1.2.3-',
      '1.2.3-a_1',
    ]) {
      expect(
        UpdateManifestModel.validVersion(version),
        isFalse,
        reason: version,
      );
    }
    for (final version in ['1.2.3', '1.2.3-beta.1', '1.2.3-0', '1.2.3-rc-1']) {
      expect(
        UpdateManifestModel.validVersion(version),
        isTrue,
        reason: version,
      );
    }
  });
}
