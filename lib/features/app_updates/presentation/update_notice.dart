import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/context_l10n.dart';
import '../domain/update_status.dart';
import 'app_updates_controller.dart';

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key, required this.controller});
  final AppUpdatesController controller;
  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  String? dismissed;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (ctx, _) {
      final c = widget.controller,
          key = '${c.track.name}:${c.update?.buildNumber}:${c.status.name}';
      if (!c.hasUpdate ||
          ![
            UpdateStatus.available,
            UpdateStatus.downloaded,
          ].contains(c.status) ||
          dismissed == key) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        bottom: false,
        child: Material(
          color: Theme.of(ctx).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.system_update, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.status == UpdateStatus.downloaded
                        ? ctx.l.updateReadyToInstall
                        : ctx.l.updateReady,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => ctx.push('/updates'),
                  child: Text(ctx.l.viewUpdate),
                ),
                IconButton(
                  tooltip: ctx.l.close,
                  onPressed: () => setState(() => dismissed = key),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
