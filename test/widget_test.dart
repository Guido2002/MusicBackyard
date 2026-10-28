import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/app/app.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/library_controller.dart';
import 'package:music_backyard/features/songs/domain/song.dart';

void main() {
  testWidgets('Empty library has functional navigation and new song action', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    final library = LibraryController(MusicRepository(db));
    await tester.runAsync(() async {
      await library.load();
      await library.setPreference('onboarded', true);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWithValue(library)],
        child: const MusicBackyardApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hier begint jouw muziek'), findsWidgets);
    expect(find.text('Nieuw nummer'), findsOneWidget);
    await tester.tap(find.text('Nieuw nummer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Mijn eerste lied');
    await tester.tap(find.text('Opslaan'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(library.songs.single.title, 'Mijn eerste lied');
    expect(find.text('Tekst & akkoorden'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    await tester.runAsync(() async {
      await db.close();
    });
  });
  testWidgets('Dutch onboarding works without an account', (tester) async {
    final library = LibraryController(
      MusicRepository(AppDatabase(NativeDatabase.memory())),
    );
    await tester.runAsync(library.load);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWithValue(library)],
        child: const MusicBackyardApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welkom bij MusicBackyard'), findsOneWidget);
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gitaar'));
    await tester.tap(find.text('Volgende'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aan de slag'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(library.preferences['onboarded'], isTrue);
    expect(library.preferences['instrument'], 'Gitaar');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    await tester.runAsync(library.repository.database.close);
  });
  testWidgets('Tablet and large text remain usable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final library = LibraryController(
      MusicRepository(AppDatabase(NativeDatabase.memory())),
    );
    await tester.runAsync(() async {
      await library.load();
      await library.setPreference('onboarded', true);
      await library.saveSong(Song(title: 'Zomeravond', artist: 'Eigen werk'));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWithValue(library)],
        child: const MusicBackyardApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Zomeravond'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    library.dispose();
    await tester.runAsync(library.repository.database.close);
  });
}
