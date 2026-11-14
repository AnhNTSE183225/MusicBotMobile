import 'package:signals_flutter/signals_flutter.dart';
import '../core/database/app_database.dart';
import '../models/music_models.dart';

class PatchNotesStore {
  final AppDatabase _database;

  final Signal<Set<String>> readVersions = signal(<String>{});
  late final ReadonlySignal<int> unreadCount;

  PatchNotesStore({required AppDatabase database}) : _database = database {
    unreadCount = computed(() {
      final read = readVersions.value;
      return kPatchNotes.where((p) => !read.contains(p.version)).length;
    });
  }

  String get currentVersion => kPatchNotes.first.version;
  PatchNote get latestPatch => kPatchNotes.first;

  Future<void> load() async {
    try {
      final stored = await _database.loadReadPatchVersions();
      readVersions.value = stored.toSet();
    } catch (_) {}
  }

  bool isRead(String version) => readVersions.value.contains(version);

  Future<void> toggleRead(String version) async {
    if (isRead(version)) {
      await markAsUnread(version);
    } else {
      await markAsRead(version);
    }
  }

  Future<void> markAsRead(String version) async {
    if (readVersions.value.contains(version)) return;
    readVersions.value = {...readVersions.value, version};
    try {
      await _database.markPatchVersionRead(version);
    } catch (_) {}
  }

  Future<void> markAsUnread(String version) async {
    if (!readVersions.value.contains(version)) return;
    final next = {...readVersions.value}..remove(version);
    readVersions.value = next;
    try {
      await _database.markPatchVersionUnread(version);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final all = kPatchNotes.map((p) => p.version).toList();
    readVersions.value = all.toSet();
    try {
      await _database.markAllPatchVersionsRead(all);
    } catch (_) {}
  }

  Future<void> markAllAsUnread() async {
    readVersions.value = <String>{};
    try {
      await _database.clearAllReadPatchVersions();
    } catch (_) {}
  }

  void dispose() {
    readVersions.dispose();
  }
}
