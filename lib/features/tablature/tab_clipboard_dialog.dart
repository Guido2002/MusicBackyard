import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import 'tab_codec.dart';

Future<void> pasteTab(
  BuildContext context,
  SongArrangement arrangement,
  VoidCallback beforeChange,
  VoidCallback onChanged,
) => guard(context, () async {
  var text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
  if (!context.mounted) {
    return;
  }
  var replace = false;
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(ctx.l.pasteTabs),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ctx.l.pasteTabsHelp),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: text,
                  onChanged: (value) => text = value,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: ctx.l.tabs,
                    errorText: error,
                    errorMaxLines: 4,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ctx.l.replaceTabs),
                  subtitle: Text(ctx.l.replaceTabsHelp),
                  value: replace,
                  onChanged: (value) => set(() => replace = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l.cancel),
          ),
          FilledButton(
            onPressed: () {
              try {
                final parsed = TabCodec.parse(text);
                if (!replace &&
                    arrangement.measures.isNotEmpty &&
                    parsed.tuning.toUpperCase() !=
                        arrangement.tuning.toUpperCase()) {
                  set(() => error = ctx.l.tabTuningMismatch);
                  return;
                }
                beforeChange();
                if (replace || arrangement.measures.isEmpty) {
                  arrangement.tuning = parsed.tuning;
                }
                if (replace) {
                  arrangement.measures = parsed.measures;
                } else {
                  arrangement.measures.addAll(parsed.measures);
                }
                onChanged();
                Navigator.pop(ctx);
              } on FormatException {
                set(() => error = ctx.l.invalidTab);
              }
            },
            child: Text(ctx.l.apply),
          ),
        ],
      ),
    ),
  );
});
