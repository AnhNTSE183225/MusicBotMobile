import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../app_config.dart';

part 'app_database.g.dart';

LazyDatabase _openWalConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, AppConfig.sqliteDbName));

    // Executes all SQLite C FFI calls on a dedicated background Isolate
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // Match BACKEND_TECHSTACK.md & MOBILE_TECHSTACK.md SQLite WAL performance pragmas
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
        rawDb.execute('PRAGMA temp_store = MEMORY;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}

@DriftDatabase(include: {'tables.drift'})
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openWalConnection());

  @override
  int get schemaVersion => 1;

  Future<double> loadTrackOffset(String trackTitle) async {
    final rows = await getLyricOffset(trackTitle).get();
    if (rows.isEmpty) return 0.0;
    return rows.first;
  }

  Future<void> saveTrackOffset(String trackTitle, double offset) async {
    if (offset == 0.0) {
      await (delete(lyricOffsets)
            ..where((tbl) => tbl.trackTitle.equals(trackTitle)))
          .go();
      return;
    }
    await into(lyricOffsets).insertOnConflictUpdate(
      LyricOffsetsCompanion.insert(
        trackTitle: trackTitle,
        offsetSeconds: Value(offset),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<String>> loadReadPatchVersions() {
    return getAllReadPatchVersions().get();
  }

  Future<void> markPatchVersionRead(String version) async {
    await into(readPatchVersions).insertOnConflictUpdate(
      ReadPatchVersionsCompanion.insert(
        version: version,
        readAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> markPatchVersionUnread(String version) async {
    await (delete(readPatchVersions)
          ..where((tbl) => tbl.version.equals(version)))
        .go();
  }

  Future<void> markAllPatchVersionsRead(List<String> versions) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await batch((b) {
      for (final v in versions) {
        b.insert(
          readPatchVersions,
          ReadPatchVersionsCompanion.insert(version: v, readAt: now),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> clearAllReadPatchVersions() async {
    await delete(readPatchVersions).go();
  }

  Future<String?> loadSetting(String key) async {
    final rows = await getKvSetting(key).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> saveSetting(String key, String value) async {
    await into(appKvSettings).insertOnConflictUpdate(
      AppKvSettingsCompanion.insert(
        settingKey: key,
        settingValue: value,
      ),
    );
  }
}
