import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/services/library_controller.dart';
import '../../core/services/backup_service.dart';
import '../../core/widgets/common.dart';
import '../app_updates/presentation/app_updates_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, required this.library});
  final LibraryController library;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final updates = ref.watch(updatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.more)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l.preferences, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: library.themeMode,
                decoration: InputDecoration(labelText: l.theme),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(l.system),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(l.light),
                  ),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(l.dark)),
                ],
                onChanged: (v) => guard(
                  context,
                  () => library.setPreference('theme', v!.name),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.piano_outlined),
              title: Text(l.instrument),
              subtitle: Text(library.preferences['instrument'] ?? l.multiple),
              onTap: () async {
                final value = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text(l.instrument),
                    children:
                        [
                              l.guitar,
                              l.piano,
                              l.voice,
                              l.bass,
                              l.other,
                              l.multiple,
                            ]
                            .map(
                              (v) => SimpleDialogOption(
                                onPressed: () => Navigator.pop(ctx, v),
                                child: Text(v),
                              ),
                            )
                            .toList(),
                  ),
                );
                if (value != null && context.mounted) {
                  await guard(
                    context,
                    () => library.setPreference('instrument', value),
                  );
                }
              },
            ),
          ),
          Card(
            child: ExpansionTile(
              leading: const Icon(Icons.person_outline),
              title: Text(l.profile),
              children: [
                ListenableBuilder(
                  listenable: updates,
                  builder: (ctx, _) => ListTile(
                    leading: Badge(
                      isLabelVisible: updates.hasUpdate,
                      child: const Icon(Icons.system_update_outlined),
                    ),
                    title: Text(l.appUpdates),
                    onTap: () => ctx.push('/updates'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(l.backup, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.backupContents),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () =>
                guard(context, () => BackupService(library).export()),
            icon: const Icon(Icons.save_alt),
            label: Text(l.backup),
          ),
          TextButton.icon(
            onPressed: () async {
              final source = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: ['mbbackup'],
              );
              if (source == null || !context.mounted) {
                return;
              }
              if (!await confirm(context, l.confirmRestore, l.backupWarning) ||
                  !context.mounted) {
                return;
              }
              try {
                await BackupService(library).restore(source);
                if (context.mounted) {
                  message(context, l.restoreDone);
                }
              } catch (_) {
                if (context.mounted) {
                  message(context, l.backupInvalid);
                }
              }
            },
            icon: const Icon(Icons.restore),
            label: Text(l.restoreBackup),
          ),
          const SizedBox(height: 24),
          Text(l.performance, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.scrollHelp),
          for (final key in ['pedalPrevious', 'pedalNext'])
            Card(
              child: ListTile(
                title: Text(key == 'pedalNext' ? l.next : l.previous),
                subtitle: Text(
                  library.preferences[key] ??
                      (key == 'pedalNext' ? 'Page Down' : 'Page Up'),
                ),
                onTap: () async {
                  final value = await askText(
                    context,
                    l.name,
                    initial:
                        library.preferences[key] ??
                        (key == 'pedalNext' ? 'Page Down' : 'Page Up'),
                  );
                  if (value != null && value.isNotEmpty && context.mounted) {
                    await guard(
                      context,
                      () => library.setPreference(key, value),
                    );
                  }
                },
              ),
            ),
          const SizedBox(height: 24),
          Text(l.about, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.aboutBody),
          const SizedBox(height: 32),
          Text(l.tagline, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
