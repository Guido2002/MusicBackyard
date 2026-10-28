import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/library_controller.dart';
import 'package:music_backyard/features/library/domain/folder_tree.dart';
import 'package:music_backyard/features/songs/domain/song.dart';

void main() {
  late AppDatabase db;
  late LibraryController library;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    library = LibraryController(MusicRepository(db));
    await library.load();
  });
  tearDown(() async {
    library.dispose();
    await db.close();
  });
  test('Rename and reparent survive reload; cycles and missing parents are rejected', () async {
    final parent = Folder(name: 'Band'), child = Folder(name: 'Optredens');
    child.parentId = parent.id;
    await library.saveFolder(parent);
    await library.saveFolder(child);
    await expectLater(
      library.saveFolder(
        Folder(id: parent.id, name: 'Band', parentId: child.id),
      ),
      throwsArgumentError,
    );
    await expectLater(
      library.saveFolder(Folder(name: 'Los', parentId: 'missing')),
      throwsArgumentError,
    );
    await library.saveFolder(Folder(id: child.id, name: '  Live  '));
    await library.load();
    expect(library.folders.singleWhere((f) => f.id == child.id).name, 'Live');
    expect(
      library.folders.singleWhere((f) => f.id == child.id).parentId,
      isNull,
    );
    expect(FolderTree([parent, child]).path(child.id), 'Band / Optredens');
    expect(FolderTree([parent, child]).descendants(parent.id), {child.id});
  });
  test(
    'Removing a populated folder preserves nested folders, songs and trash',
    () async {
      final root = Folder(name: 'Root'),
          parent = Folder(name: 'Live'),
          child = Folder(name: 'Voorprogramma');
      parent.parentId = root.id;
      child.parentId = parent.id;
      for (final folder in [root, parent, child]) {
        await library.saveFolder(folder);
      }
      final song = Song(title: 'Lied', folderId: parent.id),
          trashed = Song(title: 'Oud lied', folderId: parent.id, deleted: true),
          nested = Song(title: 'Intro', folderId: child.id);
      for (final s in [song, trashed, nested]) {
        await library.saveSong(s);
      }
      await library.removeFolder(parent.id);
      await library.load();
      expect(library.folders.map((f) => f.id), isNot(contains(parent.id)));
      expect(
        library.folders.singleWhere((f) => f.id == child.id).parentId,
        root.id,
      );
      expect(library.song(song.id)!.folderId, root.id);
      expect(library.song(trashed.id)!.deleted, isTrue);
      expect(library.song(trashed.id)!.folderId, root.id);
      expect(library.song(nested.id)!.folderId, child.id);
      await library.removeFolder(root.id);
      expect(library.song(song.id)!.folderId, isNull);
    },
  );
  test(
    'Failed deletion rolls back folder moves on disk and in memory',
    () async {
      final folder = Folder(name: 'Keep'),
          child = Folder(name: 'Child', parentId: folder.id);
      await library.saveFolder(folder);
      await library.saveFolder(child);
      final song = Song(title: 'Keep', folderId: folder.id);
      await library.saveSong(song);
      await db.customStatement(
        "CREATE TRIGGER reject_folder_delete BEFORE DELETE ON folders BEGIN SELECT RAISE(ABORT,'Rejected'); END",
      );
      await expectLater(library.removeFolder(folder.id), throwsA(anything));
      expect(library.song(song.id)!.folderId, folder.id);
      expect(
        library.folders.singleWhere((f) => f.id == child.id).parentId,
        folder.id,
      );
      await library.load();
      expect(library.song(song.id)!.folderId, folder.id);
      expect(library.folders.length, 2);
    },
  );
  test('Concurrent parent moves cannot introduce a cycle', () async {
    final a = Folder(name: 'A'), b = Folder(name: 'B');
    await library.saveFolder(a);
    await library.saveFolder(b);
    Future<bool> move(Folder value) async {
      try {
        await library.saveFolder(value);
        return true;
      } on ArgumentError {
        return false;
      }
    }

    final results = await Future.wait([
      move(Folder(id: a.id, name: a.name, parentId: b.id)),
      move(Folder(id: b.id, name: b.name, parentId: a.id)),
    ]);
    expect(results.where((r) => r).length, 1);
    await library.load();
    for (final folder in library.folders) {
      FolderTree(library.folders).validate(folder);
    }
  });
  test('Corrupted graph traversal terminates', () {
    final a = Folder(id: 'a', name: 'A', parentId: 'b'),
        b = Folder(id: 'b', name: 'B', parentId: 'a');
    final tree = FolderTree([a, b]);
    expect(tree.descendants('a'), {'b'});
    expect(tree.path('a'), 'B / A');
    expect(
      () => tree.validate(Folder(name: 'New', parentId: 'a')),
      throwsArgumentError,
    );
  });
}
