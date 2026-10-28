import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/export/pdf_service.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:pdfrx/pdfrx.dart';

PdfRect wordRect(PdfPageRawText text, String word) {
  final start = text.fullText.indexOf(word);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing $word');
  return text.charRects
      .sublist(start, start + word.length)
      .reduce((a, b) => a.merge(b));
}

double finalABaseline(PdfPageRawText text, String word) {
  final start = text.fullText.indexOf(word);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing $word');
  // Every test word ends in the same glyph, so differing glyph descenders
  // cannot mask a wrongly raised lyric fragment.
  return text.charRects[start + word.length - 1].bottom;
}

Future<void> inspectSong(
  Song song,
  PdfOptions options,
  void Function(PdfPageRawText text) inspect,
) async {
  final bytes = await MusicPdfService.build([song], options);
  final document = await PdfDocument.openData(bytes);
  try {
    final contents = StringBuffer();
    final rectangles = <PdfRect>[];
    // Preserve geometry across page breaks in a continuous vertical coordinate
    // space, excluding the bandbook cover.
    for (final page in document.pages.skip(
      options.style == 'bandbook' ? 1 : 0,
    )) {
      final text = (await page.loadText())!;
      contents.write(text.fullText);
      final offset = page.pageNumber * 1000.0;
      rectangles.addAll(
        text.charRects.map(
          (r) => PdfRect(r.left, r.top - offset, r.right, r.bottom - offset),
        ),
      );
    }
    inspect(PdfPageRawText(contents.toString(), rectangles));
  } finally {
    await document.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
    await pdfrxFlutterInitialize();
  });

  for (final style in ['standard', 'compact', 'minimal', 'bandbook']) {
    for (final anchorAtStart in [true, false]) {
      test(
        '$style: unanchored words share the lyric baseline ($anchorAtStart)',
        () async {
          final song = Song(title: 'Uitlijning');
          song.arrangements.first.sections.first.lines = [
            LyricLine(
              text: 'alfa brava canta dama',
              chords: [
                if (anchorAtStart) ChordAnchor(0, 'F#m7'),
                ChordAnchor(11, 'C/E'),
              ],
            ),
          ];
          await inspectSong(song, PdfOptions(style: style), (text) {
            final baseline = finalABaseline(text, 'alfa');
            for (final word in ['brava', 'canta', 'dama']) {
              expect(finalABaseline(text, word), closeTo(baseline, .1));
            }
            final chord = wordRect(text, 'C/E'),
                lyric = wordRect(text, 'canta');
            expect(chord.left, closeTo(lyric.left, 2));
            expect(chord.bottom, greaterThan(lyric.top));
          });
        },
      );
    }
  }

  for (final options in [
    PdfOptions(a5: true, fontSize: 22, margin: 30),
    PdfOptions(a5: true, landscape: true, fontSize: 22, lineSpacing: 2),
    PdfOptions(fontSize: 8, lineSpacing: 1),
  ]) {
    test(
      'Wrapped rows retain all words and anchored chords (${options.a5}, ${options.landscape}, ${options.fontSize})',
      () async {
        final words = [
          'alfa',
          'brava',
          'canta',
          'dama',
          'elena',
          'flora',
          'gama',
          'hanna',
          'irma',
          'julia',
          'klara',
          'luna',
          'maria',
          'nora',
          'oliva',
          'paula',
          'quinta',
          'rosa',
          'sara',
          'tara',
          'ursula',
          'vera',
          'wanda',
          'xenia',
          'yara',
          'zora',
        ];
        final source = words.join(' ');
        final anchors = <String, String>{
          'brava': 'F#m7',
          'elena': 'Bbm9',
          'hanna': 'C/E',
          'klara': 'Gmaj7',
          'nora': 'Dm11',
          'quinta': 'Asus4',
          'tara': 'E7/G#',
        };
        final song = Song(title: 'Doorlopende regels');
        song.arrangements.first.sections.first.lines = [
          LyricLine(
            text: source,
            chords: [
              for (final entry in anchors.entries)
                ChordAnchor(source.indexOf(entry.key), entry.value),
            ],
          ),
        ];
        await inspectSong(song, options, (text) {
          final baselines = <int>{};
          for (final word in words) {
            baselines.add(finalABaseline(text, word).round());
          }
          expect(baselines.length, greaterThan(1));
          for (final entry in anchors.entries) {
            final chord = wordRect(text, entry.value),
                lyric = wordRect(text, entry.key);
            expect(chord.left, closeTo(lyric.left, 2), reason: entry.value);
            expect(chord.bottom, greaterThan(lyric.top), reason: entry.value);
            expect(
              chord.bottom - lyric.top,
              lessThan(options.fontSize * 2),
              reason: '${entry.value} must stay on the lyric page',
            );
            // Adjacent unanchored words on this visual row must share its baseline.
            final index = words.indexOf(entry.key);
            final next = words[index + 1];
            final delta =
                (finalABaseline(text, next) - finalABaseline(text, entry.key))
                    .abs();
            expect(
              delta < .1 || delta > options.fontSize * 2,
              isTrue,
              reason: '${entry.key} / $next are staggered',
            );
          }
        });
      },
    );
  }

  test(
    'Wide adjacent chords remain separated above short lyric fragments',
    () async {
      final song = Song(title: 'Korte woorden');
      song.arrangements.first.sections.first.lines = [
        LyricLine(
          text: 'a b c',
          chords: [
            ChordAnchor(0, 'F#m7/B'),
            ChordAnchor(2, 'Cmaj7'),
            ChordAnchor(4, 'Gsus4'),
          ],
        ),
      ];
      await inspectSong(song, PdfOptions(fontSize: 22), (text) {
        final chords = [
          'F#m7/B',
          'Cmaj7',
          'Gsus4',
        ].map((c) => wordRect(text, c)).toList();
        for (var i = 1; i < chords.length; i++) {
          expect(chords[i].left - chords[i - 1].right, greaterThan(3));
        }
      });
    },
  );
}
