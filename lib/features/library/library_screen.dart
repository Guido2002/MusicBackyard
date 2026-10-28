import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/context_l10n.dart';
import '../../app/theme/app_theme.dart';
import '../../core/services/library_controller.dart';
import '../../core/widgets/common.dart';
import '../songs/domain/song.dart';
import 'folder_manager_screen.dart';
import 'domain/folder_tree.dart';
import '../import/import_service.dart';
import '../export/export_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.library, this.studio = false});
  final LibraryController library;
  final bool studio;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String query = '',
      view = 'all',
      sort = 'updated',
      instrument = '',
      keyFilter = '',
      tagFilter = '';
  String? folder;
  final selected = <String>{};
  Future<void> createSong() async {
    final title = await askText(context, context.l.newSong);
    if (title == null || title.isEmpty || !mounted) {
      return;
    }
    await guard(context, () async {
      final song = Song(
        title: title,
        folderId: folder,
        instrument:
            widget.library.preferences['instrument'] ?? context.l.guitar,
      );
      await widget.library.saveSong(song);
      if (mounted) {
        context.push('/song/${song.id}');
      }
    });
  }

  Future<void> action(String value, Song song) async {
    final c = widget.library;
    await guard(context, () async {
      final copy = song.clone();
      switch (value) {
        case 'copy':
          await c.saveSong(song.clone(newIdentity: true));
        case 'archive':
          copy.archived = !copy.archived;
          await c.saveSong(copy);
        case 'delete':
          copy.deleted = true;
          await c.saveSong(copy);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l.deleted),
                action: SnackBarAction(
                  label: context.l.restore,
                  onPressed: () => guard(context, () async {
                    copy.deleted = false;
                    await c.saveSong(copy);
                  }),
                ),
              ),
            );
          }
        case 'restore':
          copy.deleted = false;
          await c.saveSong(copy);
        case 'destroy':
          if (await confirm(
            context,
            context.l.confirmDelete,
            context.l.confirmDeleteBody,
          )) {
            await c.deleteForever(song.id);
          }
        case 'move':
          final choice = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: Text(ctx.l.move),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: Text(ctx.l.rootFolder),
                ),
                ...c.folders.map(
                  (f) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, f.id),
                    child: Text(f.name),
                  ),
                ),
              ],
            ),
          );
          if (choice != null) {
            copy.folderId = choice.isEmpty ? null : choice;
            await c.saveSong(copy);
          }
        case 'select':
          setState(() => selected.add(song.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.library,
    builder: (context, _) {
      final l = context.l, c = widget.library;
      final currentFolder = c.folders.where((f) => f.id == folder).firstOrNull;
      if (folder != null && currentFolder == null) {
        folder = null;
      }
      final songs = c.songs
          .where(
            (s) => view == 'trash'
                ? s.deleted
                : !s.deleted &&
                      (view == 'archived' ? s.archived : !s.archived) &&
                      (view != 'favorites' || s.favorite) &&
                      (folder == null || s.folderId == folder),
          )
          .where(
            (s) =>
                s.searchable.contains(query.toLowerCase()) &&
                (instrument.isEmpty || s.instrument == instrument) &&
                (keyFilter.isEmpty || s.currentKey == keyFilter) &&
                (tagFilter.isEmpty || s.tags.contains(tagFilter)),
          )
          .toList();
      songs.sort(
        (a, b) => sort == 'title'
            ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
            : sort == 'opened'
            ? (b.openedAt ?? DateTime(1970)).compareTo(
                a.openedAt ?? DateTime(1970),
              )
            : b.updatedAt.compareTo(a.updatedAt),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.studio ? l.studio : l.appName),
          actions: [
            IconButton(
              tooltip: l.importFile,
              onPressed: () => guard(context, () async {
                final song = await ImportService(c).importSong(context);
                if (song != null && context.mounted) {
                  context.push('/song/${song.id}');
                }
              }),
              icon: const Icon(Icons.file_open_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: l.sort,
              onSelected: (v) => setState(() => sort = v),
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'title', child: Text(l.sortTitle)),
                PopupMenuItem(value: 'updated', child: Text(l.sortUpdated)),
                PopupMenuItem(value: 'opened', child: Text(l.sortOpened)),
              ],
              icon: const Icon(Icons.sort_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: widget.studio ? "studio-add" : "library-add",
          onPressed: createSong,
          icon: const Icon(Icons.add),
          label: Text(l.newSong),
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.forest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.tagline,
                            style: const TextStyle(
                              color: AppTheme.sage,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.studio ? l.firstSong : l.libraryHeading,
                            style: const TextStyle(
                              color: AppTheme.cream,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l.librarySubheading,
                            style: const TextStyle(color: AppTheme.sage),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Icon(
                                Icons.offline_pin_outlined,
                                size: 16,
                                color: AppTheme.amber,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l.offline,
                                  style: const TextStyle(
                                    color: AppTheme.sage,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        hintText: l.search,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final item in [
                            ('all', l.allSongs),
                            ('favorites', l.favorites),
                            ('archived', l.archived),
                            ('trash', l.trash),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(item.$2),
                                selected: view == item.$1,
                                onSelected: (_) => setState(() {
                                  view = item.$1;
                                  folder = null;
                                }),
                              ),
                            ),
                          IconButton(
                            tooltip: l.filter,
                            onPressed: () => showFilters(context),
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (folder != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => folder = currentFolder?.parentId),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(
                          currentFolder == null
                              ? l.folders
                              : FolderTree(c.folders).path(currentFolder.id),
                        ),
                      ),
                    if (view == 'all') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            l.folders,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: l.manageFolders,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => FolderManagerScreen(
                                  library: c,
                                  initialParent: folder,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.folder_copy_outlined),
                          ),
                          TextButton.icon(
                            onPressed: () => guard(context, () async {
                              final name = await askText(context, l.newFolder);
                              if (name != null && name.isNotEmpty) {
                                await c.saveFolder(
                                  Folder(name: name, parentId: folder),
                                );
                              }
                            }),
                            icon: const Icon(
                              Icons.create_new_folder_outlined,
                              size: 18,
                            ),
                            label: Text(l.newFolder),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: c.folders
                            .where((f) => f.parentId == folder)
                            .map(
                              (f) => ActionChip(
                                avatar: const Icon(
                                  Icons.folder_outlined,
                                  size: 18,
                                ),
                                label: Text(f.name),
                                onPressed: () => setState(() => folder = f.id),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '${songs.length} ${l.songCount}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const Spacer(),
                        if (selected.isNotEmpty) ...[
                          TextButton(
                            onPressed: () => setState(selected.clear),
                            child: Text(l.clearSelection),
                          ),
                          IconButton(
                            tooltip: l.exportSelected,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ExportScreen(
                                  songs: c.songs
                                      .where((s) => selected.contains(s.id))
                                      .toList(),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.ios_share_rounded),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (songs.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  compact: true,
                  icon: Icons.library_music_outlined,
                  title: query.isNotEmpty
                      ? l.noResults
                      : view == 'trash'
                      ? l.emptyTrash
                      : l.emptyLibrary,
                  body: l.emptyLibraryBody,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) {
                    final s = songs[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: selected.isNotEmpty
                            ? Checkbox(
                                value: selected.contains(s.id),
                                onChanged: (v) => setState(
                                  () => v == true
                                      ? selected.add(s.id)
                                      : selected.remove(s.id),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.music_note_rounded),
                              ),
                        title: Text(
                          s.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${s.artist.isEmpty ? l.untitled : s.artist}  ·  ${s.currentKey}  ·  ${s.bpm} BPM',
                        ),
                        onTap: () => selected.isNotEmpty
                            ? setState(
                                () => selected.contains(s.id)
                                    ? selected.remove(s.id)
                                    : selected.add(s.id),
                              )
                            : context.push('/song/${s.id}'),
                        onLongPress: () => setState(() => selected.add(s.id)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l.favorites,
                              onPressed: () => guard(context, () async {
                                final copy = s.clone()..favorite = !s.favorite;
                                await c.saveSong(copy);
                              }),
                              icon: Icon(
                                s.favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: s.favorite
                                    ? const Color(0xffb56c3b)
                                    : null,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) => action(v, s),
                              itemBuilder: (ctx) => s.deleted
                                  ? [
                                      PopupMenuItem(
                                        value: 'restore',
                                        child: Text(l.restore),
                                      ),
                                      PopupMenuItem(
                                        value: 'destroy',
                                        child: Text(l.deleteForever),
                                      ),
                                    ]
                                  : [
                                      PopupMenuItem(
                                        value: 'select',
                                        child: Text(l.select),
                                      ),
                                      PopupMenuItem(
                                        value: 'copy',
                                        child: Text(l.duplicate),
                                      ),
                                      PopupMenuItem(
                                        value: 'move',
                                        child: Text(l.move),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        child: Text(
                                          s.archived ? l.unarchive : l.archive,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(l.delete),
                                      ),
                                    ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
  Future<void> showFilters(BuildContext context) async {
    final c = widget.library;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(ctx.l.filter),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in [
                (
                  ctx.l.instrumentFilter,
                  c.songs.map((s) => s.instrument).toSet().toList(),
                  instrument,
                  0,
                ),
                (
                  ctx.l.keyFilter,
                  c.songs.map((s) => s.currentKey).toSet().toList(),
                  keyFilter,
                  1,
                ),
                (
                  ctx.l.categoryFilter,
                  c.songs.expand((s) => s.tags).toSet().toList(),
                  tagFilter,
                  2,
                ),
              ])
                DropdownButtonFormField<String>(
                  initialValue: entry.$3,
                  decoration: InputDecoration(labelText: entry.$1),
                  items: [
                    DropdownMenuItem(value: '', child: Text(ctx.l.all)),
                    ...entry.$2.map(
                      (v) => DropdownMenuItem(value: v, child: Text(v)),
                    ),
                  ],
                  onChanged: (v) => update(() {
                    if (entry.$4 == 0) {
                      instrument = v ?? '';
                    } else if (entry.$4 == 1) {
                      keyFilter = v ?? '';
                    } else {
                      tagFilter = v ?? '';
                    }
                  }),
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l.apply),
            ),
          ],
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }
}
