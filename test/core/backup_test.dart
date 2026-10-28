import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_backyard/core/database/app_database.dart';
import 'package:music_backyard/core/database/music_repository.dart';
import 'package:music_backyard/core/services/backup_service.dart';
import 'package:music_backyard/core/services/library_controller.dart';
import 'package:music_backyard/features/songs/domain/song.dart';

void main() {
  late Directory directory;
  late LibraryController library;
  late BackupService backup;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('musicbackyard-backup');
    library = LibraryController(
      MusicRepository(AppDatabase(NativeDatabase.memory())),
    );
    await library.load();
    backup = BackupService(library, attachmentDirectory: () async => directory);
  });
  tearDown(() async {
    library.dispose();
    await library.repository.database.close();
    await directory.delete(recursive: true);
  });
  test(
    'Portable backup restores binary attachments using fresh private paths',
    () async {
      final original = File('${directory.path}/old.pdf');
      await original.writeAsBytes([1, 2, 3, 255]);
      final song = Song(
        title: 'Eigen lied',
        attachments: [
          Attachment(name: 'Bladmuziek.pdf', path: original.path, kind: 'pdf'),
        ],
      );
      await library.saveSong(song);
      final bytes = await backup.createBytes();
      await library.deleteForever(song.id);
      await original.delete();
      await backup.restoreBytes(bytes);
      final result = library.songs.single;
      expect(result.id, song.id);
      expect(result.attachments.single.path, isNot(original.path));
      expect(await File(result.attachments.single.path).readAsBytes(), [
        1,
        2,
        3,
        255,
      ]);
    },
  );
  test(
    'Malformed backup and missing attachment never replace active songs',
    () async {
      await library.saveSong(Song(title: 'Keep this'));
      await expectLater(
        backup.restoreBytes(utf8.encode('broken')),
        throwsFormatException,
      );
      expect(library.songs.single.title, 'Keep this');
      final song = Song(
        title: 'Do not import',
        attachments: [
          Attachment(name: 'Missing.pdf', path: '/untrusted/path', kind: 'pdf'),
        ],
      );
      final raw = {
        'format': 'musicbackyard',
        'version': 1,
        'songs': [song.toJson()],
        'folders': [],
        'setlists': [],
        'files': {},
      };
      await expectLater(
        backup.restoreBytes(utf8.encode(jsonEncode(raw))),
        throwsFormatException,
      );
      expect(library.songs.single.title, 'Keep this');
      expect(
        (await library.repository.read('songs')).single['title'],
        'Keep this',
      );
    },
  );
  test('Duplicate identities are rejected before restoring any data', () async {
    final song = Song(title: 'Duplicate');
    final raw = {
      'format': 'musicbackyard',
      'version': 1,
      'songs': [song.toJson(), song.toJson()],
      'folders': [],
      'setlists': [],
      'files': {},
    };
    await expectLater(
      backup.restoreBytes(utf8.encode(jsonEncode(raw))),
      throwsFormatException,
    );
    expect(library.songs, isEmpty);
  });
}
