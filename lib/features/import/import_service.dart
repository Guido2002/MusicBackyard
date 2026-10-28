import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/services/library_controller.dart';
import '../../core/services/attachment_service.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import '../songs/domain/chordpro.dart';

class ImportService {
  ImportService(this.library);
  final LibraryController library;
  Future<Song?> importSong(BuildContext context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'cho',
        'chopro',
        'chordpro',
        'pdf',
        'png',
        'jpg',
        'jpeg',
      ],
    );
    if (file == null || !context.mounted) {
      return null;
    }
    final name = file.name, extension = name.split('.').last.toLowerCase();
    Attachment? original;
    String text = '';
    try {
      if (['pdf', 'png', 'jpg', 'jpeg'].contains(extension)) {
        original = await AttachmentService.copy(file);
        if (extension == 'pdf') {
          await pdfrxFlutterInitialize();
          final document = await PdfDocument.openFile(original.path);
          try {
            final buffer = StringBuffer();
            for (final page in document.pages) {
              final pageText = await page.loadText();
              if (pageText != null) {
                buffer.writeln(pageText.fullText);
              }
            }
            text = buffer.toString();
          } finally {
            await document.dispose();
          }
        }
      } else {
        text = utf8.decode(await file.readAsBytes());
      }
      if (!context.mounted) {
        return null;
      }
      final initial = ChordPro.parse(
        text,
        fallbackTitle: name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
      );
      var edited = ChordPro.encode(initial);
      final accepted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: Text(ctx.l.importReview),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.l.save),
                ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    text.trim().isEmpty
                        ? ctx.l.importEmpty
                        : ctx.l.importWarning,
                  ),
                ),
                if (original?.kind == 'pdf')
                  SizedBox(height: 200, child: PdfViewer.file(original!.path)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      initialValue: edited,
                      onChanged: (v) => edited = v,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        labelText: ctx.l.chordpro,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (accepted != true) {
        if (original != null) {
          await File(original.path).delete();
        }
        return null;
      }
      final song = ChordPro.parse(edited, fallbackTitle: initial.title);
      if (song.title.trim().isEmpty) {
        throw const FormatException('Missing title');
      }
      if (original != null) {
        song.attachments.add(original);
      }
      await library.saveSong(song);
      return song;
    } catch (_) {
      if (context.mounted) {
        message(context, context.l.importInvalid);
      }
      return null;
    }
  }
}
