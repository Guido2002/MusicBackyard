import '../domain/update_info.dart';
import '../domain/release_track.dart';
import 'update_url_policy.dart';

abstract final class UpdateManifestModel {
  static bool validVersion(String version) {
    if (version.length > 128) {
      return false;
    }
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?$',
    ).firstMatch(version);
    if (match == null) {
      return false;
    }
    final prerelease = match[4];
    return prerelease == null ||
        prerelease
            .split('.')
            .every(
              (part) =>
                  RegExp(r'^[0-9A-Za-z-]+$').hasMatch(part) &&
                  !(RegExp(r'^\d+$').hasMatch(part) &&
                      part.length > 1 &&
                      part.startsWith('0')),
            );
  }

  static UpdateInfo parse(
    Object? value, {
    required String platform,
    required String channel,
    required Set<String> trustedHosts,
    ReleaseTrack track = ReleaseTrack.stable,
    String? githubRepository,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid update manifest');
    }
    String string(String key) {
      final v = value[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('Invalid $key');
      }
      return v;
    }

    int number(String key) {
      final v = value[key];
      if (v is! int || v <= 0) {
        throw FormatException('Invalid $key');
      }
      return v;
    }

    final version = string('version'),
        build = number('buildNumber'),
        size = number('sizeBytes'),
        sha = string('sha256');
    if (!validVersion(version) ||
        build > 2100000000 ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha) ||
        size > 500 * 1024 * 1024) {
      throw const FormatException('Invalid version, hash or size');
    }
    final actualTrack = value.containsKey('track') ? value['track'] : 'stable';
    if (actualTrack != track.name ||
        track == ReleaseTrack.stable && version.contains('-')) {
      throw const FormatException('Incompatible release track');
    }
    if (string('platform') != platform || string('channel') != channel) {
      throw const FormatException('Incompatible distribution');
    }
    final url = Uri.tryParse(string('downloadUrl'));
    if (url == null ||
        !UpdateUrlPolicy(
          downloadHosts: trustedHosts,
          githubRepository: githubRepository,
        ).allowsDownload(url)) {
      throw const FormatException('Untrusted download URL');
    }
    final notes = value['releaseNotes'];
    if (notes is! List ||
        notes.length > 100 ||
        notes.any((e) => e is! String || e.length > 2000) ||
        value['mandatory'] is! bool) {
      throw const FormatException('Invalid release information');
    }
    return UpdateInfo(
      version: version,
      track: track.name,
      buildNumber: build,
      platform: platform,
      channel: channel,
      downloadUrl: url,
      sha256: sha.toLowerCase(),
      sizeBytes: size,
      releaseNotes: List<String>.from(notes),
      mandatory: value['mandatory'],
    );
  }
}
