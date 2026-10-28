import 'song.dart';
import 'music_theory.dart';

abstract final class ChordPro {
  static Song parse(String input, {String fallbackTitle = ''}) {
    if (input.contains('\u0000')) {
      throw const FormatException('Binary input');
    }
    final song = Song(title: fallbackTitle);
    final sections = <SongSection>[];
    SongSection? current;
    void ensureSection() {
      current ??= SongSection(name: 'Couplet', lines: []);
      if (!sections.contains(current)) {
        sections.add(current!);
      }
    }

    final source = input.replaceAll('\r\n', '\n').split('\n');
    if (source.isNotEmpty && source.last.isEmpty) {
      source.removeLast();
    }
    for (var sourceIndex = 0; sourceIndex < source.length; sourceIndex++) {
      final raw = source[sourceIndex];
      final tokens = RegExp(r'\S+').allMatches(raw).toList();
      if (sourceIndex + 1 < source.length &&
          tokens.isNotEmpty &&
          tokens.every((m) => MusicTheory.validChord(m[0]!)) &&
          !source[sourceIndex + 1].trim().startsWith('{')) {
        ensureSection();
        final lyric = source[++sourceIndex];
        current!.lines.add(
          LyricLine(
            text: lyric,
            chords: tokens
                .map((m) => ChordAnchor(m.start.clamp(0, lyric.length), m[0]!))
                .toList(),
          ),
        );
        continue;
      }
      final heading = RegExp(
        r'^\[(Intro|Couplet|Verse|Refrein|Chorus|Bridge|Solo|Outro)(?:\s+\d+)?\]$',
        caseSensitive: false,
      ).firstMatch(raw.trim());
      if (heading != null) {
        current = SongSection(
          name: raw.trim().substring(1, raw.trim().length - 1),
          lines: [],
        );
        sections.add(current!);
        continue;
      }
      final directive = RegExp(r'^\{([^:}]+)(?::\s*(.*))?\}$')
          .firstMatch(raw.trim());
      if (directive != null) {
        final key = directive[1]!.toLowerCase(), value = directive[2] ?? '';
        switch (key) {
          case 'title':
          case 't':
            song.title = value;
          case 'artist':
            song.artist = value;
          case 'album':
            song.album = value;
          case 'key':
            song.originalKey = value;
            song.currentKey = value;
          case 'capo':
            song.capo = (int.tryParse(value) ?? 0).clamp(0, 12);
          case 'tempo':
            song.bpm = (int.tryParse(value) ?? 100).clamp(20, 400);
          case 'start_of_chorus':
          case 'soc':
          case 'start_of_verse':
          case 'sov':
          case 'start_of_bridge':
          case 'sob':
            current = SongSection(
              name: value.isNotEmpty
                  ? value
                  : (key.contains('chorus') || key == 'soc'
                        ? 'Refrein'
                        : key.contains('bridge') || key == 'sob'
                        ? 'Bridge'
                        : 'Couplet'),
              lines: [],
            );
            sections.add(current!);
          case 'end_of_chorus':
          case 'eoc':
          case 'end_of_verse':
          case 'eov':
          case 'end_of_bridge':
          case 'eob':
            current = null;
          case 'comment':
          case 'c':
            current = SongSection(name: value, lines: []);
            sections.add(current!);
          default:
            song.directives.add(raw);
        }
        continue;
      }
      ensureSection();
      final chords = <ChordAnchor>[];
      final text = StringBuffer();
      var index = 0;
      for (final m in RegExp(r'\[([^\]]+)\]').allMatches(raw)) {
        text.write(raw.substring(index, m.start));
        if (MusicTheory.validChord(m[1]!)) {
          chords.add(ChordAnchor(text.length, m[1]!));
        } else {
          text.write(m[0]);
        }
        index = m.end;
      }
      text.write(raw.substring(index));
      current!.lines.add(LyricLine(text: text.toString(), chords: chords));
    }
    song.arrangements.first.sections = sections.isEmpty
        ? [SongSection(name: 'Couplet')]
        : sections;
    return song;
  }

  static String inline(LyricLine line) {
    final sorted = [...line.chords]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final out = StringBuffer();
    var index = 0;
    for (final chord in sorted) {
      final offset = chord.offset.clamp(index, line.text.length);
      out.write(line.text.substring(index, offset));
      out.write('[${chord.chord}]');
      index = offset;
    }
    out.write(line.text.substring(index));
    return out.toString();
  }

  static String encode(Song song, {SongArrangement? arrangement}) {
    String clean(String text) => text.replaceAll(RegExp(r'[\r\n{}]'), ' ');
    return [
      '{title: ${clean(song.title)}}',
      '{artist: ${clean(song.artist)}}',
      '{album: ${clean(song.album)}}',
      '{key: ${clean(song.currentKey)}}',
      '{capo: ${song.capo}}',
      '{tempo: ${song.bpm}}',
      ...song.directives,
      for (final section
          in (arrangement ?? song.arrangements.first).sections) ...[
        '{comment: ${clean(section.name)}}',
        ...section.lines.map(inline),
      ],
      '',
    ].join('\n');
  }
}
