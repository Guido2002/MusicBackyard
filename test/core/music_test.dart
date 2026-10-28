import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:music_backyard/features/songs/domain/music_theory.dart';
import 'package:music_backyard/features/songs/domain/chordpro.dart';

void main() {
  group('Transposition', () {
    for (final pair in [
      ('C', 'C#'),
      ('Cm', 'C#m'),
      ('C7', 'C#7'),
      ('Cmaj7', 'C#maj7'),
      ('Csus4', 'C#sus4'),
      ('Cadd9', 'C#add9'),
      ('C/E', 'C#/F'),
      ('F#m7', 'Gm7'),
      ('Bb', 'B'),
      ('Ddim', 'D#dim'),
      ('Bb/D', 'B/Eb'),
    ]) {
      test(
        '${pair.$1} + 1',
        () => expect(MusicTheory.transpose(pair.$1, 1), pair.$2),
      );
    }
    test('Negative intervals and wrap', () {
      expect(MusicTheory.transpose('C', -13), 'B');
      expect(MusicTheory.transpose('G/B', 12), 'G/B');
      expect(MusicTheory.transpose('Cb', 1), 'C');
    });
    test(
      'Capo separates sounding key from shapes',
      () => expect(MusicTheory.soundingKey('Am', 3), 'Cm'),
    );
    test(
      'Unknown strings are not corrupted',
      () => expect(MusicTheory.transpose('N.C.', 3), 'N.C.'),
    );
    test('Anchors shift with inserted text', () {
      final line = LyricLine(
        text: 'Hello world',
        chords: [ChordAnchor(6, 'G')],
      );
      MusicTheory.editLine(line, 'Oh Hello world');
      expect(line.chords.single.offset, 9);
    });
    test('Anchors clamp when covered by replacement', () {
      final line = LyricLine(
        text: 'Hello world',
        chords: [ChordAnchor(7, 'G')],
      );
      MusicTheory.editLine(line, 'Hello you');
      expect(line.chords.single.offset, 9);
    });
    test('ChordPro round trip preserves metadata, extensions and unknown directives', () {
      const input =
          '{title: Eigen lied}\n{artist: Zoë}\n{key: Bb}\n{capo: 3}\n{tempo: 92}\n{x_custom: keep}\n{start_of_chorus: Refrein}\n[Bb]Hé [F/A]wereld [Gm7]🎵\n{end_of_chorus}';
      final song = ChordPro.parse(input);
      final output = ChordPro.parse(ChordPro.encode(song));
      expect(output.title, 'Eigen lied');
      expect(output.artist, 'Zoë');
      expect(output.currentKey, 'Bb');
      expect(output.capo, 3);
      expect(output.bpm, 92);
      expect(output.directives, ['{x_custom: keep}']);
      final line = output.arrangements.first.sections
          .expand((s) => s.lines)
          .firstWhere((l) => l.text.contains('wereld'));
      expect(line.text, 'Hé wereld 🎵');
      expect(line.chords.map((a) => a.offset), [0, 3, 10]);
      expect(line.chords.map((a) => a.chord), ['Bb', 'F/A', 'Gm7']);
    });
    test('Plain text import and binary rejection', () {
      expect(
        ChordPro.parse(
          'één\ntwee',
          fallbackTitle: 'Lied',
        ).arrangements.first.sections.first.lines.length,
        2,
      );
      expect(() => ChordPro.parse('bad\u0000'), throwsFormatException);
    });
    test('Structured tablature and arrangements serialize losslessly', () {
      final song = Song(title: 'Idee');
      song.arrangements.first.measures.add(
        TabMeasure(events: [TabEvent(string: 2, position: 4, value: '5h7')]),
      );
      song.arrangements.add(
        SongArrangement(
          name: 'Akoestisch',
          sections: [
            SongSection(
              name: 'Bridge',
              lines: [
                LyricLine(text: 'Woorden', chords: [ChordAnchor(2, 'C/E')]),
              ],
            ),
          ],
        ),
      );
      final result = Song.fromJson(song.toJson());
      expect(result.id, song.id);
      expect(
        result.arrangements.first.measures.single.events.single.value,
        '5h7',
      );
      expect(
        result
            .arrangements
            .last
            .sections
            .single
            .lines
            .single
            .chords
            .single
            .offset,
        2,
      );
    });
    test('Copy does not alias original structured content', () {
      final song = Song(title: 'A');
      final copy = song.clone(newIdentity: true);
      copy.arrangements.first.sections.first.lines.first.text = 'New';
      expect(song.arrangements.first.sections.first.lines.first.text, '');
      expect(copy.id, isNot(song.id));
    });
  });
  test(
    'Copies receive fresh nested identities while normal saves keep them',
    () {
      final song = Song(title: 'Eigen werk');
      final copy = song.clone(newIdentity: true), saved = song.clone();
      expect(copy.arrangements.first.id, isNot(song.arrangements.first.id));
      expect(
        copy.arrangements.first.sections.first.lines.first.id,
        isNot(song.arrangements.first.sections.first.lines.first.id),
      );
      expect(saved.arrangements.first.id, song.arrangements.first.id);
      expect(
        song.arrangements.first.duplicate().sections.first.id,
        isNot(song.arrangements.first.sections.first.id),
      );
    },
  );
  test('Plain chord rows are converted to positions during import', () {
    final song = ChordPro.parse('[Refrein]\nC     G7\nHallo wereld');
    final section = song.arrangements.first.sections.single;
    expect(section.name, 'Refrein');
    expect(section.lines.single.text, 'Hallo wereld');
    expect(section.lines.single.chords.map((a) => a.offset), [0, 6]);
    expect(MusicTheory.validChord('Bridge'), isFalse);
  });
  test('Repeated ChordPro roundtrips do not accumulate blank lines', () {
    final song = ChordPro.parse('Een eigen lied\n');
    final once = ChordPro.encode(song);
    expect(ChordPro.encode(ChordPro.parse(once)), once);
  });
  test('Export snapshots select the requested arrangement without mutating the song', () {
    final song = Song(title: 'A');
    song.arrangements.add(
      SongArrangement(
        name: 'Acoustic',
        sections: [
          SongSection(
            name: 'Intro',
            lines: [LyricLine(text: 'Alternative')],
          ),
        ],
      ),
    );
    final snapshot = song.clone(arrangementId: song.arrangements.last.id);
    expect(snapshot.arrangements.single.name, 'Acoustic');
    expect(song.arrangements.length, 2);
    snapshot.arrangements.single.sections.single.name = 'Changed';
    expect(song.arrangements.last.sections.single.name, 'Intro');
    expect(() => song.clone(arrangementId: 'missing'), throwsArgumentError);
  });
  group('Spotify validation', () {
    test(
      'Canonical track URL',
      () => expect(
        spotifyTrack(
          'https://open.spotify.com/track/1234567890123456789012?si=test',
        ).toString(),
        'https://open.spotify.com/track/1234567890123456789012',
      ),
    );
    for (final url in [
      'http://open.spotify.com/track/1234567890123456789012',
      'https://open.spotify.com.evil.test/track/1234567890123456789012',
      'https://evil.test/track/1234567890123456789012',
      'https://open.spotify.com/album/1234567890123456789012',
      'https://open.spotify.com/track/short',
      'spotify:track:123',
      'not a url',
      'https://open.spotify.com/a/b/track/1234567890123456789012',
    ]) {
      test('Reject $url', () => expect(spotifyTrack(url), isNull));
    }
  });
}
