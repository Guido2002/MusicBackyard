import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/services/library_controller.dart';
import '../core/widgets/common.dart';
import '../features/library/library_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/songs/presentation/song_screen.dart';
import '../features/setlists/setlists_screen.dart';
import '../features/performance/performance_screen.dart';
import '../features/app_updates/presentation/app_updates_screen.dart';
import '../features/app_updates/presentation/app_updates_controller.dart';
import '../features/app_updates/presentation/update_notice.dart';
import 'localization/app_localizations.dart';
import 'localization/context_l10n.dart';
import 'theme/app_theme.dart';

class MusicBackyardApp extends ConsumerStatefulWidget {
  const MusicBackyardApp({super.key});
  @override
  ConsumerState<MusicBackyardApp> createState() => _MusicBackyardAppState();
}

class _MusicBackyardAppState extends ConsumerState<MusicBackyardApp>
    with WidgetsBindingObserver {
  late final LibraryController library = ref.read(libraryProvider);
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) =>
            MainShell(library: library, updates: ref.read(updatesProvider)),
      ),
      GoRoute(
        path: '/song/:id',
        builder: (c, s) =>
            SongScreen(library: library, id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/setlist/:id',
        builder: (c, s) =>
            SetlistScreen(library: library, id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/play',
        builder: (c, s) => PerformanceScreen(
          library: library,
          songId: s.uri.queryParameters['song'],
          arrangementId: s.uri.queryParameters['arrangement'],
          setlistId: s.uri.queryParameters['setlist'],
        ),
      ),
      GoRoute(
        path: '/updates',
        builder: (c, s) =>
            AppUpdatesScreen(controller: ref.read(updatesProvider)),
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!library.ready) {
      unawaited(library.load());
    }
    unawaited(ref.read(updatesProvider).initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final updates = ref.read(updatesProvider);
    if (state == AppLifecycleState.resumed) {
      unawaited(updates.onResume());
    } else {
      updates.onPause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library,
    builder: (context, _) => MaterialApp.router(
      title: 'MusicBackyard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: library.themeMode,
      locale: const Locale('nl'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        if (library.error != null) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.storage_rounded,
              title: context.l.error,
              body: context.l.dataError,
              action: FilledButton(
                onPressed: library.load,
                child: Text(context.l.retry),
              ),
            ),
          );
        }
        if (!library.ready) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (library.preferences['onboarded'] != true) {
          return Onboarding(library: library);
        }
        return child!;
      },
    ),
  );
}

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.library});
  final LibraryController library;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  String? instrument;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/branding/app-icon.png',
                      width: 100,
                      height: 100,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    ['01 / 03', '02 / 03', '03 / 03'][step],
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    [l.welcome, l.instrument, l.firstSong][step],
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  if (step == 0)
                    Text(
                      l.welcomeBody,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  if (step == 1)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                                (v) => ChoiceChip(
                                  label: Text(v),
                                  selected: instrument == v,
                                  onSelected: (_) =>
                                      setState(() => instrument = v),
                                ),
                              )
                              .toList(),
                    ),
                  if (step == 2)
                    Text(
                      l.firstSongBody,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      if (step > 0)
                        TextButton(
                          onPressed: () => setState(() => step--),
                          child: Text(l.back),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => guard(context, () async {
                          if (step < 2) {
                            setState(() => step++);
                          } else {
                            if (instrument != null) {
                              await widget.library.setPreference(
                                'instrument',
                                instrument,
                              );
                            }
                            await widget.library.setPreference(
                              'onboarded',
                              true,
                            );
                          }
                        }),
                        child: Text(step == 2 ? l.start : l.next),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.library, required this.updates});
  final LibraryController library;
  final AppUpdatesController updates;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final labels = [l.library, l.studio, l.setlists, l.performance, l.more];
    const icons = [
      Icons.library_music_outlined,
      Icons.edit_note_rounded,
      Icons.queue_music_rounded,
      Icons.play_circle_outline_rounded,
      Icons.grid_view_rounded,
    ];
    final pages = [
      LibraryScreen(library: widget.library),
      LibraryScreen(library: widget.library, studio: true),
      SetlistsScreen(library: widget.library),
      PerformancePicker(library: widget.library),
      SettingsScreen(library: widget.library),
    ];
    return LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 760;
        return Scaffold(
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  extended: size.maxWidth >= 1150,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/branding/app-icon.png',
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() => index = v),
                  destinations: List.generate(
                    5,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    UpdateNotice(controller: widget.updates),
                    Expanded(
                      child: IndexedStack(index: index, children: pages),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (v) => setState(() => index = v),
                  destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
