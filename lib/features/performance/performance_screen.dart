import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/localization/context_l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/library_controller.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import '../songs/domain/music_theory.dart';
import '../chord_editor/chord_line.dart';

class PerformancePicker extends StatelessWidget {
  const PerformancePicker({super.key, required this.library});
  final LibraryController library;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (ctx, _) => Scaffold(
      appBar: AppBar(title: Text(ctx.l.performance)),
      body: library.songs.where((s) => !s.deleted).isEmpty
          ? EmptyState(
              icon: Icons.play_circle_outline,
              title: ctx.l.performance,
              body: ctx.l.noSongs,
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  ctx.l.rehearsal,
                  style: Theme.of(ctx).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                ...library.setlists.map(
                  (s) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.queue_music),
                      title: Text(s.name),
                      onTap: () => ctx.push('/play?setlist=${s.id}'),
                    ),
                  ),
                ),
                ...library.songs
                    .where((s) => !s.deleted)
                    .map(
                      (s) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(s.title),
                          subtitle: Text(s.artist),
                          onTap: () => ctx.push('/play?song=${s.id}'),
                        ),
                      ),
                    ),
              ],
            ),
    ),
  );
}

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({
    super.key,
    required this.library,
    this.songId,
    this.arrangementId,
    this.setlistId,
  });
  final LibraryController library;
  final String? songId, setlistId, arrangementId;
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with WidgetsBindingObserver {
  final scroll = ScrollController(), focus = FocusNode();
  Timer? timer, persistTimer;
  int index = 0;
  double fontSize = 24, speed = 24;
  bool running = false, chords = true;
  late List<SetlistEntry> entries;
  late String session;
  String get positionKey =>
      'scroll:$session:${entries.isEmpty ? 'empty' : entries[index].id}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    entries = widget.setlistId == null
        ? [
            SetlistEntry(
              id: widget.songId,
              songId: widget.songId,
              arrangementId: widget.arrangementId,
            ),
          ]
        : widget.library.setlists
                  .where((s) => s.id == widget.setlistId)
                  .firstOrNull
                  ?.entries ??
              [];
    final originalArrangement = widget.library
        .song(widget.songId ?? '')
        ?.arrangements
        .firstOrNull
        ?.id;
    final defaultArrangement =
        widget.arrangementId == null ||
        widget.arrangementId == originalArrangement;
    session =
        widget.setlistId ??
        (defaultArrangement
            ? widget.songId ?? 'empty'
            : '${widget.songId}:${widget.arrangementId}');
    index = (widget.library.preferences['playIndex:$session'] as int? ?? 0)
        .clamp(0, entries.isEmpty ? 0 : entries.length - 1);
    fontSize = (widget.library.preferences['playFont'] as num? ?? 24)
        .toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restorePosition();
      focus.requestFocus();
    });
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
    scroll.addListener(schedulePosition);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      stopScroll();
      unawaited(savePosition());
    }
  }

  void schedulePosition() {
    persistTimer?.cancel();
    persistTimer = Timer(const Duration(milliseconds: 600), savePosition);
  }

  Future<void> savePosition() async {
    if (!scroll.hasClients || entries.isEmpty) {
      return;
    }
    try {
      await widget.library.setPreference(positionKey, scroll.offset);
      await widget.library.setPreference('playIndex:$session', index);
    } catch (_) {
      /* Position is optional; song data is unaffected. */
    }
  }

  void restorePosition() {
    if (scroll.hasClients) {
      scroll.jumpTo(
        (widget.library.preferences[positionKey] as num? ?? 0).toDouble().clamp(
          0,
          scroll.position.maxScrollExtent,
        ),
      );
    }
  }

  void stopScroll() {
    timer?.cancel();
    if (mounted && running) {
      setState(() => running = false);
    }
  }

  void toggleScroll() {
    if (running) {
      stopScroll();
      return;
    }
    setState(() => running = true);
    var previous = DateTime.now();
    timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final now = DateTime.now();
      final elapsed = now.difference(previous).inMicroseconds / 1000000;
      previous = now;
      if (!scroll.hasClients) {
        return;
      }
      final next = (scroll.offset + elapsed * speed).clamp(
        0,
        scroll.position.maxScrollExtent,
      );
      scroll.jumpTo(next.toDouble());
      if (next >= scroll.position.maxScrollExtent) {
        stopScroll();
      }
    });
  }

  Future<void> navigate(int delta) async {
    if (index + delta < 0 || index + delta >= entries.length) {
      return;
    }
    stopScroll();
    await savePosition();
    if (!mounted) {
      return;
    }
    setState(() => index += delta);
    await widget.library.setPreference('playIndex:$session', index);
    WidgetsBinding.instance.addPostFrameCallback((_) => restorePosition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    persistTimer?.cancel();
    scroll.removeListener(schedulePosition);
    scroll.dispose();
    focus.dispose();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final entry = entries.isEmpty ? null : entries[index];
    final original = entry?.songId == null
        ? null
        : widget.library.song(entry!.songId!);
    final song = original?.clone();
    SongArrangement? arrangement;
    if (song != null) {
      arrangement =
          song.arrangements
              .where((a) => a.id == entry?.arrangementId)
              .firstOrNull ??
          song.arrangements.first;
      MusicTheory.transposeArrangement(arrangement, entry!.transpose);
    }
    final nextKey =
        widget.library.preferences['pedalNext'] as String? ?? 'Page Down';
    final previousKey =
        widget.library.preferences['pedalPrevious'] as String? ?? 'Page Up';
    return Theme(
      data: AppTheme.build(Brightness.dark),
      child: KeyboardListener(
        focusNode: focus,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) {
            return;
          }
          if (event.logicalKey.keyLabel == nextKey) {
            navigate(1);
          } else if (event.logicalKey.keyLabel == previousKey) {
            navigate(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            toggleScroll();
          } else if (scroll.hasClients &&
              [
                LogicalKeyboardKey.arrowDown,
                LogicalKeyboardKey.arrowUp,
              ].contains(event.logicalKey)) {
            scroll.animateTo(
              (scroll.offset +
                      (event.logicalKey == LogicalKeyboardKey.arrowDown
                          ? 180
                          : -180))
                  .clamp(0, scroll.position.maxScrollExtent),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              stopScroll();
              await savePosition();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: l.exitPerformance,
                onPressed: () async {
                  stopScroll();
                  await savePosition();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.close),
              ),
              title: Text(song?.title ?? l.breakLabel),
              actions: [
                IconButton(
                  tooltip: l.showChords,
                  onPressed: () => setState(() => chords = !chords),
                  icon: Icon(chords ? Icons.music_note : Icons.music_off),
                ),
                IconButton(
                  tooltip: l.fontSize,
                  onPressed: () {
                    setState(
                      () => fontSize = fontSize >= 36 ? 18 : fontSize + 3,
                    );
                    guard(
                      context,
                      () => widget.library.setPreference('playFont', fontSize),
                    );
                  },
                  icon: const Icon(Icons.text_fields),
                ),
                IconButton(
                  tooltip: l.reset,
                  onPressed: () {
                    stopScroll();
                    if (scroll.hasClients) {
                      scroll.jumpTo(0);
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
            body: entries.isEmpty
                ? Center(child: Text(l.noSongs))
                : song == null
                ? EmptyState(
                    icon: Icons.coffee_outlined,
                    title: entry!.songId == null
                        ? l.breakLabel
                        : l.attachmentMissing,
                    body:
                        '${entry.breakSeconds ~/ 60} ${l.minutes}\n${entry.note}',
                  )
                : ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 100),
                    children: [
                      Text(
                        song.artist,
                        style: const TextStyle(color: AppTheme.sage),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${MusicTheory.transpose(song.currentKey, entry!.transpose)} · ${song.bpm} BPM · ${l.capo} ${entry.capo ?? song.capo}',
                        style: const TextStyle(color: AppTheme.amber),
                      ),
                      if (entry.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(entry.note),
                        ),
                      ...arrangement!.sections.map(
                        (section) => Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.name.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.amber,
                                  letterSpacing: 2,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...section.lines.map(
                                (line) => ChordLine(
                                  line: line,
                                  fontSize: fontSize,
                                  mode: chords ? 'both' : 'lyrics',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l.previous,
                          onPressed: index > 0 ? () => navigate(-1) : null,
                          icon: const Icon(Icons.skip_previous),
                        ),
                        Text(
                          entries.isEmpty
                              ? '0 / 0'
                              : '${index + 1} / ${entries.length}',
                        ),
                        IconButton(
                          tooltip: l.next,
                          onPressed: index < entries.length - 1
                              ? () => navigate(1)
                              : null,
                          icon: const Icon(Icons.skip_next),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: toggleScroll,
                          icon: Icon(running ? Icons.pause : Icons.play_arrow),
                          label: Text(running ? l.pause : l.autoscroll),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(l.speed),
                        Expanded(
                          child: Slider(
                            value: speed,
                            min: 5,
                            max: 100,
                            onChanged: (v) => setState(() => speed = v),
                          ),
                        ),
                        Text('${speed.round()} px/s'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
