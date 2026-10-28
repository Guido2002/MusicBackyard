import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import 'tab_codec.dart';
import 'tab_clipboard_dialog.dart';

class TabEditor extends StatefulWidget {
  const TabEditor({
    super.key,
    required this.arrangement,
    required this.beforeChange,
    required this.onChanged,
  });
  final SongArrangement arrangement;
  final VoidCallback beforeChange, onChanged;
  @override
  State<TabEditor> createState() => _TabEditorState();
}

class _TabEditorState extends State<TabEditor> {
  SongArrangement get arrangement => widget.arrangement;
  VoidCallback get beforeChange => widget.beforeChange;
  VoidCallback get onChanged => widget.onChanged;
  double zoom = 1;
  bool textView = false;
  @override
  Widget build(BuildContext context) {
    final labels = arrangement.tuning.split(' ').reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: arrangement.measures.isEmpty
                  ? null
                  : () => guard(context, () async {
                      await Clipboard.setData(
                        ClipboardData(text: TabCodec.encode(arrangement)),
                      );
                      if (context.mounted) {
                        message(context, context.l.copiedTabs);
                      }
                    }),
              icon: const Icon(Icons.copy_outlined),
              label: Text(context.l.copyTabs),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  pasteTab(context, arrangement, beforeChange, onChanged),
              icon: const Icon(Icons.content_paste),
              label: Text(context.l.pasteTabs),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l.tabTextView),
          value: textView,
          onChanged: (value) => setState(() => textView = value),
        ),
        Row(
          children: [
            Text(context.l.zoom),
            Expanded(
              child: Slider(
                label: '${(zoom * 100).round()}%',
                value: zoom,
                min: 1,
                max: 1.8,
                divisions: 8,
                onChanged: (value) => setState(() => zoom = value),
              ),
            ),
            Text('${(zoom * 100).round()}%'),
          ],
        ),
        Text(context.l.tabHelp),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey(arrangement.tuning),
          initialValue:
              [
                'E A D G B e',
                'D A D G B e',
                'Eb Ab Db Gb Bb eb',
                'D G D G B d',
              ].contains(arrangement.tuning)
              ? arrangement.tuning
              : 'custom',
          decoration: InputDecoration(labelText: context.l.tuning),
          items: [
            for (final pair in [
              ('E A D G B e', context.l.standardTuning),
              ('D A D G B e', 'Drop D'),
              ('Eb Ab Db Gb Bb eb', 'Half Step Down'),
              ('D G D G B d', 'Open G'),
              ('custom', context.l.customTuning),
            ])
              DropdownMenuItem(value: pair.$1, child: Text(pair.$2)),
          ],
          onChanged: (v) async {
            if (v == null) {
              return;
            }
            if (v == 'custom') {
              final custom = await askText(
                context,
                context.l.customTuning,
                initial: arrangement.tuning,
              );
              if (custom == null) {
                return;
              }
              if (!TabCodec.validTuning(custom)) {
                if (context.mounted) {
                  message(context, context.l.invalidTuning);
                }
                return;
              }
              v = custom.trim().split(RegExp(r'\s+')).join(' ');
            }
            beforeChange();
            arrangement.tuning = v;
            onChanged();
          },
        ),
        const SizedBox(height: 24),
        if (textView && arrangement.measures.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              TabCodec.encode(arrangement),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14 * zoom,
                height: 1.8,
              ),
            ),
          ),
        if (!textView)
          ...arrangement.measures.asMap().entries.map(
            (entry) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '${entry.key + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: context.l.removeMeasure,
                          onPressed: () {
                            beforeChange();
                            arrangement.measures.remove(entry.value);
                            onChanged();
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: List.generate(
                          6,
                          (string) => Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  labels.length == 6 ? labels[string] : '?',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              ...List.generate(8, (position) {
                                final event = entry.value.events
                                    .where(
                                      (e) =>
                                          e.string == string &&
                                          e.position == position,
                                    )
                                    .firstOrNull;
                                return SizedBox(
                                  width: 48 * zoom,
                                  height: 48 * zoom,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: const RoundedRectangleBorder(),
                                    ),
                                    onPressed: () async {
                                      final value = await askText(
                                        context,
                                        context.l.fret,
                                        initial: event?.value ?? '',
                                      );
                                      if (value == null) {
                                        return;
                                      }
                                      if (value.isNotEmpty &&
                                          !TabCodec.validValue(value)) {
                                        if (context.mounted) {
                                          message(
                                            context,
                                            context.l.invalidFret,
                                          );
                                        }
                                        return;
                                      }
                                      beforeChange();
                                      entry.value.events.removeWhere(
                                        (e) =>
                                            e.string == string &&
                                            e.position == position,
                                      );
                                      if (value.isNotEmpty) {
                                        entry.value.events.add(
                                          TabEvent(
                                            string: string,
                                            position: position,
                                            value: value,
                                          ),
                                        );
                                      }
                                      onChanged();
                                    },
                                    child: Text(
                                      event?.value ?? '—',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14 * zoom,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            beforeChange();
            arrangement.measures.add(TabMeasure());
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: Text(context.l.addMeasure),
        ),
      ],
    );
  }
}
