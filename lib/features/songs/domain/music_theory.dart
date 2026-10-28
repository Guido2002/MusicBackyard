import 'song.dart';

abstract final class MusicTheory {
  static const sharps = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  static const flats = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];
  static final chordPattern = RegExp(
    r'^([A-G](?:#|b)?)([^/\s]*)(?:/([A-G](?:#|b)?))?$',
  );
  static bool validChord(String chord) =>
      RegExp(
        r'^[A-G](?:#|b)?(?:(?:min|maj|dim|aug|sus|add|alt|omit|no|m|M)|[0-9()+#b°øΔ-])*(?:/[A-G](?:#|b)?)?$',
      ).hasMatch(chord) &&
      !chord.contains(RegExp(r'[\[\]{}]'));
  static String transpose(String chord, int semitones, {bool? preferFlats}) {
    final match = chordPattern.firstMatch(chord);
    if (match == null) {
      return chord;
    }
    final useFlats = preferFlats ?? chord.contains('b');
    String root(String value) {
      int index = sharps.indexOf(value);
      if (index < 0) {
        index = flats.indexOf(value);
      }
      if (index < 0) {
        index = {'Cb': 11, 'B#': 0, 'E#': 5, 'Fb': 4}[value] ?? 0;
      }
      return (useFlats ? flats : sharps)[(index + semitones) % 12];
    }

    return '${root(match[1]!)}${match[2]}${match[3] == null ? '' : '/${root(match[3]!)}'}';
  }

  static void transposeArrangement(
    SongArrangement arrangement,
    int semitones, {
    bool? preferFlats,
  }) {
    for (final section in arrangement.sections) {
      for (final line in section.lines) {
        for (final chord in line.chords) {
          chord.chord = transpose(
            chord.chord,
            semitones,
            preferFlats: preferFlats,
          );
        }
      }
    }
  }

  static String soundingKey(String played, int capo) => transpose(played, capo);
  static List<int> suggestedCapos(
    SongArrangement arrangement, {
    int currentCapo = 0,
  }) {
    if (currentCapo < 0 || currentCapo > 12) {
      throw RangeError.range(currentCapo, 0, 12);
    }
    final chords = arrangement.sections
        .expand((s) => s.lines)
        .expand((l) => l.chords)
        .toList();
    if (chords.isEmpty) {
      return [];
    }
    return List.generate(13, (i) => i)
        .where(
          (capo) => chords.every(
            (a) => const ['C', 'D', 'E', 'G', 'A', 'Am', 'Dm', 'Em', 'C/E']
                .contains(
                  transpose(a.chord, currentCapo - capo, preferFlats: false),
                ),
          ),
        )
        .toList();
  }

  /// Capo is song-wide: update every arrangement consistently, leaving the original key intact.
  static void applyCapo(Song song, int capo, {bool preservePitch = true}) {
    if (capo < 0 || capo > 12) {
      throw RangeError.range(capo, 0, 12);
    }
    if (preservePitch) {
      final delta = song.capo - capo;
      for (final arrangement in song.arrangements) {
        transposeArrangement(
          arrangement,
          delta,
          preferFlats: song.currentKey.contains('b'),
        );
      }
      song.currentKey = transpose(song.currentKey, delta);
    }
    song.capo = capo;
  }

  // Keep anchors attached to the same text when an edit inserts/removes characters.
  static void editLine(LyricLine line, String value) {
    final old = line.text;
    var start = 0;
    while (start < old.length &&
        start < value.length &&
        old[start] == value[start]) {
      start++;
    }
    var oldEnd = old.length, newEnd = value.length;
    while (oldEnd > start &&
        newEnd > start &&
        old[oldEnd - 1] == value[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }
    final delta = newEnd - oldEnd;
    for (final anchor in line.chords) {
      if (anchor.offset >= oldEnd) {
        anchor.offset += delta;
      } else if (anchor.offset > start) {
        anchor.offset = newEnd;
      }
      anchor.offset = anchor.offset.clamp(0, value.length);
    }
    line.text = value;
  }
}

Uri? spotifyTrack(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'open.spotify.com' ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final parts = uri.pathSegments;
  final trackIndex = parts.indexOf('track');
  if (trackIndex < 0 ||
      trackIndex != parts.length - 2 ||
      (trackIndex > 0 && !RegExp(r'^intl-[a-z]{2}$').hasMatch(parts.first)) ||
      !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(parts.last)) {
    return null;
  }
  return Uri.https('open.spotify.com', '/track/${parts.last}');
}
