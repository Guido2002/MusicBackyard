import 'package:flutter/material.dart';

import '../../app/localization/context_l10n.dart';
import '../../core/services/library_controller.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import 'domain/folder_tree.dart';

class FolderManagerScreen extends StatelessWidget {
  const FolderManagerScreen({
    super.key,
    required this.library,
    this.initialParent,
  });
  final LibraryController library;
  final String? initialParent;

  Future<void> create(BuildContext context) => guard(context, () async {
    final name = await askText(context, context.l.newFolder);
    if (name != null && name.isNotEmpty) {
      await library.saveFolder(
        Folder(
          name: name,
          parentId: library.folders.any((f) => f.id == initialParent)
              ? initialParent
              : null,
        ),
      );
    }
  });

  Future<void> act(BuildContext context, Folder folder, String action) =>
      guard(context, () async {
        switch (action) {
          case 'rename':
            final name = await askText(
              context,
              context.l.rename,
              initial: folder.name,
            );
            if (name != null && name.isNotEmpty) {
              await library.saveFolder(
                Folder(id: folder.id, name: name, parentId: folder.parentId),
              );
            }
          case 'move':
            final tree = FolderTree(library.folders),
                excluded = {
                  folder.id,
                  ...FolderTree(library.folders).descendants(folder.id),
                };
            final destinations =
                library.folders.where((f) => !excluded.contains(f.id)).toList()
                  ..sort((a, b) => tree.path(a.id).compareTo(tree.path(b.id)));
            final parent = await showDialog<String>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(ctx.l.folderParent),
                children: [
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, ''),
                    child: Text(ctx.l.rootFolder),
                  ),
                  ...destinations.map(
                    (f) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, f.id),
                      child: Text(tree.path(f.id)),
                    ),
                  ),
                ],
              ),
            );
            if (parent != null) {
              await library.saveFolder(
                Folder(
                  id: folder.id,
                  name: folder.name,
                  parentId: parent.isEmpty ? null : parent,
                ),
              );
            }
          case 'delete':
            if (await confirm(
              context,
              context.l.deleteFolder,
              context.l.deleteFolderBody,
            )) {
              await library.removeFolder(folder.id);
            }
        }
      });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (ctx, _) {
      final tree = FolderTree(library.folders);
      final folders = [...library.folders]
        ..sort((a, b) => tree.path(a.id).compareTo(tree.path(b.id)));
      return Scaffold(
        appBar: AppBar(
          title: Text(ctx.l.manageFolders),
          actions: [
            IconButton(
              tooltip: ctx.l.newFolder,
              onPressed: () => create(ctx),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          ],
        ),
        body: folders.isEmpty
            ? EmptyState(
                icon: Icons.folder_outlined,
                title: ctx.l.folders,
                body: ctx.l.emptyFolders,
                action: FilledButton.icon(
                  onPressed: () => create(ctx),
                  icon: const Icon(Icons.add),
                  label: Text(ctx.l.newFolder),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: folders.length,
                itemBuilder: (ctx, index) {
                  final folder = folders[index];
                  final count = library.songs
                      .where((s) => s.folderId == folder.id && !s.deleted)
                      .length;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(folder.name),
                      subtitle: Text(
                        '${tree.path(folder.id)}\n$count ${ctx.l.songCount}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        tooltip: ctx.l.folderActions,
                        onSelected: (value) => act(ctx, folder, value),
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(ctx.l.rename),
                          ),
                          PopupMenuItem(value: 'move', child: Text(ctx.l.move)),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(ctx.l.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}
