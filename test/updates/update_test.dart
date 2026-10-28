import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/app_updates/data/update_manifest_model.dart';
import 'package:music_backyard/features/app_updates/data/update_repository.dart';
import 'package:music_backyard/features/app_updates/domain/update_status.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body);
  final int status;
  final List<int> body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      Headers.contentLengthHeader: ['${body.length}'],
    },
  );
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> manifest() => {
  'version': '1.1.0',
  'buildNumber': 12,
  'platform': 'android',
  'channel': 'direct',
  'downloadUrl': 'https://releases.example.test/app.apk',
  'sha256': 'a' * 64,
  'sizeBytes': 12,
  'releaseNotes': ['Verbeterd'],
  'mandatory': false,
};
void main() {
  const hosts = {'releases.example.test'};
  test('Verified download and cancellation clean up partial APKs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'musicbackyard-download',
    );
    try {
      final bytes = utf8.encode('verified apk');
      final info = UpdateManifestModel.parse(
        manifest()
          ..['sha256'] = sha256.convert(bytes).toString()
          ..['sizeBytes'] = bytes.length,
        platform: 'android',
        channel: 'direct',
        trustedHosts: hosts,
      );
      final dio = Dio()..httpClientAdapter = FakeAdapter(200, bytes);
      final repository = UpdateRepository(
        endpoint: Uri.parse('https://releases.example.test/manifest.json'),
        trustedHosts: hosts,
        dio: dio,
      );
      final file = await repository.download(
        info,
        directory,
        CancelToken(),
        (received, total) {},
      );
      expect(await file.readAsBytes(), bytes);
      await file.delete();
      final cancelled = CancelToken()..cancel('test');
      await expectLater(
        repository.download(info, directory, cancelled, (received, total) {}),
        throwsA(isA<DioException>()),
      );
      expect(await file.exists(), isFalse);
      dio.httpClientAdapter = FakeAdapter(200, utf8.encode('tampered apk'));
      await expectLater(
        repository.download(
          info,
          directory,
          CancelToken(),
          (received, total) {},
        ),
        throwsFormatException,
      );
      expect(await file.exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  test('Valid manifest accepts strictly matching channel and host', () {
    final info = UpdateManifestModel.parse(
      manifest(),
      platform: 'android',
      channel: 'direct',
      trustedHosts: hosts,
    );
    expect(info.buildNumber, 12);
    expect(info.releaseNotes, ['Verbeterd']);
  });
  for (final change in <String, dynamic>{
    'version': 'latest',
    'buildNumber': '12',
    'platform': 'ios',
    'channel': 'play',
    'downloadUrl': 'http://releases.example.test/app.apk',
    'sha256': 'bad',
    'sizeBytes': -1,
    'releaseNotes': [null],
    'mandatory': 'false',
  }.entries) {
    test('Reject invalid ${change.key}', () {
      final value = manifest()..[change.key] = change.value;
      expect(
        () => UpdateManifestModel.parse(
          value,
          platform: 'android',
          channel: 'direct',
          trustedHosts: hosts,
        ),
        throwsFormatException,
      );
    });
  }
  for (final url in [
    'https://evil.test/app.apk',
    'https://releases.example.test.evil.test/app.apk',
    'https://user:pass@releases.example.test/app.apk',
    'https://releases.example.test:444/app.apk',
    'https://releases.example.test/app.ipa',
  ]) {
    test(
      'Reject URL $url',
      () => expect(
        () => UpdateManifestModel.parse(
          manifest()..['downloadUrl'] = url,
          platform: 'android',
          channel: 'direct',
          trustedHosts: hosts,
        ),
        throwsFormatException,
      ),
    );
  }
  test(
    'Non-map JSON is rejected',
    () => expect(
      () => UpdateManifestModel.parse(
        [],
        platform: 'android',
        channel: 'direct',
        trustedHosts: hosts,
      ),
      throwsFormatException,
    ),
  );
  test('State machine rejects installing before download', () {
    final machine = UpdateStateMachine();
    expect(() => machine.move(UpdateStatus.preparing), throwsStateError);
    machine.move(UpdateStatus.checking);
    machine.move(UpdateStatus.available);
    machine.move(UpdateStatus.downloading);
    machine.move(UpdateStatus.downloaded);
    machine.move(UpdateStatus.preparing);
    machine.move(UpdateStatus.permissionRequired);
    machine.move(UpdateStatus.preparing);
    machine.move(UpdateStatus.installStarted);
    machine.move(UpdateStatus.downloaded);
  });
  test('Network failures remain an ordinary failed future', () async {
    final dio = Dio()..httpClientAdapter = FakeAdapter(503, []);
    final r = UpdateRepository(
      endpoint: Uri.parse('https://releases.example.test/manifest.json'),
      trustedHosts: hosts,
      dio: dio,
    );
    await expectLater(r.check(), throwsA(isA<DioException>()));
  });
  test('Malformed JSON does not offer an update', () async {
    final dio = Dio()
      ..httpClientAdapter = FakeAdapter(200, utf8.encode('not-json'));
    final r = UpdateRepository(
      endpoint: Uri.parse('https://releases.example.test/manifest.json'),
      trustedHosts: hosts,
      dio: dio,
    );
    await expectLater(r.check(), throwsA(anything));
  });
  test(
    'Redirect response is rejected instead of bypassing host policy',
    () async {
      final dio = Dio()..httpClientAdapter = FakeAdapter(302, []);
      final r = UpdateRepository(
        endpoint: Uri.parse('https://releases.example.test/manifest.json'),
        trustedHosts: hosts,
        dio: dio,
      );
      await expectLater(r.check(), throwsFormatException);
    },
  );
  test('Valid file, wrong hash, wrong size and missing file', () async {
    final directory = await Directory.systemTemp.createTemp('apk-test');
    final file = File('${directory.path}/app.apk');
    final bytes = utf8.encode('verified apk');
    await file.writeAsBytes(bytes);
    final data = manifest()
      ..['sha256'] = sha256.convert(bytes).toString()
      ..['sizeBytes'] = bytes.length;
    final info = UpdateManifestModel.parse(
      data,
      platform: 'android',
      channel: 'direct',
      trustedHosts: hosts,
    );
    await UpdateRepository.verify(file, info);
    await file.writeAsBytes(utf8.encode('tampered apk'));
    await expectLater(
      UpdateRepository.verify(file, info),
      throwsFormatException,
    );
    await file.writeAsBytes([1]);
    await expectLater(
      UpdateRepository.verify(file, info),
      throwsFormatException,
    );
    await file.delete();
    await expectLater(
      UpdateRepository.verify(file, info),
      throwsFormatException,
    );
    await directory.delete();
  });
}
