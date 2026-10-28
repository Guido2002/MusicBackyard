import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:music_backyard/features/export/pdf_service.dart';
import 'package:music_backyard/features/export/export_screen.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:music_backyard/app/app.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/library_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: create, edit, anchor, transpose and reopen offline', (
    tester,
  ) async {
    final library = LibraryController(MusicRepository(AppDatabase.open()));
    await library.load();
    expect(library.error, isNull);
    await library.setPreference('onboarded', true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWithValue(library)],
        child: const MusicBackyardApp(),
      ),
    );
    await tester.pumpAndSettle();
    final title = 'Emulatortest ${DateTime.now().millisecondsSinceEpoch}';
    await tester.tap(find.text('Nieuw nummer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, title);
    await tester.tap(find.text('Opslaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plak of schrijf hier je songtekst…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Op een warme zomeravond\nKlinkt een eigen melodie',
    );
    await tester.tap(find.byTooltip('Akkoord op cursor invoegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'C/E');
    await tester.tap(find.text('Opslaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Halve toon hoger'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    final song = library.songs.firstWhere((s) => s.title == title),
        id = library.songs.firstWhere((s) => s.title == title).id;
    expect(song.currentKey, 'C#');
    expect(
      song.arrangements.first.sections.first.lines.last.chords.single.chord,
      'C#/F',
    );
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    await library.repository.database.close();
    final reopened = LibraryController(MusicRepository(AppDatabase.open()));
    await reopened.load();
    expect(reopened.error, isNull);
    final persisted = reopened.song(id)!;
    expect(
      persisted.arrangements.first.sections.first.lines.first.text,
      'Op een warme zomeravond',
    );
    expect(
      persisted
          .arrangements
          .first
          .sections
          .first
          .lines
          .last
          .chords
          .single
          .chord,
      'C#/F',
    );
    // Native gate must reject arbitrary paths before launching any system UI.
    await expectLater(
      const MethodChannel('nl.musicbackyard/updates')
          .invokeMethod<String>('install', {
            'path': '/data/local/tmp/untrusted.apk',
            'sha256': 'a' * 64,
            'buildNumber': 99999,
          }),
      throwsA(isA<PlatformException>()),
    );
    await reopened.deleteForever(id);
    reopened.dispose();
    await reopened.repository.database.close();
  });
  testWidgets(
    'Rendered PDF places each chord directly above its anchored lyric',
    (tester) async {
      final song = Song(title: 'Uitlijning', artist: 'Eigen werk');
      song.arrangements.first.sections.first.lines = [
        LyricLine(
          text: 'Hallo wereld',
          chords: [ChordAnchor(0, 'F#m7'), ChordAnchor(6, 'C/E')],
        ),
      ];
      final bytes = await MusicPdfService.build([song], PdfOptions());
      await pdfrxFlutterInitialize();
      final document = await PdfDocument.openData(bytes);
      try {
        final text = (await document.pages.first.loadText())!;
        final chord = text.fullText.indexOf('C/E'),
            lyric = text.fullText.indexOf('wereld');
        expect(chord, greaterThanOrEqualTo(0));
        expect(lyric, greaterThanOrEqualTo(0));
        expect(
          text.charRects[chord].left,
          closeTo(text.charRects[lyric].left, 1),
        );
        final rendered = (await document.pages.first.render(
          width: 600,
          height: 850,
        ))!;
        expect(rendered.width, greaterThan(0));
        final picture = await rendered.createImage();
        final png = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/musicbackyard-export-preview.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        if (const bool.fromEnvironment('SAVE_QA_ARTIFACTS')) {
          debugPrint(
            'PDF_QA_READY:${Directory.systemTemp.path}/musicbackyard-export-preview.png',
          );
          await Future<void>.delayed(const Duration(seconds: 10));
        }
        picture.dispose();
        rendered.dispose();
      } finally {
        await document.dispose();
      }
    },
  );
  testWidgets('PDF content presets contain only the selected music', (
    tester,
  ) async {
    final song = Song(
      title: 'Presettest',
      artist: 'Eigen werk',
      notes: 'Persoonlijke notitie',
    );
    song.arrangements.first.sections.first.lines = [
      LyricLine(
        text: 'Unieke songtekst',
        chords: [ChordAnchor(0, 'F#m7'), ChordAnchor(7, 'C/E')],
      ),
    ];
    song.arrangements.first.measures = [
      TabMeasure(events: [TabEvent(string: 0, position: 4, value: '23')]),
    ];
    await pdfrxFlutterInitialize();
    for (final content in PdfContent.values) {
      final bytes = await MusicPdfService.build([
        song,
      ], PdfOptions(content: content));
      final document = await PdfDocument.openData(bytes);
      try {
        final buffer = StringBuffer();
        for (final page in document.pages) {
          buffer.writeln((await page.loadText())!.fullText);
        }
        final text = buffer.toString();
        expect(
          text.contains('Unieke'),
          content == PdfContent.lyricsAndChords ||
              content == PdfContent.lyricsOnly,
          reason: content.name,
        );
        expect(
          text.contains('F#m7'),
          content == PdfContent.lyricsAndChords ||
              content == PdfContent.chordsOnly,
          reason: content.name,
        );
        expect(
          text.contains('23'),
          content == PdfContent.lyricsAndChords ||
              content == PdfContent.tabsOnly,
          reason: content.name,
        );
        expect(text.contains('Persoonlijke notitie'), isFalse);
        if (const bool.fromEnvironment('SAVE_QA_ARTIFACTS') &&
            content == PdfContent.lyricsOnly) {
          final render = (await document.pages.first.render(
            width: 600,
            height: 850,
          ))!;
          final picture = await render.createImage();
          final png = await picture.toByteData(format: ui.ImageByteFormat.png);
          final path =
              '${Directory.systemTemp.path}/musicbackyard-lyrics-export.png';
          await File(path).writeAsBytes(png!.buffer.asUint8List());
          picture.dispose();
          render.dispose();
          debugPrint('PDF_QA_READY:$path');
          await Future<void>.delayed(const Duration(seconds: 10));
        }
      } finally {
        await document.dispose();
      }
    }
  });
  testWidgets(
    'Editor opens the selected arrangement in performance and PDF export',
    (tester) async {
      final library = LibraryController(MusicRepository(AppDatabase.open()));
      await library.load();
      await library.setPreference('onboarded', true);
      final song = Song(
        title: 'Arrangementtest',
        arrangements: [
          SongArrangement(
            name: 'Origineel',
            sections: [
              SongSection(
                name: 'Couplet',
                lines: [LyricLine(text: 'OriginalOnly')],
              ),
            ],
          ),
          SongArrangement(
            name: 'Akoestisch',
            sections: [
              SongSection(
                name: 'Couplet',
                lines: [LyricLine(text: 'AcousticOnly')],
              ),
            ],
          ),
        ],
      );
      await library.saveSong(song);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [libraryProvider.overrideWithValue(library)],
          child: const MusicBackyardApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(song.title));
      await tester.tap(find.text(song.title));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akoestisch').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('song-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speelmodus'));
      await tester.pumpAndSettle();
      expect(find.text('AcousticOnly'), findsOneWidget);
      expect(find.text('OriginalOnly'), findsNothing);
      await tester.tap(find.byTooltip('Speelmodus verlaten'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('song-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF Export Studio'));
      await tester.pumpAndSettle();
      final export = tester.widget<ExportScreen>(find.byType(ExportScreen));
      expect(
        export.songs.single.arrangements.single.id,
        song.arrangements.last.id,
      );
      await tester.pumpWidget(const SizedBox());
      await library.deleteForever(song.id);
      library.dispose();
      await library.repository.database.close();
    },
  );
}
