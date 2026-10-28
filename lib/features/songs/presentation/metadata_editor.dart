import 'package:flutter/material.dart';

import '../../../app/localization/context_l10n.dart';
import '../domain/song.dart';
import '../domain/music_theory.dart';

Future<void> editMetadata(
  BuildContext context,
  Song song,
  VoidCallback before,
  VoidCallback changed,
) async {
  final l = context.l;
  final labels = [
    l.title,
    l.artist,
    l.album,
    l.genre,
    l.originalKey,
    l.key,
    l.bpm,
    l.timeSignature,
    l.capo,
    l.instrument,
    l.duration,
    l.spotify,
    l.tags,
    l.comments,
  ];
  final values = [
    song.title,
    song.artist,
    song.album,
    song.genre,
    song.originalKey,
    song.currentKey,
    '${song.bpm}',
    song.timeSignature,
    '${song.capo}',
    song.instrument,
    '${song.duration}',
    song.spotifyUrl,
    song.tags.join(', '),
    song.comments,
  ];
  final form = GlobalKey<FormState>();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.metadata),
      content: SizedBox(
        width: 500,
        child: Form(
          key: form,
          child: ListView(
            shrinkWrap: true,
            children: List.generate(
              labels.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  initialValue: values[i],
                  onChanged: (v) => values[i] = v,
                  decoration: InputDecoration(labelText: labels[i]),
                  keyboardType: [6, 8, 10].contains(i)
                      ? TextInputType.number
                      : TextInputType.text,
                  maxLines: i == 13 ? 3 : 1,
                  validator: (v) {
                    if (i == 0 && (v ?? '').trim().isEmpty) {
                      return l.title;
                    }
                    if (i == 11 &&
                        (v ?? '').isNotEmpty &&
                        spotifyTrack(v!) == null) {
                      return l.invalidSpotify;
                    }
                    if ([4, 5].contains(i) &&
                        !RegExp(r'^[A-G](?:#|b)?m?$').hasMatch(v ?? '')) {
                      return l.key;
                    }
                    if ([6, 8, 10].contains(i)) {
                      final number = int.tryParse(v ?? '');
                      if (number == null ||
                          number < (i == 6 ? 20 : 0) ||
                          number >
                              (i == 8
                                  ? 12
                                  : i == 6
                                  ? 400
                                  : 86400)) {
                        return l.notAvailable;
                      }
                    }
                    return null;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(ctx, true);
            }
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
  if (accepted == true) {
    final v = values.map((text) => text.trim()).toList();
    before();
    song.title = v[0];
    song.artist = v[1];
    song.album = v[2];
    song.genre = v[3];
    song.originalKey = v[4];
    song.currentKey = v[5];
    song.bpm = int.parse(v[6]);
    song.timeSignature = v[7];
    song.capo = int.parse(v[8]);
    song.instrument = v[9];
    song.duration = int.parse(v[10]);
    song.spotifyUrl = v[11].isEmpty ? '' : spotifyTrack(v[11])!.toString();
    song.tags = v[12]
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    song.comments = v[13];
    changed();
  }
}
