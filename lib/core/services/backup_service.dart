import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../features/songs/domain/song.dart';
import 'attachment_service.dart';
import 'library_controller.dart';

class BackupService {
  BackupService(
    this.library, {
    Future<Directory> Function()? attachmentDirectory,
  }) : attachmentDirectory = attachmentDirectory ?? AttachmentService.directory;
  final LibraryController library;
  final Future<Directory> Function() attachmentDirectory;
  Future<void> export() async {
    final bytes = await createBytes();
    await FilePicker.saveFile(
      fileName:
          'MusicBackyard-${DateTime.now().toIso8601String().split('T').first}.mbbackup',
      bytes: bytes,
    );
  }

  Future<Uint8List> createBytes() async {
    final files = <String, String>{};
    for (final song in library.songs) {
      for (final a in song.attachments) {
        final file = File(a.path);
        if (!await file.exists()) {
          throw FileSystemException('Attachment missing', a.path);
        }
        files[a.id] = base64Encode(await file.readAsBytes());
      }
    }
    final backup = {
      'format': 'musicbackyard',
      'version': 1,
      'songs': library.songs.map((s) => s.toJson()).toList(),
      'folders': library.folders.map((f) => f.toJson()).toList(),
      'setlists': library.setlists.map((s) => s.toJson()).toList(),
      'files': files,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(backup)));
  }

  Future<void> restore(PlatformFile source) async =>
      restoreBytes(await source.readAsBytes());
  Future<void> restoreBytes(List<int> bytes) async {
    // Parse everything before touching the active database. Imported paths are ignored.
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map ||
        raw['format'] != 'musicbackyard' ||
        raw['version'] != 1) {
      throw const FormatException('Invalid backup');
    }
    final songs = (raw['songs'] as List)
        .map((j) => Song.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final folders = (raw['folders'] as List)
        .map((j) => Folder.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    final setlists = (raw['setlists'] as List)
        .map((j) => MusicSetlist.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    if (songs.map((s) => s.id).toSet().length != songs.length ||
        folders.map((s) => s.id).toSet().length != folders.length ||
        setlists.map((s) => s.id).toSet().length != setlists.length ||
        songs.any((s) => s.arrangements.isEmpty)) {
      throw const FormatException('Invalid identities');
    }
    final files = Map<String, dynamic>.from(raw['files']);
    final directory = await attachmentDirectory();
    final staged = <File>[];
    try {
      for (final song in songs) {
        for (final a in song.attachments) {
          final encoded = files[a.id];
          if (encoded is! String) {
            throw const FormatException('Missing attachment');
          }
          final bytes = base64Decode(encoded);
          // New names prevent a failed restore from overwriting live attachments.
          final extension = {
            'pdf': '.pdf',
            'audio': '.m4a',
            'image': p.extension(a.name).toLowerCase(),
          }[a.kind];
          if (extension == null ||
              !['.pdf', '.m4a', '.png', '.jpg', '.jpeg'].contains(extension)) {
            throw const FormatException('Invalid attachment type');
          }
          final file = File(p.join(directory.path, '${newId()}$extension'));
          staged.add(file);
          await file.writeAsBytes(bytes, flush: true);
          a.path = file.path;
        }
      }
      await library.repository.replaceAll(
        songs: songs,
        folders: folders,
        setlists: setlists,
      );
    } catch (_) {
      for (final file in staged) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      rethrow;
    }
    await library.load();
  }
}
