import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Aggregate JSON preserves structured music without generated ORM boilerplate.
// The versioned SQLite schema and all aggregate writes remain transactional.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);
  factory AppDatabase.open() => AppDatabase(
    LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, 'musicbackyard.sqlite')),
      );
    }),
  );
  @override
  int get schemaVersion => 2;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await createV1();
      await migrateV2();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await migrateV2();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
  Future<void> createV1() async {
    for (final table in ['songs', 'folders', 'setlists']) {
      await customStatement(
        'CREATE TABLE $table (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)',
      );
    }
  }

  Future<void> migrateV2() async {
    await customStatement(
      "CREATE TABLE preferences (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)",
    );
  }
}
