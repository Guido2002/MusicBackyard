enum ReleaseTrack {
  stable,
  beta;

  static ReleaseTrack parse(String value) => switch (value) {
    'stable' => stable,
    'beta' => beta,
    _ => throw FormatException('Unknown release track: $value'),
  };
}
