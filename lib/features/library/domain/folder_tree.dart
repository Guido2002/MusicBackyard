import '../../songs/domain/song.dart';

/// Validates parent changes and resolves paths without trusting stored graphs.
class FolderTree {
  FolderTree(Iterable<Folder> folders)
    : byId = {for (final f in folders) f.id: f};
  final Map<String, Folder> byId;

  void validate(Folder folder) {
    if (folder.name.trim().isEmpty) {
      throw ArgumentError('Empty folder name');
    }
    final seen = {folder.id};
    var parent = folder.parentId;
    while (parent != null) {
      if (!seen.add(parent)) {
        throw ArgumentError('Folder cycle');
      }
      final ancestor = byId[parent];
      if (ancestor == null) {
        throw ArgumentError('Missing parent');
      }
      parent = ancestor.parentId;
    }
  }

  Set<String> descendants(String id) {
    final result = <String>{}, pending = [id];
    while (pending.isNotEmpty) {
      final parent = pending.removeLast();
      for (final folder in byId.values.where((f) => f.parentId == parent)) {
        if (folder.id != id && result.add(folder.id)) {
          pending.add(folder.id);
        }
      }
    }
    return result;
  }

  String path(String id) {
    final names = <String>[], seen = <String>{};
    var folder = byId[id];
    while (folder != null && seen.add(folder.id)) {
      names.insert(0, folder.name);
      folder = byId[folder.parentId];
    }
    return names.join(' / ');
  }
}
