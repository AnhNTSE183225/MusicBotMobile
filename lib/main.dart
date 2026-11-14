import 'package:flutter/material.dart';
import 'components/glass_panel.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/repositories/music_repository.dart';
import 'core/repositories/schedule_repository.dart';
import 'router.dart';
import 'stores/ai_store.dart';
import 'stores/auth_store.dart';
import 'stores/patch_notes_store.dart';
import 'stores/room_store.dart';
import 'stores/schedule_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final apiClient = ApiClient();
  final musicRepo = LiveMusicRepository(apiClient);
  final scheduleRepo = LiveScheduleRepository(apiClient);

  final authStore = AuthStore(authGateway: musicRepo, database: db);
  final roomStore = RoomStore(
    guildVoice: musicRepo,
    playbackQueue: musicRepo,
    playlistGateway: musicRepo,
    db: db,
  );
  final aiStore = AiStore(musicRepo);
  final scheduleStore = ScheduleStore(gateway: scheduleRepo);
  final patchNotesStore = PatchNotesStore(database: db);

  // Initialize local persistence & session asynchronously
  await patchNotesStore.load();
  await authStore.initialize();
  if (authStore.isAuthenticated.value) {
    roomStore.startSessionPolling();
  }

  runApp(
    MusicBotMobileApp(
      authStore: authStore,
      roomStore: roomStore,
      aiStore: aiStore,
      scheduleStore: scheduleStore,
      patchNotesStore: patchNotesStore,
    ),
  );
}

class MusicBotMobileApp extends StatelessWidget {
  final AuthStore authStore;
  final RoomStore roomStore;
  final AiStore aiStore;
  final ScheduleStore scheduleStore;
  final PatchNotesStore patchNotesStore;

  const MusicBotMobileApp({
    super.key,
    required this.authStore,
    required this.roomStore,
    required this.aiStore,
    required this.scheduleStore,
    required this.patchNotesStore,
  });

  @override
  Widget build(BuildContext context) {
    final router = createAppRouter(
      authStore: authStore,
      roomStore: roomStore,
      aiStore: aiStore,
      scheduleStore: scheduleStore,
      patchNotesStore: patchNotesStore,
    );

    return MaterialApp.router(
      title: 'Music Bot',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppThemeTokens.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppThemeTokens.accentGreen,
          secondary: AppThemeTokens.accentEmerald,
          surface: AppThemeTokens.bgPrimary,
        ),
        // Sleek 4px translucent scrollbars (MOBILE_TECHSTACK.md Section 11.3)
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(4.0),
          radius: const Radius.circular(999),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.dragged)
                ? const Color(0x8094A3B8)
                : const Color(0x4094A3B8),
          ),
          trackVisibility: WidgetStateProperty.all(false),
        ),
      ),
      routerConfig: router,
    );
  }
}
