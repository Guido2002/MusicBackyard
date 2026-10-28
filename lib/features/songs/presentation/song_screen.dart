import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/localization/context_l10n.dart';
import '../../../core/services/library_controller.dart';
import '../../../core/widgets/common.dart';
import '../../audio/audio_panel.dart';
import '../../chord_editor/capo_dialog.dart';
import '../../tablature/tab_editor.dart';
import '../../export/export_screen.dart';
import '../domain/song.dart';
import '../domain/music_theory.dart';
import '../domain/chordpro.dart';
import 'section_editor.dart';
import 'metadata_editor.dart';
import 'attachments_panel.dart';

class SongScreen extends StatefulWidget {
  const SongScreen({super.key, required this.library, required this.id});
  final LibraryController library;
  final String id;
  @override
  State<SongScreen> createState() => _SongScreenState();
}

class _SongScreenState extends State<SongScreen> with WidgetsBindingObserver {
  Song? song;
  int arrangementIndex = 0;
  int historyRevision = 0;
  SongArrangement get arrangement =>
      song!.arrangements[arrangementIndex.clamp(
        0,
        song!.arrangements.length - 1,
      )];
  final undo = <String>[], redo = <String>[];
  final collapsed = <String>{};
  String mode = 'both';
  double fontSize = 18;
  Timer? debounce;
  Future<void> queue = Future.value();
  bool dirty = false, failed = false, canLeave = false, recording = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    song = widget.library.song(widget.id)?.clone();
    if (song != null) {
      song!.openedAt = DateTime.now();
      dirty = true;
      debounce = Timer(const Duration(milliseconds: 100), flush);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(flush());
    }
  }

  void before() {
    if (song == null) {
      return;
    }
    undo.add(jsonEncode(song!.toJson()));
    if (undo.length > 60) {
      undo.removeAt(0);
    }
    redo.clear();
  }

  void changed() {
    setState(() {
      dirty = true;
      failed = false;
    });
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 450), flush);
  }

  Future<void> flush() async {
    debounce?.cancel();
    if (song == null || !dirty) {
      await queue;
      return;
    }
    final snapshot = song!.clone();
    final serialized = jsonEncode(snapshot.toJson());
    queue = queue.catchError((Object _) {}).then((_) async {
      try {
        await widget.library.saveSong(snapshot);
        if (mounted && jsonEncode(song!.toJson()) == serialized) {
          setState(() {
            dirty = false;
            failed = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => failed = true);
        }
      }
    });
    await queue;
  }

  Future<void> leave([VoidCallback? next]) async {
    if (recording) {
      message(context, context.l.stopRecordingFirst);
      return;
    }
    await flush();
    if (!mounted || failed) {
      return;
    }
    if (next != null) {
      next();
    } else {
      setState(() => canLeave = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.pop();
        }
      });
    }
  }

  void history(bool backwards) {
    final source = backwards ? undo : redo, target = backwards ? redo : undo;
    if (source.isEmpty) {
      return;
    }
    historyRevision++;
    target.add(jsonEncode(song!.toJson()));
    song = Song.fromJson(jsonDecode(source.removeLast()));
    arrangementIndex = arrangementIndex.clamp(0, song!.arrangements.length - 1);
    changed();
  }

  void transpose(int amount) {
    before();
    MusicTheory.transposeArrangement(
      arrangement,
      amount,
      preferFlats: song!.currentKey.contains('b'),
    );
    song!.currentKey = MusicTheory.transpose(song!.currentKey, amount);
    changed();
  }

  Future<void> sectionAction(String value, SongSection section) async {
    if (value == 'rename') {
      final name = await askText(
        context,
        context.l.sectionName,
        initial: section.name,
      );
      if (name != null && name.isNotEmpty) {
        before();
        section.name = name;
        changed();
      }
      return;
    }
    before();
    final i = arrangement.sections.indexOf(section);
    switch (value) {
      case 'duplicate':
        final copy = section.duplicate();
        arrangement.sections.insert(
          i + 1,
          SongSection(name: copy.name, lines: copy.lines),
        );
      case 'delete':
        arrangement.sections.remove(section);
      case 'up':
        if (i > 0) {
          arrangement.sections.removeAt(i);
          arrangement.sections.insert(i - 1, section);
        }
      case 'down':
        if (i < arrangement.sections.length - 1) {
          arrangement.sections.removeAt(i);
          arrangement.sections.insert(i + 1, section);
        }
    }
    changed();
  }

  Future<void> replaceText() async {
    final find = await askText(context, context.l.find);
    if (find == null || find.isEmpty || !mounted) {
      return;
    }
    final replace = await askText(context, context.l.replace);
    if (replace == null) {
      return;
    }
    before();
    for (final section in arrangement.sections) {
      for (final line in section.lines) {
        // Apply replacements one by one from right to left, preserving chord anchors.
        final matches = RegExp(RegExp.escape(find))
            .allMatches(line.text)
            .toList()
            .reversed;
        for (final m in matches) {
          MusicTheory.editLine(
            line,
            line.text.replaceRange(m.start, m.end, replace),
          );
        }
      }
    }
    changed();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.noSongs)),
      );
    }
    final s = song!;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(leave());
        }
      },
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  failed
                      ? l.saveError
                      : dirty
                      ? l.saving
                      : l.saved,
                  style: TextStyle(
                    fontSize: 11,
                    color: failed ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ],
            ),
            actions: [
              if (failed)
                IconButton(
                  tooltip: l.retry,
                  onPressed: flush,
                  icon: const Icon(Icons.sync_problem),
                ),
              IconButton(
                tooltip: l.undo,
                onPressed: undo.isEmpty ? null : () => history(true),
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: l.redo,
                onPressed: redo.isEmpty ? null : () => history(false),
                icon: const Icon(Icons.redo),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('song-actions'),
                onSelected: (value) async {
                  switch (value) {
                    case 'metadata':
                      await editMetadata(context, s, before, changed);
                    case 'pdf':
                      await leave(
                        () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ExportScreen(
                              songs: [s.clone(arrangementId: arrangement.id)],
                            ),
                          ),
                        ),
                      );
                    case 'chordpro':
                      await guard(context, () async {
                        await FilePicker.saveFile(
                          fileName:
                              '${s.title.replaceAll(RegExp(r'[^\w\s-]'), '')}.cho',
                          bytes: utf8.encode(
                            ChordPro.encode(s, arrangement: arrangement),
                          ),
                        );
                      });
                    case 'play':
                      await leave(
                        () => context.push(
                          '/play?song=${s.id}&arrangement=${arrangement.id}',
                        ),
                      );
                    case 'replace':
                      await replaceText();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'metadata', child: Text(l.metadata)),
                  PopupMenuItem(value: 'play', child: Text(l.performance)),
                  PopupMenuItem(value: 'pdf', child: Text(l.pdfExport)),
                  PopupMenuItem(value: 'chordpro', child: Text(l.chordpro)),
                  PopupMenuItem(value: 'replace', child: Text(l.findReplace)),
                ],
              ),
            ],
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.lyrics),
                Tab(text: l.tabs),
                Tab(text: l.notes),
                Tab(text: l.audio),
                Tab(text: l.attachments),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        label: Text('${l.key}: ${s.currentKey}'),
                        onPressed: () =>
                            editMetadata(context, s, before, changed),
                      ),
                      ActionChip(
                        label: Text(
                          '${l.capo}: ${s.capo} · ${MusicTheory.soundingKey(s.currentKey, s.capo)}',
                        ),
                        onPressed: () async {
                          final change = await showCapoDialog(
                            context,
                            s,
                            arrangement,
                          );
                          if (change != null && mounted) {
                            before();
                            MusicTheory.applyCapo(
                              s,
                              change.capo,
                              preservePitch: change.preservePitch,
                            );
                            changed();
                          }
                        },
                      ),
                      InputChip(
                        label: Text('${s.bpm} BPM'),
                        onPressed: () =>
                            editMetadata(context, s, before, changed),
                      ),
                      IconButton(
                        tooltip: l.semitoneDown,
                        onPressed: () => transpose(-1),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: l.semitoneUp,
                        onPressed: () => transpose(1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      if (s.spotifyUrl.isNotEmpty)
                        IconButton(
                          tooltip: l.openSpotify,
                          onPressed: () => guard(context, () async {
                            final uri = spotifyTrack(s.spotifyUrl);
                            if (uri == null ||
                                !await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                )) {
                              if (context.mounted) {
                                message(context, l.openFailed);
                              }
                            }
                          }),
                          icon: const Icon(Icons.headphones),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: arrangementIndex,
                          items: s.arrangements
                              .asMap()
                              .entries
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.key,
                                  child: Text(a.value.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => arrangementIndex = v ?? 0),
                        ),
                      ),
                      IconButton(
                        tooltip: l.newArrangement,
                        onPressed: () async {
                          final name = await askText(context, l.newArrangement);
                          if (name != null && name.isNotEmpty) {
                            before();
                            final copy = arrangement.duplicate();
                            s.arrangements.add(
                              SongArrangement(
                                name: name,
                                sections: copy.sections,
                                measures: copy.measures,
                                tuning: copy.tuning,
                              ),
                            );
                            arrangementIndex = s.arrangements.length - 1;
                            changed();
                          }
                        },
                        icon: const Icon(Icons.library_add_outlined),
                      ),
                      PopupMenuButton<String>(
                        tooltip: l.chordView,
                        initialValue: mode,
                        onSelected: (v) => setState(() => mode = v),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(value: 'both', child: Text(l.both)),
                          PopupMenuItem(
                            value: 'lyrics',
                            child: Text(l.lyricsOnly),
                          ),
                          PopupMenuItem(
                            value: 'chords',
                            child: Text(l.chordsOnly),
                          ),
                        ],
                        icon: const Icon(Icons.visibility_outlined),
                      ),
                      IconButton(
                        tooltip: l.fontSize,
                        onPressed: () => setState(
                          () => fontSize = fontSize >= 26 ? 16 : fontSize + 2,
                        ),
                        icon: const Icon(Icons.text_fields),
                      ),
                    ],
                  ),
                  ...arrangement.sections.map(
                    (section) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    section.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      letterSpacing: 1.7,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: collapsed.contains(section.id)
                                      ? l.expand
                                      : l.collapse,
                                  onPressed: () => setState(
                                    () => collapsed.contains(section.id)
                                        ? collapsed.remove(section.id)
                                        : collapsed.add(section.id),
                                  ),
                                  icon: Icon(
                                    collapsed.contains(section.id)
                                        ? Icons.expand_more
                                        : Icons.expand_less,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) => sectionAction(v, section),
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text(l.rename),
                                    ),
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text(l.duplicate),
                                    ),
                                    PopupMenuItem(
                                      value: 'up',
                                      child: Text(l.moveUp),
                                    ),
                                    PopupMenuItem(
                                      value: 'down',
                                      child: Text(l.moveDown),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(l.delete),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!collapsed.contains(section.id))
                              SectionEditor(
                                key: ValueKey(
                                  '${arrangement.id}-${section.id}',
                                ),
                                section: section,
                                onBeforeChange: before,
                                onChanged: changed,
                                fontSize: fontSize,
                                mode: mode,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await askText(
                        context,
                        l.sectionName,
                        initial: l.verse,
                      );
                      if (name != null && name.isNotEmpty) {
                        before();
                        arrangement.sections.add(SongSection(name: name));
                        changed();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l.addSection),
                  ),
                ],
              ),
              TabEditor(
                arrangement: arrangement,
                beforeChange: before,
                onChanged: changed,
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: TextFormField(
                  key: ValueKey('notes-${s.id}-$historyRevision'),
                  initialValue: s.notes,
                  maxLines: null,
                  minLines: 12,
                  decoration: InputDecoration(
                    labelText: l.notes,
                    hintText: l.comments,
                  ),
                  onChanged: (v) {
                    before();
                    s.notes = v;
                    changed();
                  },
                ),
              ),
              AudioPanel(
                key: ValueKey('audio-${s.id}'),
                song: s,
                onChanged: changed,
                onRecordingChanged: (value) => recording = value,
              ),
              AttachmentsPanel(song: s, onChanged: changed),
            ],
          ),
        ),
      ),
    );
  }
}
