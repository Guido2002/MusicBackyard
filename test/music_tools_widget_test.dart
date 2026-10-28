import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/app/localization/app_localizations.dart';
import 'package:music_backyard/app/theme/app_theme.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/library_controller.dart';
import 'package:music_backyard/features/library/folder_manager_screen.dart';
import 'package:music_backyard/features/chord_editor/capo_dialog.dart';
import 'package:music_backyard/features/songs/domain/song.dart';
import 'package:music_backyard/features/tablature/tab_editor.dart';
import 'package:music_backyard/features/tablature/tab_codec.dart';

Widget app(Widget child) => MaterialApp(
  theme: AppTheme.build(Brightness.light),
  locale: const Locale('nl'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
Future<void> settleWrite(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Folder menu renames and removes only the container', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final library = LibraryController(MusicRepository(db));
    final root = Folder(name: 'Band'), child = Folder(name: 'Live');
    child.parentId = root.id;
    final song = Song(title: 'Keep me', folderId: root.id);
    await tester.runAsync(() async {
      await library.load();
      await library.saveFolder(root);
      await library.saveFolder(child);
      await library.saveSong(song);
    });
    await tester.pumpWidget(app(FolderManagerScreen(library: library)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Live'),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hernoemen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Optredens');
    await tester.tap(find.text('Opslaan'));
    await settleWrite(tester);
    expect(
      library.folders.singleWhere((f) => f.id == child.id).name,
      'Optredens',
    );
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Band'),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verwijderen'));
    await tester.pumpAndSettle();
    expect(find.text('Map verwijderen?'), findsOneWidget);
    await tester.tap(find.text('Toepassen'));
    await settleWrite(tester);
    expect(library.folders.single.id, child.id);
    expect(library.folders.single.parentId, isNull);
    expect(library.song(song.id)!.folderId, isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    await tester.runAsync(() async {
      await db.close();
    });
  });
  testWidgets(
    'Tab paste validates, appends, replaces and keeps invalid input intact',
    (tester) async {
      final arrangement = SongArrangement(
        name: 'A',
        measures: [
          TabMeasure(events: [TabEvent(string: 0, position: 0, value: '3')]),
        ],
      );
      final incoming = SongArrangement(
        name: 'B',
        measures: [
          TabMeasure(events: [TabEvent(string: 5, position: 7, value: '12')]),
        ],
      );
      String clipboard = TabCodec.encode(incoming);
      int changes = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboard};
          }
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (ctx, set) => Scaffold(
              body: TabEditor(
                arrangement: arrangement,
                beforeChange: () => changes++,
                onChanged: () => set(() {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tabs plakken'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toepassen'));
      await tester.pumpAndSettle();
      expect(arrangement.measures.length, 2);
      expect(changes, 1);
      clipboard = 'not valid';
      await tester.tap(find.text('Tabs plakken'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toepassen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Controleer de zes snaren'), findsOneWidget);
      expect(arrangement.measures.length, 2);
      expect(changes, 1);
      await tester.tap(find.text('Annuleren'));
      await tester.pumpAndSettle();
      clipboard = TabCodec.encode(incoming);
      await tester.tap(find.text('Tabs plakken'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bestaande tabs vervangen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toepassen'));
      await tester.pumpAndSettle();
      expect(arrangement.measures.length, 1);
      expect(arrangement.measures.single.events.single.value, '12');
      expect(changes, 2);
      await tester.tap(find.text('Tabs kopiëren'));
      await tester.pumpAndSettle();
      expect(clipboard, TabCodec.encode(arrangement));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Capo review cancels without changing song data', (tester) async {
    final song = Song(currentKey: 'F');
    song.arrangements.first.sections.first.lines.first.chords.add(
      ChordAnchor(0, 'F'),
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCapoDialog(ctx, song, song.arrangements.first),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Klinkende toonsoort behouden'), findsOneWidget);
    await tester.tap(find.text('Capo 1 · E'));
    await tester.pumpAndSettle();
    expect(find.text('Gespeelde grepen: E'), findsOneWidget);
    await tester.tap(find.text('Annuleren'));
    await tester.pumpAndSettle();
    expect(song.capo, 0);
    expect(song.currentKey, 'F');
    expect(tester.takeException(), isNull);
  });
}
