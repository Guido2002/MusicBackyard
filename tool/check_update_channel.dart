import 'dart:io';

import 'package:dio/dio.dart';
import 'package:music_backyard/features/app_updates/data/update_repository.dart';
import 'package:music_backyard/features/app_updates/domain/release_track.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || !['stable', 'beta'].contains(args.first)) {
    stderr.writeln(
      'Usage: dart run tool/check_update_channel.dart stable|beta [--download]',
    );
    exitCode = 64;
    return;
  }
  final track = ReleaseTrack.parse(args.first);
  final repository = UpdateRepository(
    endpoint: Uri.parse(
      'https://raw.githubusercontent.com/Guido2002/MusicBackyard/update-channels/${track.name}.json',
    ),
    trustedHosts: {'github.com'},
    githubRepository: 'Guido2002/MusicBackyard',
    track: track,
  );
  try {
    final info = await repository.check();
    stdout.writeln(
      '${track.name}: ${info.version} (${info.buildNumber}), ${info.sizeBytes} bytes',
    );
    if (args.contains('--download')) {
      final directory = await Directory.systemTemp.createTemp(
        'musicbackyard-release-check',
      );
      try {
        await repository.download(info, directory, CancelToken(), (_, _) {});
        stdout.writeln(
          'Live HTTPS redirect policy, byte count and SHA-256 verified.',
        );
      } finally {
        await directory.delete(recursive: true);
      }
    }
  } catch (error) {
    stderr.writeln('Channel verification failed: $error');
    exitCode = 1;
  } finally {
    repository.dio.close(force: true);
  }
}
