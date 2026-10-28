import 'package:flutter/foundation.dart';

import '../domain/release_track.dart';

/// Public configuration only. Release builds never contain hosting credentials.
class ReleaseConfig {
  const ReleaseConfig({
    required this.stableEndpoint,
    required this.betaEndpoint,
    required this.downloadHosts,
    this.githubRepository,
    this.interval = const Duration(hours: 6),
    this.defaultTrack = ReleaseTrack.stable,
    this.automaticWifiDownload = true,
  });
  factory ReleaseConfig.fromEnvironment() {
    const repo = String.fromEnvironment(
      'UPDATE_REPOSITORY',
      defaultValue: 'Guido2002/MusicBackyard',
    );
    const stable = String.fromEnvironment('UPDATE_ENDPOINT');
    const beta = String.fromEnvironment('UPDATE_BETA_ENDPOINT');
    final repository = repo.isEmpty ? null : repo;
    if (repository != null &&
        !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository)) {
      throw const FormatException('Invalid update repository');
    }
    Uri? endpoint(String override, String track) => override.isNotEmpty
        ? Uri.tryParse(override)
        : repository == null
        ? null
        : Uri.https(
            'raw.githubusercontent.com',
            '/$repository/update-channels/$track.json',
          );
    final hours = const int.fromEnvironment(
      'UPDATE_INTERVAL_HOURS',
      defaultValue: 6,
    );
    if (hours < 1 || hours > 168) {
      throw const FormatException('Update interval must be 1–168 hours');
    }
    return ReleaseConfig(
      stableEndpoint: endpoint(stable, 'stable'),
      betaEndpoint: endpoint(beta, 'beta'),
      githubRepository: repository,
      downloadHosts: {
        if (repository != null) 'github.com',
        ...const String.fromEnvironment('UPDATE_DOWNLOAD_HOSTS')
            .split(',')
            .map((v) => v.trim().toLowerCase())
            .where((v) => v.isNotEmpty),
      },
      interval: Duration(hours: hours),
      defaultTrack: ReleaseTrack.parse(
        const String.fromEnvironment('RELEASE_TRACK', defaultValue: 'stable'),
      ),
      automaticWifiDownload: const bool.fromEnvironment(
        'UPDATE_AUTO_DOWNLOAD_WIFI',
        defaultValue: !kDebugMode,
      ),
    );
  }
  final Uri? stableEndpoint, betaEndpoint;
  final Set<String> downloadHosts;
  final String? githubRepository;
  final Duration interval;
  final ReleaseTrack defaultTrack;
  final bool automaticWifiDownload;
  Uri? endpoint(ReleaseTrack track) =>
      track == ReleaseTrack.stable ? stableEndpoint : betaEndpoint;
  bool get hasBeta => betaEndpoint != null;
}
