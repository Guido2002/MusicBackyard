import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/songs/domain/song.dart';

class AttachmentService {
  static Future<Directory> directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'attachments')).create(recursive: true);
  }

  static Future<Attachment> copy(PlatformFile source, {String? kind}) async {
    final dir = await directory();
    final id = newId(), extension = p.extension(source.name).toLowerCase();
    final path = p.join(dir.path, '$id$extension');
    await File(path).writeAsBytes(await source.readAsBytes(), flush: true);
    return Attachment(
      id: id,
      name: source.name,
      path: path,
      kind: kind ?? (extension == '.pdf' ? 'pdf' : 'image'),
    );
  }
}
