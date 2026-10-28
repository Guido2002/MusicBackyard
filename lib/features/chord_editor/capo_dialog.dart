import 'package:flutter/material.dart';

import '../../app/localization/context_l10n.dart';
import '../songs/domain/music_theory.dart';
import '../songs/domain/song.dart';

class CapoChange {
  const CapoChange(this.capo, this.preservePitch);
  final int capo;
  final bool preservePitch;
}

Future<CapoChange?> showCapoDialog(
  BuildContext context,
  Song song,
  SongArrangement arrangement,
) => showDialog<CapoChange>(
  context: context,
  builder: (_) => _CapoDialog(song: song, arrangement: arrangement),
);

class _CapoDialog extends StatefulWidget {
  const _CapoDialog({required this.song, required this.arrangement});
  final Song song;
  final SongArrangement arrangement;
  @override
  State<_CapoDialog> createState() => _CapoDialogState();
}

class _CapoDialogState extends State<_CapoDialog> {
  late int capo = widget.song.capo;
  bool preservePitch = true;
  @override
  Widget build(BuildContext context) {
    final l = context.l, s = widget.song;
    final delta = preservePitch ? s.capo - capo : 0;
    final played = MusicTheory.transpose(s.currentKey, delta);
    final suggestions = MusicTheory.suggestedCapos(
      widget.arrangement,
      currentCapo: s.capo,
    ).where((c) => c != s.capo).toList();
    return AlertDialog(
      title: Text(l.capo),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l.capo}: $capo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Slider(
                value: capo.toDouble(),
                min: 0,
                max: 12,
                divisions: 12,
                label: '$capo',
                onChanged: (v) => setState(() => capo = v.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.preservePitch),
                subtitle: Text(l.preservePitchHelp),
                value: preservePitch,
                onChanged: (v) => setState(() => preservePitch = v),
              ),
              const SizedBox(height: 12),
              Text('${l.playedKey}: $played'),
              Text(
                '${l.soundingKey}: ${MusicTheory.soundingKey(played, capo)}',
              ),
              const SizedBox(height: 20),
              Text(
                l.capoSuggestions,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (suggestions.isEmpty)
                Text(l.noCapoSuggestions)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map(
                        (c) => ActionChip(
                          label: Text(
                            '${l.capo} $c · ${MusicTheory.transpose(s.currentKey, s.capo - c)}',
                          ),
                          onPressed: () => setState(() {
                            capo = c;
                            preservePitch = true;
                          }),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, CapoChange(capo, preservePitch)),
          child: Text(l.apply),
        ),
      ],
    );
  }
}
