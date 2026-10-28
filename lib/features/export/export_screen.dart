import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/widgets/common.dart';

import 'package:printing/printing.dart';

import '../../app/localization/context_l10n.dart';
import '../songs/domain/song.dart';
import 'pdf_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.songs});
  final List<Song> songs;
  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final options = PdfOptions();
  int revision = 0;
  void change(VoidCallback action) => setState(() {
    action();
    revision++;
  });
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final controls = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<PdfContent>(
          initialValue: options.content,
          decoration: InputDecoration(labelText: l.pdfContent),
          items: [
            DropdownMenuItem(
              value: PdfContent.lyricsAndChords,
              child: Text(l.both),
            ),
            DropdownMenuItem(
              value: PdfContent.lyricsOnly,
              child: Text(l.lyricsOnly),
            ),
            DropdownMenuItem(
              value: PdfContent.chordsOnly,
              child: Text(l.chordsOnly),
            ),
            DropdownMenuItem(
              value: PdfContent.tabsOnly,
              enabled: widget.songs.any(
                (s) => s.arrangements.first.measures.isNotEmpty,
              ),
              child: Text(l.tabsOnly),
            ),
          ],
          onChanged: (v) {
            if (v != null) {
              change(() => options.content = v);
            }
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: options.style,
          decoration: InputDecoration(labelText: l.exportStyle),
          items:
              [
                    ('standard', l.standard),
                    ('compact', l.compact),
                    ('minimal', l.minimal),
                    ('bandbook', l.bandbook),
                  ]
                  .map((p) => DropdownMenuItem(value: p.$1, child: Text(p.$2)))
                  .toList(),
          onChanged: (v) => change(() => options.style = v!),
        ),
        SwitchListTile(
          title: Text('${l.paper}: A5'),
          subtitle: const Text('A4 / A5'),
          value: options.a5,
          onChanged: (v) => change(() => options.a5 = v),
        ),
        SwitchListTile(
          title: Text(l.landscape),
          value: options.landscape,
          onChanged: (v) => change(() => options.landscape = v),
        ),
        SwitchListTile(
          title: Text(l.includeNotes),
          value: options.notes,
          onChanged: (v) => change(() => options.notes = v),
        ),
        SwitchListTile(
          title: Text(l.includeTabs),
          value:
              options.content == PdfContent.tabsOnly ||
              options.content == PdfContent.lyricsAndChords && options.tabs,
          onChanged: options.content != PdfContent.lyricsAndChords
              ? null
              : (v) => change(() => options.tabs = v),
        ),
        SwitchListTile(
          title: Text(l.pageNumbers),
          value: options.pageNumbers,
          onChanged: (v) => change(() => options.pageNumbers = v),
        ),
        SwitchListTile(
          title: Text(l.tableOfContents),
          value: options.contents,
          onChanged: (v) => change(() => options.contents = v),
        ),
        Text('${l.fontSize}: ${options.fontSize.round()}'),
        Slider(
          value: options.fontSize,
          min: 8,
          max: 22,
          divisions: 14,
          onChanged: (v) => change(() => options.fontSize = v),
        ),
        Text('${l.margin}: ${options.margin.round()}'),
        Slider(
          value: options.margin,
          min: 8,
          max: 30,
          divisions: 22,
          onChanged: (v) => change(() => options.margin = v),
        ),
        Text('${l.lineSpacing}: ${options.lineSpacing.toStringAsFixed(1)}'),
        Slider(
          value: options.lineSpacing,
          min: 1,
          max: 2,
          divisions: 10,
          onChanged: (v) => change(() => options.lineSpacing = v),
        ),
        TextField(
          decoration: InputDecoration(labelText: l.header),
          onChanged: (v) => change(() => options.header = v),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(labelText: l.footer),
          onChanged: (v) => change(() => options.footer = v),
        ),
      ],
    );
    final preview = PdfPreview(
      key: ValueKey(revision),
      build: (_) => MusicPdfService.build(widget.songs, options),
      canChangePageFormat: false,
      canChangeOrientation: false,
      allowSharing: false,
      allowPrinting: false,
      canDebug: false,
      actions: [
        Tooltip(
          message: l.print,
          child: PdfPrintAction(
            jobName: 'MusicBackyard',
            onPrintError: (error) => message(context, l.exportError),
          ),
        ),
        Tooltip(
          message: l.share,
          child: PdfShareAction(
            filename: 'MusicBackyard.pdf',
            onShareError: (error) => message(context, l.exportError),
          ),
        ),
      ],
      pdfFileName: 'MusicBackyard.pdf',
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (ctx, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(ctx.l.exportError, textAlign: TextAlign.center),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.pdfExport),
        actions: [
          IconButton(
            tooltip: l.save,
            onPressed: () => guard(context, () async {
              final bytes = await MusicPdfService.build(widget.songs, options);
              await FilePicker.saveFile(
                fileName: 'MusicBackyard.pdf',
                bytes: bytes,
              );
            }),
            icon: const Icon(Icons.save_alt),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (ctx, size) => size.maxWidth >= 800
            ? Row(
                children: [
                  SizedBox(width: 310, child: controls),
                  Expanded(child: preview),
                ],
              )
            : Column(
                children: [
                  SizedBox(height: 260, child: controls),
                  Expanded(child: preview),
                ],
              ),
      ),
    );
  }
}
