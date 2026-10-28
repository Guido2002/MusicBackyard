import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/features/export/pdf_service.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Long song and intact tabs paginate with embedded offline fonts',
    () async {
      final song = Song(
        title: 'Eigen muziek — Zoë',
        artist: 'Muzikant',
        notes: 'Zacht spelen.',
      );
      song.arrangements.first.sections = [
        for (var i = 0; i < 12; i++)
          SongSection(
            name: 'Couplet $i',
            lines: [
              for (var j = 0; j < 14; j++)
                LyricLine(
                  text: 'Wij spelen samen op een warme zomeravond.',
                  chords: [ChordAnchor(0, 'F#m7'), ChordAnchor(17, 'C/E')],
                ),
            ],
          ),
      ];
      song.arrangements.first.measures = [
        TabMeasure(events: [TabEvent(string: 0, position: 0, value: '5h7')]),
      ];
      final regular = pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
          ),
          bold = pw.Font.ttf(
            await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
          );
      for (final style in ['standard', 'compact', 'minimal', 'bandbook']) {
        final bytes = await MusicPdfService.generate(
          [song],
          PdfOptions(style: style, notes: true, contents: true),
          regular: regular,
          bold: bold,
        );
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        expect(bytes.length, greaterThan(5000));
        final raw = latin1.decode(bytes);
        expect(
          RegExp(r'/Type\s*/Page\b').allMatches(raw).length,
          greaterThan(2),
        );
      }
    },
  );
  test('A5 landscape book accepts multiple songs and large font', () async {
    final songs = [Song(title: 'Eerste'), Song(title: 'Tweede')];
    final bytes = await MusicPdfService.build(
      songs,
      PdfOptions(
        a5: true,
        landscape: true,
        fontSize: 22,
        margin: 30,
        contents: true,
      ),
    );
    expect(bytes, isNotEmpty);
    expect(
      RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
      3,
    );
  });
}
