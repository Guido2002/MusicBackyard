import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:music_backyard/features/app_updates/data/update_manifest_model.dart';
import 'package:music_backyard/features/app_updates/domain/release_track.dart';

Future<void> main(List<String> args) async {
  if (args.length != 6 && args.length != 7) {
    stderr.writeln(
      'Usage: dart run tool/create_update_manifest.dart APK VERSION BUILD HTTPS_DOWNLOAD_URL NOTES_TEXT_FILE OUTPUT_JSON [stable|beta]',
    );
    exitCode = 64;
    return;
  }
  try {
    final apk = File(args[0]), uri = Uri.parse(args[3]);
    final track = ReleaseTrack.parse(args.length == 7 ? args[6] : 'stable');
    final githubRepository =
        uri.host == 'github.com' && uri.pathSegments.length >= 6
        ? '${uri.pathSegments[0]}/${uri.pathSegments[1]}'
        : null;
    final notes = (await File(
      args[4],
    ).readAsLines()).map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
    final info = UpdateManifestModel.parse(
      {
        'version': args[1],
        'buildNumber': int.parse(args[2]),
        'platform': 'android',
        'channel': 'direct',
        'track': track.name,
        'downloadUrl': uri.toString(),
        'sha256': (await sha256.bind(apk.openRead()).first).toString(),
        'sizeBytes': await apk.length(),
        'releaseNotes': notes,
        'mandatory': false,
      },
      platform: 'android',
      channel: 'direct',
      trustedHosts: {uri.host},
      track: track,
      githubRepository: githubRepository,
    );
    await File(args[5]).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(info.toJson())}\n',
    );
    stdout.writeln(
      'Manifest written to ${args[5]}. Verify APK version, application ID and production signer before publishing.',
    );
  } catch (e) {
    stderr.writeln('Manifest generation failed: $e');
    exitCode = 1;
  }
}
