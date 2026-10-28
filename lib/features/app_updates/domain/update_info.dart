class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.channel,
    required this.downloadUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.mandatory,
    this.track = 'stable',
  });
  final String version, platform, channel, sha256, track;
  final int buildNumber, sizeBytes;
  final Uri downloadUrl;
  final List<String> releaseNotes;
  final bool mandatory;
  Map<String, dynamic> toJson() => {
    'version': version,
    'buildNumber': buildNumber,
    'platform': platform,
    'channel': channel,
    'track': track,
    'downloadUrl': downloadUrl.toString(),
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'releaseNotes': releaseNotes,
    'mandatory': mandatory,
  };
}
