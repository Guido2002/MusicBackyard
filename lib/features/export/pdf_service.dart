import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../songs/domain/song.dart';

enum PdfContent { lyricsAndChords, lyricsOnly, chordsOnly, tabsOnly }

class PdfOptions {
  PdfOptions({
    this.style = 'standard',
    this.content = PdfContent.lyricsAndChords,
    this.a5 = false,
    this.landscape = false,
    this.notes = false,
    this.tabs = true,
    this.fontSize = 12,
    this.margin = 16,
    this.lineSpacing = 1.4,
    this.pageNumbers = true,
    this.contents = false,
    this.header = '',
    this.footer = '',
  });
  String style, header, footer;
  PdfContent content;
  bool a5, landscape, notes, tabs, pageNumbers, contents;
  double fontSize, margin, lineSpacing;
}

class MusicPdfService {
  static Future<Uint8List> build(List<Song> songs, PdfOptions options) async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    return Isolate.run(
      () => generate(
        songs,
        options,
        regular: pw.Font.ttf(regularData),
        bold: pw.Font.ttf(boldData),
      ),
    );
  }

  static Future<Uint8List> generate(
    List<Song> songs,
    PdfOptions options, {
    required pw.Font regular,
    required pw.Font bold,
  }) async {
    if (options.content == PdfContent.tabsOnly) {
      songs = songs
          .where(
            (s) =>
                s.arrangements.isNotEmpty &&
                s.arrangements.first.measures.isNotEmpty,
          )
          .toList();
    }
    if (songs.isEmpty) {
      throw ArgumentError('No music to export');
    }
    final doc = pw.Document(
      title: songs.length == 1 ? songs.first.title : 'MusicBackyard',
      author: 'MusicBackyard',
    );
    var format = options.a5 ? PdfPageFormat.a5 : PdfPageFormat.a4;
    if (options.landscape) {
      format = format.landscape;
    }
    final fontSize = options.style == 'compact'
        ? options.fontSize * .85
        : options.fontSize;
    final color = options.style == 'minimal'
        ? PdfColors.black
        : PdfColor.fromHex('#183329');
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    pw.Widget lineWidget(LyricLine line) {
      if (options.content == PdfContent.lyricsOnly) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Text(
            line.text.isEmpty ? ' ' : line.text,
            style: pw.TextStyle(
              fontSize: fontSize,
              lineSpacing: fontSize * (options.lineSpacing - 1),
            ),
          ),
        );
      }
      final anchors = [...line.chords]
        ..sort((a, b) => a.offset.compareTo(b.offset));
      if (options.content == PdfContent.chordsOnly) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Wrap(
            spacing: 14,
            runSpacing: 5,
            children: anchors
                .map(
                  (a) => pw.Text(
                    a.chord,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: fontSize,
                      color: color,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      }
      final boundaries = {
        0,
        line.text.length,
        ...anchors.map((a) => a.offset.clamp(0, line.text.length)),
        ...RegExp(r'\s+').allMatches(line.text).map((m) => m.end),
      }.toList()..sort();
      final children = <pw.Widget>[];
      for (var i = 0; i < boundaries.length; i++) {
        final start = boundaries[i],
            end = i + 1 < boundaries.length ? boundaries[i + 1] : start;
        final chords = anchors
            .where((a) => a.offset == start)
            .map((a) => a.chord)
            .join(' ');
        if (start == end && chords.isEmpty) {
          continue;
        }
        children.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                chords.isEmpty ? ' ' : chords,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: fontSize * .85,
                  color: color,
                ),
              ),
              pw.Text(
                line.text.substring(start, end),
                style: pw.TextStyle(
                  fontSize: fontSize,
                  lineSpacing: fontSize * (options.lineSpacing - 1),
                ),
              ),
            ],
          ),
        );
      }
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: children.isEmpty
            ? pw.SizedBox(height: fontSize)
            : pw.Wrap(children: children),
      );
    }

    if (options.style == 'bandbook') {
      doc.addPage(
        pw.Page(
          pageFormat: format,
          theme: theme,
          build: (ctx) => pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MUSICBACKYARD',
                  style: pw.TextStyle(
                    fontSize: 12,
                    letterSpacing: 3,
                    color: color,
                  ),
                ),
                pw.SizedBox(height: 32),
                pw.Text(
                  'Bandboek',
                  style: pw.TextStyle(
                    fontSize: 42,
                    fontWeight: pw.FontWeight.bold,
                    color: color,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '${songs.length} nummers',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 48),
                pw.Text(
                  'Jouw muziek. Jouw plek.',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if ((options.contents || options.style == 'bandbook') && songs.length > 1) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          theme: theme,
          build: (ctx) => [
            pw.Header(level: 0, child: pw.Text('Inhoudsopgave')),
            for (var i = 0; i < songs.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 7),
                child: pw.Text(
                  '${i + 1}. ${songs[i].title} — ${songs[i].artist}',
                ),
              ),
          ],
        ),
      );
    }
    for (final song in songs) {
      final arrangement = song.arrangements.first;
      final body = <pw.Widget>[
        pw.Text(
          song.title,
          style: pw.TextStyle(
            fontSize: options.style == 'minimal' ? 22 : 28,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(song.artist, style: pw.TextStyle(fontSize: fontSize)),
        pw.SizedBox(height: 8),
        if (options.content != PdfContent.lyricsOnly)
          pw.Text(
            '${song.currentKey}  ·  ${song.bpm} BPM  ·  Capo ${song.capo}  ·  ${song.timeSignature}',
            style: pw.TextStyle(fontSize: fontSize * .8),
          ),
        pw.SizedBox(height: 20),
      ];
      for (final section
          in options.content == PdfContent.tabsOnly
              ? <SongSection>[]
              : arrangement.sections) {
        final lines = section.lines
            .where(
              (line) =>
                  options.content != PdfContent.chordsOnly ||
                  line.chords.isNotEmpty,
            )
            .toList();
        if (options.content == PdfContent.chordsOnly && lines.isEmpty) {
          continue;
        }
        final heading = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 8),
          child: pw.Text(
            section.name.toUpperCase(),
            style: pw.TextStyle(
              fontSize: fontSize * .8,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        );
        // Keep each heading with the first lyric line, then allow long sections to span pages.
        if (lines.isNotEmpty) {
          body.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [heading, lineWidget(lines.first)],
            ),
          );
          body.addAll(lines.skip(1).map(lineWidget));
        } else {
          body.add(heading);
        }
      }
      if (options.content == PdfContent.tabsOnly ||
          options.content == PdfContent.lyricsAndChords && options.tabs) {
        for (final measure in arrangement.measures) {
          final labels = arrangement.tuning.split(' ').reversed.toList();
          body.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: pw.Table(
                border: const pw.TableBorder(
                  horizontalInside: pw.BorderSide(width: .3),
                ),
                columnWidths: {0: const pw.FixedColumnWidth(22)},
                children: List.generate(
                  6,
                  (string) => pw.TableRow(
                    children: [
                      pw.Text(
                        labels.length == 6 ? labels[string] : '',
                        style: pw.TextStyle(fontSize: fontSize),
                      ),
                      ...List.generate(
                        8,
                        (position) => pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            measure.events
                                    .where(
                                      (e) =>
                                          e.string == string &&
                                          e.position == position,
                                    )
                                    .firstOrNull
                                    ?.value ??
                                '—',
                            style: pw.TextStyle(fontSize: fontSize * .8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      }
      if (options.notes && song.notes.isNotEmpty) {
        body.add(pw.SizedBox(height: 18));
        for (final line in song.notes.split('\n')) {
          body.add(pw.Text(line, style: pw.TextStyle(fontSize: fontSize)));
        }
      }
      doc.addPage(
        pw.MultiPage(
          maxPages: 1000,
          pageFormat: format,
          margin: pw.EdgeInsets.all(options.margin * PdfPageFormat.mm),
          theme: theme,
          header: options.header.isEmpty
              ? null
              : (ctx) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    options.header,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
          footer: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  options.footer.isEmpty ? 'MusicBackyard' : options.footer,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                if (options.pageNumbers)
                  pw.Text(
                    '${ctx.pageNumber}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
              ],
            ),
          ),
          build: (ctx) => body,
        ),
      );
    }
    return doc.save();
  }
}
