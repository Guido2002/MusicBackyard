import 'package:flutter/material.dart';

import '../../../app/localization/context_l10n.dart';
import '../../../core/widgets/common.dart';
import '../../chord_editor/chord_line.dart';
import '../domain/song.dart';
import '../domain/music_theory.dart';

class SectionEditor extends StatefulWidget {
  const SectionEditor({
    super.key,
    required this.section,
    required this.onBeforeChange,
    required this.onChanged,
    this.fontSize = 18,
    this.mode = 'both',
  });
  final SongSection section;
  final VoidCallback onBeforeChange, onChanged;
  final double fontSize;
  final String mode;
  @override
  State<SectionEditor> createState() => _SectionEditorState();
}

class _SectionEditorState extends State<SectionEditor> {
  late final TextEditingController text = TextEditingController(
    text: widget.section.lines.map((l) => l.text).join('\n'),
  );
  final focus = FocusNode();
  bool editing = false;
  @override
  void didUpdateWidget(covariant SectionEditor old) {
    super.didUpdateWidget(old);
    final value = widget.section.lines.map((l) => l.text).join('\n');
    if (text.text != value) {
      text.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  LyricLine flattened() {
    final chords = <ChordAnchor>[];
    var offset = 0;
    for (final l in widget.section.lines) {
      chords.addAll(
        l.chords.map((a) => ChordAnchor(offset + a.offset, a.chord)),
      );
      offset += l.text.length + 1;
    }
    return LyricLine(
      text: widget.section.lines.map((l) => l.text).join('\n'),
      chords: chords,
    );
  }

  void distribute(LyricLine flat) {
    final lines = <LyricLine>[];
    var offset = 0;
    for (final value in flat.text.split('\n')) {
      lines.add(
        LyricLine(
          text: value,
          chords: flat.chords
              .where(
                (a) => a.offset >= offset && a.offset <= offset + value.length,
              )
              .map((a) => ChordAnchor(a.offset - offset, a.chord))
              .toList(),
        ),
      );
      offset += value.length + 1;
    }
    widget.section.lines = lines;
  }

  Future<void> insertChord() async {
    final cursor = text.selection.isValid
        ? text.selection.baseOffset
        : text.text.length;
    final value = await askText(context, context.l.addChord);
    if (value == null || !mounted) {
      return;
    }
    if (!MusicTheory.validChord(value)) {
      message(context, context.l.invalidChord);
      return;
    }
    widget.onBeforeChange();
    final flat = flattened();
    flat.chords.add(ChordAnchor(cursor.clamp(0, flat.text.length), value));
    distribute(flat);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              editing = !editing;
              if (editing) {
                focus.requestFocus();
              }
            }),
            icon: Icon(
              editing ? Icons.visibility_outlined : Icons.edit_outlined,
              size: 18,
            ),
            label: Text(editing ? context.l.preview : context.l.lyrics),
          ),
          const Spacer(),
          IconButton(
            tooltip: context.l.addChord,
            onPressed: insertChord,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      if (editing)
        TextField(
          controller: text,
          focusNode: focus,
          minLines: 3,
          maxLines: null,
          style: TextStyle(fontSize: widget.fontSize, height: 1.6),
          decoration: InputDecoration(hintText: context.l.lyricsHint),
          onChanged: (value) {
            widget.onBeforeChange();
            final flat = flattened();
            MusicTheory.editLine(flat, value);
            distribute(flat);
            widget.onChanged();
          },
        )
      else
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            editing = true;
            focus.requestFocus();
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.section.lines.every(
                  (l) => l.text.isEmpty && l.chords.isEmpty,
                ))
                  Text(
                    context.l.lyricsHint,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ...widget.section.lines.map(
                  (line) => ChordLine(
                    line: line,
                    fontSize: widget.fontSize,
                    mode: widget.mode,
                    onTextPosition: (offset) async {
                      final value = await askText(context, context.l.addChord);
                      if (value == null || !context.mounted) {
                        return;
                      }
                      if (!MusicTheory.validChord(value)) {
                        message(context, context.l.invalidChord);
                        return;
                      }
                      widget.onBeforeChange();
                      line.chords.add(ChordAnchor(offset, value));
                      widget.onChanged();
                      setState(() {});
                    },
                    onChord: (anchor) async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: Text(anchor.chord),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, 'edit'),
                              child: Text(ctx.l.rename),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, 'delete'),
                              child: Text(ctx.l.delete),
                            ),
                          ],
                        ),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      if (result == 'delete') {
                        widget.onBeforeChange();
                        line.chords.remove(anchor);
                        widget.onChanged();
                        setState(() {});
                      } else if (result == 'edit') {
                        final chord = await askText(
                          context,
                          context.l.chord,
                          initial: anchor.chord,
                        );
                        if (chord != null && MusicTheory.validChord(chord)) {
                          widget.onBeforeChange();
                          anchor.chord = chord;
                          widget.onChanged();
                          if (mounted) {
                            setState(() {});
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
