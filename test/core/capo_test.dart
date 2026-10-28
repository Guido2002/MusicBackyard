import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/songs/domain/music_theory.dart';
import 'package:music_backyard/features/songs/domain/song.dart';

void main() {
  Song fixture() => Song(
    originalKey: 'F',
    currentKey: 'D',
    capo: 3,
    arrangements: [
      SongArrangement(
        name: 'A',
        sections: [
          SongSection(
            name: 'Verse',
            lines: [
              LyricLine(
                text: 'Own song',
                chords: [ChordAnchor(0, 'D/F#'), ChordAnchor(4, 'Bm7')],
              ),
            ],
          ),
        ],
      ),
      SongArrangement(
        name: 'B',
        sections: [
          SongSection(
            name: 'Verse',
            lines: [
              LyricLine(chords: [ChordAnchor(0, 'G')]),
            ],
          ),
        ],
      ),
    ],
  );
  test('Changing capo preserves sounding pitches for every arrangement', () {
    final song = fixture();
    final sounding = song.arrangements
        .expand((a) => a.sections)
        .expand((s) => s.lines)
        .expand((l) => l.chords)
        .map(
          (a) => MusicTheory.transpose(a.chord, song.capo, preferFlats: false),
        )
        .toList();
    MusicTheory.applyCapo(song, 1);
    final updated = song.arrangements
        .expand((a) => a.sections)
        .expand((s) => s.lines)
        .expand((l) => l.chords)
        .map(
          (a) => MusicTheory.transpose(a.chord, song.capo, preferFlats: false),
        )
        .toList();
    expect(updated, sounding);
    expect(song.currentKey, 'E');
    expect(song.originalKey, 'F');
    expect(song.capo, 1);
    expect(
      song.arrangements.first.sections.first.lines.first.chords.first.chord,
      'E/G#',
    );
  });
  test('Explicit pitch change leaves shapes as entered', () {
    final song = fixture();
    MusicTheory.applyCapo(song, 6, preservePitch: false);
    expect(song.capo, 6);
    expect(song.currentKey, 'D');
    expect(
      song.arrangements.first.sections.first.lines.first.chords.first.chord,
      'D/F#',
    );
  });
  test(
    'Suggestions account for an existing capo and do not guess without chords',
    () {
      final a = SongArrangement(
        name: 'A',
        sections: [
          SongSection(
            name: 'Verse',
            lines: [
              LyricLine(chords: [ChordAnchor(0, 'F'), ChordAnchor(2, 'Bb')]),
            ],
          ),
        ],
      );
      expect(MusicTheory.suggestedCapos(a), contains(1));
      expect(MusicTheory.suggestedCapos(a, currentCapo: 2), contains(3));
      expect(
        MusicTheory.suggestedCapos(SongArrangement(name: 'Empty')),
        isEmpty,
      );
      expect(() => MusicTheory.applyCapo(fixture(), 13), throwsRangeError);
      expect(() => MusicTheory.applyCapo(fixture(), -1), throwsRangeError);
    },
  );
}
