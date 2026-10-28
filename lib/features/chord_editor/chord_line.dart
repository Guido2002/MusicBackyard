import 'package:flutter/material.dart';

import '../../app/localization/context_l10n.dart';
import '../songs/domain/song.dart';
import 'chord_diagram.dart';

class ChordLine extends StatelessWidget {
  const ChordLine({
    super.key,
    required this.line,
    this.fontSize = 18,
    this.mode = 'both',
    this.onChord,
    this.onTextPosition,
  });
  final LyricLine line;
  final double fontSize;
  final String mode;
  final void Function(ChordAnchor)? onChord;
  final void Function(int)? onTextPosition;
  @override
  Widget build(BuildContext context) {
    final anchors = [...line.chords]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    final boundaries = {
      0,
      line.text.length,
      ...anchors.map((a) => a.offset.clamp(0, line.text.length)),
      ...RegExp(r'\s+').allMatches(line.text).map((m) => m.end),
    }.toList()..sort();
    Widget lyric(String text, int offset) {
      final child = Text(
        text,
        style: TextStyle(fontSize: fontSize, height: 1.6),
      );
      return onTextPosition == null
          ? child
          : GestureDetector(onTap: () => onTextPosition!(offset), child: child);
    }

    final widgets = <Widget>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i],
          end = i + 1 < boundaries.length ? boundaries[i + 1] : start;
      final chords = anchors.where((a) => a.offset == start).toList();
      final text = line.text.substring(start, end);
      if (text.isEmpty && chords.isEmpty) {
        continue;
      }
      if (mode == 'lyrics') {
        widgets.add(lyric(text, start));
        continue;
      }
      widgets.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chords.isNotEmpty)
              GestureDetector(
                onTap: () => onChord != null
                    ? onChord!(chords.first)
                    : showChordDiagram(context, chords.first.chord),
                child: Semantics(
                  button: true,
                  label:
                      '${context.l.chord}: ${chords.map((a) => a.chord).join(' ')}',
                  child: Text(
                    chords.map((a) => a.chord).join(' '),
                    style: TextStyle(
                      fontSize: fontSize * .85,
                      height: 1.5,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              )
            else if (mode == 'both')
              Text(
                ' ',
                style: TextStyle(fontSize: fontSize * .85, height: 1.5),
              ),
            if (mode == 'both') lyric(text, start),
          ],
        ),
      );
    }
    if (widgets.isEmpty) {
      return SizedBox(height: fontSize * 1.6);
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: mode == 'chords' ? 14 : 0,
      children: widgets,
    );
  }
}
