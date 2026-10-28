import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_backyard/app/localization/app_localizations.dart';
import 'package:music_backyard/app/theme/app_theme.dart';
import 'package:music_backyard/features/app_updates/data/release_config.dart';
import 'package:music_backyard/features/app_updates/data/update_repository.dart';
import 'package:music_backyard/features/app_updates/domain/release_track.dart';
import 'package:music_backyard/features/app_updates/presentation/app_updates_controller.dart';
import 'package:music_backyard/features/app_updates/presentation/app_updates_screen.dart';

import 'controller_test.dart' show FakePlatform, FeedAdapter;

void main() {
  testWidgets('Dutch update settings switch feeds and retain wifi preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final config = ReleaseConfig(
      stableEndpoint: Uri.parse('https://releases.example.test/stable.json'),
      betaEndpoint: Uri.parse('https://releases.example.test/beta.json'),
      downloadHosts: {'releases.example.test'},
      automaticWifiDownload: false,
    );
    final platform = FakePlatform(), feed = FeedAdapter();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('musicbackyard-update-ui'),
    ))!;
    final controller = AppUpdatesController(
      config: config,
      platform: platform,
      enableScheduling: false,
      network: () async => const UpdateNetwork(online: true, wifi: false),
      temporaryDirectory: () async => directory,
      repositories: (track) => UpdateRepository(
        endpoint: config.endpoint(track),
        track: track,
        trustedHosts: config.downloadHosts,
        dio: Dio()..httpClientAdapter = feed,
      ),
    );
    await tester.runAsync(controller.initialize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        locale: const Locale('nl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppUpdatesScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Updatekanaal'), findsOneWidget);
    await tester.tap(find.text('Stabiel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bèta').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(controller.track, ReleaseTrack.beta);
    expect(controller.update!.track, 'beta');
    expect(find.textContaining('Bètaversies'), findsOneWidget);
    await tester.tap(find.text('Updates automatisch downloaden via wifi'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    expect(controller.automaticWifiDownload, isTrue);
    expect(platform.installs, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
}
