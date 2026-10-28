import 'dart:convert';

import '../../features/songs/domain/song.dart';
import 'app_database.dart';

class MusicRepository {
  MusicRepository(this.database);
  final AppDatabase database;
  static const tables = {'songs', 'folders', 'setlists', 'preferences'};
  Future<List<Map<String, dynamic>>> read(String table) async {
    if (!tables.contains(table)) {
      throw ArgumentError.value(table);
    }
    final rows = await database
        .customSelect('SELECT payload FROM $table')
        .get();
    return rows
        .map(
          (r) =>
              Map<String, dynamic>.from(jsonDecode(r.read<String>('payload'))),
        )
        .toList();
  }

  Future<void> write(
    String table,
    String id,
    Map<String, dynamic> value,
  ) async {
    if (!tables.contains(table)) {
      throw ArgumentError.value(table);
    }
    await database.customStatement(
      'INSERT INTO $table (id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
      [id, jsonEncode(value)],
    );
  }

  Future<void> remove(String table, String id) async {
    if (!tables.contains(table)) {
      throw ArgumentError.value(table);
    }
    await database.customStatement('DELETE FROM $table WHERE id=?', [id]);
  }

  Future<void> saveSong(Song song) => write('songs', song.id, song.toJson());
  Future<void> replaceAll({
    required List<Song> songs,
    required List<Folder> folders,
    required List<MusicSetlist> setlists,
  }) => database.transaction(() async {
    for (final table in ['songs', 'folders', 'setlists']) {
      await database.customStatement('DELETE FROM $table');
    }
    for (final song in songs) {
      await saveSong(song);
    }
    for (final folder in folders) {
      await write('folders', folder.id, folder.toJson());
    }
    for (final setlist in setlists) {
      await write('setlists', setlist.id, setlist.toJson());
    }
  });
}
