import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/songs/domain/song.dart';
import '../../features/library/domain/folder_tree.dart';
import '../database/app_database.dart';
import '../database/music_repository.dart';

final libraryProvider = Provider<LibraryController>((ref) {
  final c = LibraryController(MusicRepository(AppDatabase.open()));
  ref.onDispose(c.dispose);
  return c;
});

class LibraryController extends ChangeNotifier {
  LibraryController(this.repository);
  final MusicRepository repository;
  List<Song> songs = [];
  List<Folder> folders = [];
  List<MusicSetlist> setlists = [];
  Map<String, dynamic> preferences = {};
  bool ready = false;
  Object? error;
  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == preferences['theme'],
    orElse: () => ThemeMode.system,
  );
  Future<void> load() async {
    try {
      songs = (await repository.read('songs')).map(Song.fromJson).toList();
      folders = (await repository.read('folders'))
          .map(Folder.fromJson)
          .toList();
      setlists = (await repository.read('setlists'))
          .map(MusicSetlist.fromJson)
          .toList();
      final prefs = await repository.read('preferences');
      preferences = prefs.isEmpty ? {} : prefs.first;
      error = null;
      ready = true;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Song? song(String id) {
    for (final s in songs) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  Future<void> saveSong(Song value, {bool touch = true}) async {
    if (touch) {
      value.updatedAt = DateTime.now();
    }
    await repository.saveSong(value);
    final index = songs.indexWhere((s) => s.id == value.id);
    if (index < 0) {
      songs.add(value);
    } else {
      songs[index] = value;
    }
    notifyListeners();
  }

  Future<void> saveFolder(Folder value) async {
    value = Folder(
      id: value.id,
      name: value.name.trim(),
      parentId: value.parentId,
    );
    await repository.database.transaction(() async {
      final stored = (await repository.read('folders')).map(Folder.fromJson);
      FolderTree(stored).validate(value);
      await repository.write('folders', value.id, value.toJson());
    });
    final i = folders.indexWhere((f) => f.id == value.id);
    if (i < 0) {
      folders.add(value);
    } else {
      folders[i] = value;
    }
    notifyListeners();
  }

  /// Remove only the container. All children and songs survive at its parent.
  Future<void> removeFolder(String id) async {
    late List<Song> movedSongs;
    late List<Folder> movedFolders;
    await repository.database.transaction(() async {
      final storedFolders = (await repository.read('folders'))
          .map(Folder.fromJson)
          .toList();
      final folder = storedFolders.where((f) => f.id == id).firstOrNull;
      if (folder == null) {
        throw ArgumentError('Unknown folder');
      }
      movedSongs = (await repository.read('songs'))
          .map(Song.fromJson)
          .where((s) => s.folderId == id)
          .map((s) => s..folderId = folder.parentId)
          .toList();
      movedFolders = storedFolders
          .where((f) => f.parentId == id)
          .map((f) => Folder(id: f.id, name: f.name, parentId: folder.parentId))
          .toList();
      for (final song in movedSongs) {
        await repository.saveSong(song);
      }
      for (final child in movedFolders) {
        await repository.write('folders', child.id, child.toJson());
      }
      await repository.remove('folders', id);
    });
    final updatedSongs = {for (final s in movedSongs) s.id: s};
    final updatedFolders = {for (final f in movedFolders) f.id: f};
    songs = songs.map((s) => updatedSongs[s.id] ?? s).toList();
    folders = folders
        .where((f) => f.id != id)
        .map((f) => updatedFolders[f.id] ?? f)
        .toList();
    notifyListeners();
  }

  Future<void> saveSetlist(MusicSetlist value) async {
    await repository.write('setlists', value.id, value.toJson());
    final i = setlists.indexWhere((s) => s.id == value.id);
    if (i < 0) {
      setlists.add(value);
    } else {
      setlists[i] = value;
    }
    notifyListeners();
  }

  Future<void> removeSetlist(String id) async {
    await repository.remove('setlists', id);
    setlists.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> deleteForever(String id) async {
    await repository.remove('songs', id);
    songs.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> setPreference(String key, dynamic value) async {
    final updated = {...preferences, key: value};
    await repository.write('preferences', 'main', updated);
    preferences = updated;
    notifyListeners();
  }
}
