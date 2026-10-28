import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/library_controller.dart';
import 'package:music_backyard/features/songs/domain/song.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('musicbackyard-test');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'Offline CRUD survives database reopen, including trash and tabs',
    () async {
      final file = File('${temp.path}/library.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      var repository = MusicRepository(db);
      final song = Song(
        title: 'Repetitie',
        artist: 'Zoë',
        notes: 'Zacht intro',
        tags: ['Band'],
      );
      song.arrangements.first.measures.add(
        TabMeasure(events: [TabEvent(string: 0, position: 1, value: '12')]),
      );
      await repository.saveSong(song);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repository = MusicRepository(db);
      final c = LibraryController(repository);
      await c.load();
      expect(c.error, isNull);
      expect(c.songs.single.title, 'Repetitie');
      expect(
        c.songs.single.arrangements.first.measures.single.events.single.value,
        '12',
      );
      final changed = c.songs.single.clone()
        ..title = 'Optreden'
        ..deleted = true;
      await c.saveSong(changed);
      expect(c.songs.single.deleted, isTrue);
      changed.deleted = false;
      await c.saveSong(changed);
      expect((await repository.read('songs')).single['deleted'], isFalse);
      expect(c.songs.single.searchable, contains('zacht intro'));
      await c.deleteForever(song.id);
      expect(await repository.read('songs'), isEmpty);
      c.dispose();
      await db.close();
    },
  );
  test('v1 to v2 migration preserves songs and adds preferences', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 1');
          for (final table in ['songs', 'folders', 'setlists']) {
            raw.execute(
              'CREATE TABLE $table (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)',
            );
          }
          raw.execute("INSERT INTO songs VALUES ('existing', ?)", [
            '{"id":"existing","title":"Preserved","arrangements":[]}',
          ]);
        },
      ),
    );
    final repository = MusicRepository(db);
    expect((await repository.read('songs')).single['title'], 'Preserved');
    await repository.write('preferences', 'main', {'theme': 'dark'});
    expect((await repository.read('preferences')).single['theme'], 'dark');
    await db.close();
  });
  test('Setlist order, pauses and overrides survive reopen', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = MusicRepository(db);
    final setlist = MusicSetlist(
      name: 'Live',
      entries: [
        SetlistEntry(songId: 'b', transpose: 3, capo: 2),
        SetlistEntry(breakSeconds: 600),
        SetlistEntry(songId: 'a'),
      ],
    );
    await repository.write('setlists', setlist.id, setlist.toJson());
    final result = MusicSetlist.fromJson(
      (await repository.read('setlists')).single,
    );
    expect(result.entries.map((e) => e.songId), ['b', null, 'a']);
    expect(result.entries.first.transpose, 3);
    expect(result.entries.first.capo, 2);
    expect(result.entries[1].breakSeconds, 600);
    await db.close();
  });
  test(
    'Bulk restore rollback preserves active library on write failure',
    () async {
      final db = AppDatabase(NativeDatabase.memory()),
          song = Song(title: 'Original');
      final repository = MusicRepository(db);
      await repository.saveSong(song);
      await db.customStatement(
        "CREATE TRIGGER reject_bad BEFORE INSERT ON songs WHEN NEW.id='bad' BEGIN SELECT RAISE(ABORT,'Rejected'); END",
      );
      await expectLater(
        repository.replaceAll(
          songs: [Song(id: 'bad', title: 'New')],
          folders: [],
          setlists: [],
        ),
        throwsA(anything),
      );
      expect((await repository.read('songs')).single['title'], 'Original');
      await db.close();
    },
  );
  test('Search includes lyrics and tags, sorted by latest opened', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = MusicRepository(db);
    final c = LibraryController(repository);
    final a = Song(title: 'A', openedAt: DateTime(2025)),
        b = Song(title: 'B', openedAt: DateTime(2026), tags: ['Akoestisch']);
    b.arrangements.first.sections.first.lines.first.text = 'Bijzondere tekst';
    await c.saveSong(a);
    await c.saveSong(b);
    expect(
      c.songs.where((s) => s.searchable.contains('bijzondere')).single.id,
      b.id,
    );
    expect(
      c.songs.where((s) => s.searchable.contains('akoestisch')).single.id,
      b.id,
    );
    c.songs.sort((a, b) => b.openedAt!.compareTo(a.openedAt!));
    expect(c.songs.first.id, b.id);
    c.dispose();
    await db.close();
  });
}
