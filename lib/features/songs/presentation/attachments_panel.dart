import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/localization/context_l10n.dart';
import '../../../core/services/attachment_service.dart';
import '../../../core/widgets/common.dart';
import '../domain/song.dart';

class AttachmentsPanel extends StatelessWidget {
  const AttachmentsPanel({
    super.key,
    required this.song,
    required this.onChanged,
  });
  final Song song;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final files = song.attachments.where((a) => a.kind != 'audio').toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        OutlinedButton.icon(
          onPressed: () => guard(context, () async {
            final file = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
            );
            if (file != null) {
              song.attachments.add(await AttachmentService.copy(file));
              onChanged();
            }
          }),
          icon: const Icon(Icons.attach_file_rounded),
          label: Text(context.l.attach),
        ),
        const SizedBox(height: 20),
        if (files.isEmpty) Text(context.l.noAttachments),
        ...files.map(
          (a) => Card(
            child: ListTile(
              leading: Icon(
                a.kind == 'pdf'
                    ? Icons.picture_as_pdf_outlined
                    : Icons.image_outlined,
              ),
              title: Text(a.name),
              onTap: () => guard(context, () async {
                if (!await File(a.path).exists()) {
                  if (context.mounted) {
                    message(context, context.l.attachmentMissing);
                  }
                  return;
                }
                if (!context.mounted) {
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (ctx) => Scaffold(
                      appBar: AppBar(title: Text(a.name)),
                      body: a.kind == 'pdf'
                          ? PdfViewer.file(a.path)
                          : InteractiveViewer(
                              child: Center(child: Image.file(File(a.path))),
                            ),
                    ),
                  ),
                );
              }),
              trailing: IconButton(
                tooltip: context.l.delete,
                onPressed: () async {
                  if (await confirm(
                    context,
                    context.l.confirmDelete,
                    context.l.confirmDeleteBody,
                  )) {
                    song.attachments.remove(a);
                    onChanged();
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
