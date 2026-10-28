import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/services/library_controller.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import '../songs/domain/music_theory.dart';
import '../export/export_screen.dart';

class SetlistsScreen extends StatelessWidget {
  const SetlistsScreen({super.key, required this.library});
  final LibraryController library;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (ctx, _) => Scaffold(
      appBar: AppBar(title: Text(ctx.l.setlists)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "setlist-add",
        onPressed: () => guard(ctx, () async {
          final name = await askText(ctx, ctx.l.newSetlist);
          if (name != null && name.isNotEmpty) {
            final setlist = MusicSetlist(name: name);
            await library.saveSetlist(setlist);
            if (ctx.mounted) {
              ctx.push('/setlist/${setlist.id}');
            }
          }
        }),
        icon: const Icon(Icons.add),
        label: Text(ctx.l.newSetlist),
      ),
      body: library.setlists.isEmpty
          ? EmptyState(
              icon: Icons.queue_music_rounded,
              title: ctx.l.emptySetlists,
              body: ctx.l.emptySetlistsBody,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: library.setlists.length,
              itemBuilder: (ctx, i) {
                final setlist = library.setlists[i];
                final seconds = setlist.entries.fold<int>(
                  0,
                  (sum, e) =>
                      sum +
                      (e.songId == null
                          ? e.breakSeconds
                          : library.song(e.songId!)?.duration ?? 0),
                );
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(setlist.name),
                    subtitle: Text(
                      '${setlist.entries.length} · ${(seconds / 60).ceil()} ${ctx.l.minutes}',
                    ),
                    onTap: () => ctx.push('/setlist/${setlist.id}'),
                  ),
                );
              },
            ),
    ),
  );
}

class SetlistScreen extends StatefulWidget {
  const SetlistScreen({super.key, required this.library, required this.id});
  final LibraryController library;
  final String id;
  @override
  State<SetlistScreen> createState() => _SetlistScreenState();
}

class _SetlistScreenState extends State<SetlistScreen> {
  MusicSetlist? get setlist =>
      widget.library.setlists.where((s) => s.id == widget.id).firstOrNull;
  Future<void> persist() => guard(context, () async {
    await widget.library.saveSetlist(setlist!);
    if (mounted) {
      setState(() {});
    }
  });
  Future<void> addSong() async {
    final song = await showDialog<Song>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.l.addSong),
        children: widget.library.songs
            .where((s) => !s.deleted && !s.archived)
            .map(
              (s) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, s),
                child: Text('${s.title} · ${s.artist}'),
              ),
            )
            .toList(),
      ),
    );
    if (song != null) {
      setlist!.entries.add(SetlistEntry(songId: song.id));
      await persist();
    }
  }

  List<Song> exportSongs() {
    final songs = <Song>[];
    for (final entry in setlist!.entries) {
      final original = entry.songId == null
          ? null
          : widget.library.song(entry.songId!);
      if (original == null) {
        continue;
      }
      final song = original.clone();
      final selected = song.arrangements
          .where((a) => a.id == entry.arrangementId)
          .firstOrNull;
      if (selected != null) {
        song.arrangements = [selected];
      }
      MusicTheory.transposeArrangement(
        song.arrangements.first,
        entry.transpose,
      );
      song.currentKey = MusicTheory.transpose(song.currentKey, entry.transpose);
      song.capo = entry.capo ?? song.capo;
      if (entry.note.isNotEmpty) {
        song.notes = '${entry.note}\n${song.notes}';
      }
      songs.add(song);
    }
    return songs;
  }

  Future<void> editEntry(SetlistEntry entry, Song? song) async {
    var note = entry.note, capo = '${entry.capo ?? song?.capo ?? 0}';
    int transpose = entry.transpose;
    String? arrangement = entry.arrangementId ?? song?.arrangements.first.id;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(song?.title ?? ctx.l.breakLabel),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: note,
                  onChanged: (v) => note = v,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: ctx.l.notes),
                ),
                if (song != null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: arrangement,
                    decoration: InputDecoration(labelText: ctx.l.arrangement),
                    items: song.arrangements
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => arrangement = v,
                  ),
                  Row(
                    children: [
                      Text(ctx.l.transpose),
                      IconButton(
                        tooltip: ctx.l.semitoneDown,
                        onPressed: () => set(() => transpose--),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$transpose'),
                      IconButton(
                        tooltip: ctx.l.semitoneUp,
                        onPressed: () => set(() => transpose++),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  TextFormField(
                    initialValue: capo,
                    onChanged: (v) => capo = v,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: ctx.l.capo),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l.save),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      final value = int.tryParse(capo);
      entry.note = note;
      entry.transpose = transpose;
      entry.arrangementId = arrangement;
      if (value != null && value >= 0 && value <= 12) {
        entry.capo = value;
      }
      await persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = setlist, l = context.l;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.noSongs)),
      );
    }
    final duration = s.entries.fold<int>(
      0,
      (sum, e) =>
          sum +
          (e.songId == null
              ? e.breakSeconds
              : widget.library.song(e.songId!)?.duration ?? 0),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(s.name),
        actions: [
          IconButton(
            tooltip: l.performance,
            onPressed: s.entries.isEmpty
                ? null
                : () => context.push('/play?setlist=${s.id}'),
            icon: const Icon(Icons.play_circle_outline),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => guard(context, () async {
              switch (value) {
                case 'rename':
                  final name = await askText(
                    context,
                    l.rename,
                    initial: s.name,
                  );
                  if (name != null && name.isNotEmpty) {
                    s.name = name;
                    await persist();
                  }
                case 'copy':
                  final copy = MusicSetlist(
                    name: '${s.name} (${l.copy.toLowerCase()})',
                    notes: s.notes,
                    entries: s.entries
                        .map((e) => SetlistEntry.fromJson(e.toJson()))
                        .toList(),
                  );
                  await widget.library.saveSetlist(copy);
                  if (context.mounted) {
                    context.push('/setlist/${copy.id}');
                  }
                case 'notes':
                  final note = await askText(
                    context,
                    l.setlistNotes,
                    initial: s.notes,
                    multiline: true,
                  );
                  if (note != null) {
                    s.notes = note;
                    await persist();
                  }
                case 'pdf':
                  final songs = exportSongs();
                  if (songs.isEmpty) {
                    message(context, l.noSongs);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ExportScreen(songs: songs),
                      ),
                    );
                  }
                case 'delete':
                  if (await confirm(
                    context,
                    l.confirmDelete,
                    l.confirmDeleteBody,
                  )) {
                    await widget.library.removeSetlist(s.id);
                    if (context.mounted) {
                      context.pop();
                    }
                  }
              }
            }),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'rename', child: Text(l.rename)),
              PopupMenuItem(value: 'copy', child: Text(l.duplicate)),
              PopupMenuItem(value: 'notes', child: Text(l.notes)),
              PopupMenuItem(value: 'pdf', child: Text(l.pdfExport)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '${s.entries.length} · ${(duration / 60).ceil()} ${l.minutes}',
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: addSong,
                  icon: const Icon(Icons.add),
                  label: Text(l.addSong),
                ),
              ],
            ),
          ),
          if (s.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(s.notes),
            ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: s.entries.length,
              onReorderItem: (from, to) {
                final entry = s.entries.removeAt(from);
                s.entries.insert(to, entry);
                persist();
              },
              itemBuilder: (ctx, i) {
                final entry = s.entries[i], song = entrySong(s.entries[i]);
                return Card(
                  key: ValueKey(entry.id),
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(
                      song?.title ??
                          (entry.songId == null
                              ? l.breakLabel
                              : l.attachmentMissing),
                    ),
                    subtitle: Text(
                      entry.songId == null
                          ? '${entry.breakSeconds ~/ 60} ${l.minutes}'
                          : song == null
                          ? ''
                          : "${song.artist} · ${MusicTheory.transpose(song.currentKey, entry.transpose)} · ${l.capo} ${entry.capo ?? song.capo} · ${song.duration ~/ 60}:${(song.duration % 60).toString().padLeft(2, '0')}${entry.note.isEmpty ? '' : '\n${entry.note}'}",
                    ),
                    onTap: () => editEntry(entry, song),
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'delete') {
                            s.entries.removeAt(i);
                          } else if (v == 'up' && i > 0) {
                            s.entries.removeAt(i);
                            s.entries.insert(i - 1, entry);
                          } else if (v == 'down' && i < s.entries.length - 1) {
                            s.entries.removeAt(i);
                            s.entries.insert(i + 1, entry);
                          }
                          persist();
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'up', child: Text(l.moveUp)),
                          PopupMenuItem(value: 'down', child: Text(l.moveDown)),
                          PopupMenuItem(value: 'delete', child: Text(l.delete)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton.icon(
              onPressed: () async {
                final minutes = await askText(
                  context,
                  l.minutes,
                  initial: '10',
                );
                final value = int.tryParse(minutes ?? '');
                if (value != null && value > 0 && value < 1440) {
                  s.entries.add(SetlistEntry(breakSeconds: value * 60));
                  await persist();
                }
              },
              icon: const Icon(Icons.coffee_outlined),
              label: Text(l.addBreak),
            ),
          ),
        ],
      ),
    );
  }

  Song? entrySong(SetlistEntry entry) =>
      entry.songId == null ? null : widget.library.song(entry.songId!);
}
