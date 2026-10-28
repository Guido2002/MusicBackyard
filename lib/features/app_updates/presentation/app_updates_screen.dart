import 'package:flutter/material.dart';

import '../../../app/localization/context_l10n.dart';
import '../../../core/widgets/common.dart';
import '../domain/update_status.dart';
import '../domain/release_track.dart';
import 'app_updates_controller.dart';

class AppUpdatesScreen extends StatelessWidget {
  const AppUpdatesScreen({super.key, required this.controller});
  final AppUpdatesController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (ctx, _) {
      final c = controller, l = ctx.l;
      final text = switch (c.status) {
        UpdateStatus.unconfigured => l.updateUnconfigured,
        UpdateStatus.idle => l.notChecked,
        UpdateStatus.checking => l.checking,
        UpdateStatus.upToDate => l.upToDate,
        UpdateStatus.available => l.available,
        UpdateStatus.downloading => l.downloading,
        UpdateStatus.interrupted => l.interrupted,
        UpdateStatus.downloaded => l.downloaded,
        UpdateStatus.preparing => l.preparing,
        UpdateStatus.installStarted => l.installStarted,
        UpdateStatus.permissionRequired => l.installPermission,
        UpdateStatus.error => l.updateError,
      };
      return Scaffold(
        appBar: AppBar(title: Text(l.appUpdates)),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(l.appName, style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('${l.currentVersion}: ${c.version} (${c.build})'),
            Text(
              '${l.updateSource}: ${switch (c.channel) {
                'direct' => l.directDistribution,
                'play' => 'Google Play',
                'appstore' => 'App Store',
                _ => l.notAvailable,
              }}',
            ),
            const SizedBox(height: 24),
            if (c.canChooseTrack) ...[
              DropdownButtonFormField<ReleaseTrack>(
                key: ValueKey(c.track),
                initialValue: c.track,
                decoration: InputDecoration(labelText: l.updateTrack),
                items: [
                  DropdownMenuItem(
                    value: ReleaseTrack.stable,
                    child: Text(l.stableTrack),
                  ),
                  DropdownMenuItem(
                    value: ReleaseTrack.beta,
                    child: Text(l.betaTrack),
                  ),
                ],
                onChanged: c.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          guard(ctx, () => c.setTrack(value));
                        }
                      },
              ),
              const SizedBox(height: 8),
              Text(
                c.track == ReleaseTrack.stable
                    ? l.stableTrackHelp
                    : l.betaTrackHelp,
              ),
              if (c.track == ReleaseTrack.stable && c.version.contains('-'))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.stableNeedsNewerBuild),
                ),
              const SizedBox(height: 16),
            ],
            if (c.channel == 'direct')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.autoWifiUpdates),
                subtitle: Text(l.autoWifiUpdatesHelp),
                value: c.automaticWifiDownload,
                onChanged: c.initialized
                    ? (value) =>
                          guard(ctx, () => c.setAutomaticDownloads(value))
                    : null,
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      c.hasUpdate
                          ? Icons.system_update
                          : Icons.verified_outlined,
                      size: 36,
                    ),
                    const SizedBox(height: 16),
                    Text(text, style: Theme.of(ctx).textTheme.titleLarge),
                    if (c.update != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${c.update!.version} · ${(c.update!.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                      ),
                    ],
                    if (c.status == UpdateStatus.downloading) ...[
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: c.total == 0 ? null : c.received / c.total,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${c.total == 0 ? 0 : (c.received / c.total * 100).round()}% · ${(c.received / 1048576).toStringAsFixed(1)} / ${(c.total / 1048576).toStringAsFixed(1)} MB${c.bytesPerSecond == 0 ? '' : ' · ${(c.bytesPerSecond / 1048576).toStringAsFixed(1)} MB/s'}',
                      ),
                      TextButton(onPressed: c.cancel, child: Text(l.cancel)),
                    ],
                    if (c.channel == 'direct' &&
                        c.update != null &&
                        [
                          UpdateStatus.available,
                          UpdateStatus.interrupted,
                          UpdateStatus.error,
                        ].contains(c.status))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton(
                          onPressed: c.download,
                          child: Text(l.download),
                        ),
                      ),
                    if ([
                          UpdateStatus.downloaded,
                          UpdateStatus.permissionRequired,
                        ].contains(c.status) ||
                        c.channel == 'play' &&
                            c.status == UpdateStatus.available)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: FilledButton(
                          onPressed: c.install,
                          child: Text(l.install),
                        ),
                      ),
                    if (c.status == UpdateStatus.installStarted &&
                        c.channel == 'direct')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: TextButton(
                          onPressed: () => c.move(UpdateStatus.downloaded),
                          child: Text(l.retry),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (c.update != null)
              ExpansionTile(
                title: Text(l.releaseNotes),
                children: c.update!.releaseNotes
                    .map(
                      (n) => ListTile(
                        leading: const Icon(Icons.check, size: 18),
                        title: Text(n),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 20),
            Text(
              '${l.lastChecked}: ${c.lastChecked == null ? l.notChecked : MaterialLocalizations.of(ctx).formatMediumDate(c.lastChecked!.toLocal())}',
            ),
            const SizedBox(height: 20),
            if (c.channel != 'appstore')
              OutlinedButton.icon(
                onPressed: c.busy ? null : () => c.check(force: true),
                icon: const Icon(Icons.refresh),
                label: Text(l.checkUpdates),
              ),
            if (c.channel == 'appstore' && c.storeConfigured)
              FilledButton(
                onPressed: () => guard(ctx, c.openStore),
                child: Text(l.storeUpdate),
              ),
          ],
        ),
      );
    },
  );
}
