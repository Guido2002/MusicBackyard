import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

import '../../app/localization/context_l10n.dart';
import '../../core/services/attachment_service.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';

class AudioPanel extends StatefulWidget {
  const AudioPanel({
    super.key,
    required this.song,
    required this.onChanged,
    required this.onRecordingChanged,
  });
  final Song song;
  final VoidCallback onChanged;
  final ValueChanged<bool> onRecordingChanged;
  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && recording) {
      toggleRecord();
    }
  }

  final recorder = AudioRecorder(), player = AudioPlayer();
  bool recording = false, busy = false;
  String? playingId, recordingPath;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    recorder.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> toggleRecord() async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      if (recording) {
        final path = await recorder.stop();
        if (path != null) {
          widget.song.attachments.add(
            Attachment(
              name:
                  'Demo ${widget.song.attachments.where((a) => a.kind == 'audio').length + 1}',
              path: path,
              kind: 'audio',
            ),
          );
          widget.onChanged();
        }
        if (mounted) {
          setState(() => recording = false);
          widget.onRecordingChanged(false);
        }
      } else {
        if (!await recorder.hasPermission()) {
          if (mounted) {
            message(context, context.l.microphoneDenied);
          }
          return;
        }
        final dir = await AttachmentService.directory();
        recordingPath = p.join(dir.path, '${newId()}.m4a');
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: recordingPath!,
        );
        if (mounted) {
          setState(() => recording = true);
          widget.onRecordingChanged(true);
        }
      }
    } catch (_) {
      if (mounted) {
        message(context, context.l.error);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final files = widget.song.attachments
        .where((a) => a.kind == 'audio')
        .toList();
    return PopScope(
      canPop: !recording,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton.icon(
            onPressed: busy ? null : toggleRecord,
            icon: Icon(recording ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(recording ? context.l.recordStop : context.l.record),
          ),
          const SizedBox(height: 20),
          if (files.isEmpty) Text(context.l.noAudio),
          ...files.map(
            (audio) => Card(
              child: ListTile(
                title: Text(audio.name),
                leading: StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snapshot) {
                    final active =
                        playingId == audio.id &&
                        snapshot.data?.playing == true &&
                        snapshot.data?.processingState !=
                            ProcessingState.completed;
                    return IconButton(
                      tooltip: active ? context.l.pause : context.l.play,
                      icon: Icon(active ? Icons.pause : Icons.play_arrow),
                      onPressed: () => guard(context, () async {
                        if (active) {
                          await player.pause();
                        } else {
                          if (!await File(audio.path).exists()) {
                            if (context.mounted) {
                              message(context, context.l.attachmentMissing);
                            }
                            return;
                          }
                          if (playingId != audio.id) {
                            await player.setFilePath(audio.path);
                            playingId = audio.id;
                          }
                          if (player.processingState ==
                              ProcessingState.completed) {
                            await player.seek(Duration.zero);
                          }
                          player.play().catchError((Object e) {
                            if (context.mounted) {
                              message(context, context.l.openFailed);
                            }
                          });
                        }
                      }),
                    );
                  },
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'rename') {
                      final name = await askText(
                        context,
                        context.l.audioName,
                        initial: audio.name,
                      );
                      if (name != null && name.isNotEmpty) {
                        audio.name = name;
                        widget.onChanged();
                      }
                    } else if (await confirm(
                      context,
                      context.l.confirmDelete,
                      context.l.confirmDeleteBody,
                    )) {
                      await player.stop();
                      widget.song.attachments.remove(audio);
                      widget.onChanged(); /* Keep physical files until backup/garbage collection so undo cannot lose audio. */
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'rename', child: Text(ctx.l.rename)),
                    PopupMenuItem(value: 'delete', child: Text(ctx.l.delete)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
