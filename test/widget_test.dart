import 'dart:async';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicbot_mobile/core/database/app_database.dart';
import 'package:musicbot_mobile/core/repositories/music_repository.dart';
import 'package:musicbot_mobile/core/repositories/schedule_repository.dart';
import 'package:musicbot_mobile/core/utils/schedule_utils.dart';
import 'package:musicbot_mobile/core/utils/youtube_utils.dart';
import 'package:musicbot_mobile/main.dart';
import 'package:musicbot_mobile/models/music_models.dart';
import 'package:musicbot_mobile/models/schedule_models.dart';
import 'package:musicbot_mobile/models/state_machine_dto.dart';
import 'package:musicbot_mobile/stores/ai_store.dart';
import 'package:musicbot_mobile/stores/auth_store.dart';
import 'package:musicbot_mobile/stores/entity_fsm_store.dart';
import 'package:musicbot_mobile/stores/patch_notes_store.dart';
import 'package:musicbot_mobile/stores/room_store.dart';
import 'package:musicbot_mobile/stores/schedule_store.dart';

/// In-memory LSP-compliant test double for Auth, Voice, Queue, Playlist, and AI Gateways.
class FakeMusicGateway
    implements
        AuthGateway,
        GuildVoiceGateway,
        PlaybackQueueGateway,
        PlaylistGateway,
        AiMusicGateway {
  String _serverUrl = 'http://localhost:8000/api';
  String? _token = 'test-token-123';
  final StreamController<QueueStateDto> sseController =
      StreamController<QueueStateDto>.broadcast();

  QueueStateDto currentSnapshot = const QueueStateDto(
    status: EntityStatus.active,
    current: TrackModel(
      id: 't_1',
      title: 'Midnight City',
      url: 'https://www.youtube.com/watch?v=dX3k_QDnzHE',
      image: '',
      duration: 243,
      artist: 'M83',
      requestedBy: 'TheAnh',
    ),
    queue: [
      TrackModel(
        id: 't_2',
        title: 'Nightcall',
        url: 'https://www.youtube.com/watch?v=MV_3Dpw-BRY',
        image: '',
        duration: 258,
        artist: 'Kavinsky',
        requestedBy: 'AI Auto-Queue',
      ),
    ],
    loop: false,
    position: 42.5,
    volume: 100,
    pauseVotes: 1,
    pauseVotesRequired: 2,
    skipVotes: 1,
    skipVotesRequired: 2,
  );

  @override
  String get apiBaseUrl => _serverUrl;

  @override
  String get loginUrl => 'http://localhost:8000/api/login';

  @override
  String buildMobileLoginUrl(String mobileState) =>
      'http://localhost:8000/api/login?platform=mobile&mobile_state=$mobileState';

  @override
  Future<String?> pollMobileAuth(String mobileState) async => _token;

  @override
  void updateServerUrl(String baseUrl) {
    _serverUrl = baseUrl;
  }

  @override
  Future<String?> getStoredToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<UserProfile?> checkAuth() async {
    if (_token == null) return null;
    return const UserProfile(
      id: 'u_1',
      username: 'TheAnh',
      avatar: '',
    );
  }

  @override
  Future<void> logout() async {
    _token = null;
  }

  @override
  Future<List<GuildSession>> fetchGuilds() async {
    return const [
      GuildSession(
        id: 'g_1',
        name: 'Vibe Coding Lounge',
        botConnected: true,
        channelId: 'c_1',
        channelName: 'General Voice',
      ),
    ];
  }

  @override
  Future<void> joinVoiceChannel(String guildId) async {}

  @override
  Future<void> stopBot(String guildId) async {}

  @override
  Future<QueueStateDto> fetchQueue(String guildId) async => currentSnapshot;

  @override
  Stream<QueueStateDto> watchQueueSse(String guildId) => sseController.stream;

  int addSongCalls = 0;
  Completer<void>? addSongCompleter;

  @override
  Future<void> addSong(String guildId, String url) async {
    addSongCalls++;
    if (addSongCompleter != null) {
      await addSongCompleter!.future;
    }
  }

  @override
  Future<void> skip(String guildId) async {}

  @override
  Future<void> pause(String guildId) async {}

  @override
  Future<void> resume(String guildId) async {}

  @override
  Future<void> toggleLoop(String guildId) async {}

  @override
  Future<void> setVolume(String guildId, int volume) async {}

  @override
  Future<void> skipTo(String guildId, int oneBasedIndex) async {}

  @override
  Future<void> removeTrack(String guildId, int oneBasedIndex) async {}

  @override
  Future<void> clearQueue(String guildId) async {}

  @override
  Future<LyricsData?> fetchLyrics(String guildId) async {
    return const LyricsData(
      type: 'syllable',
      provider: 'LRCLIB',
      lines: [
        LyricLine(
          begin: 10.0,
          end: 13.0,
          text: 'Waiting in a car',
          words: [
            LyricWord(begin: 10.0, end: 10.5, text: 'Waiting'),
            LyricWord(begin: 10.5, end: 11.0, text: 'in'),
            LyricWord(begin: 11.0, end: 11.5, text: 'a'),
            LyricWord(begin: 11.5, end: 12.2, text: 'car'),
          ],
        ),
        LyricLine(
          begin: 40.0,
          end: 45.0,
          text: 'Waiting for a ride in the dark',
        ),
      ],
    );
  }

  @override
  Future<PlaylistPreviewResponse> previewPlaylist(
    String guildId,
    String url,
  ) async {
    return const PlaylistPreviewResponse(
      title: 'Synthwave Classics',
      totalTracks: 2,
      tracks: [
        PlaylistTrack(
          index: 1,
          title: 'Sunset',
          url: 'https://youtube.com/watch?v=1',
          duration: 210,
          artist: 'The Midnight',
        ),
        PlaylistTrack(
          index: 2,
          title: 'Days of Thunder',
          url: 'https://youtube.com/watch?v=2',
          duration: 240,
          artist: 'The Midnight',
        ),
      ],
    );
  }

  @override
  Future<({int addedCount, String playlistTitle})> addPlaylistRange({
    required String guildId,
    required String title,
    required int startIndex,
    required int endIndex,
    required List<PlaylistTrack> selectedTracks,
  }) async {
    return (addedCount: selectedTracks.length, playlistTitle: title);
  }

  @override
  Future<List<AISong>> suggestSongs(
    String guildId, {
    required String prompt,
    required int count,
  }) async {
    return const [
      AISong(
        title: 'Tech Noir',
        artist: 'GUNSHIP',
        reason: 'Matches synthwave night drive mood',
        url: 'https://youtube.com/watch?v=3',
        duration: 297,
      ),
    ];
  }

  @override
  Future<void> confirmSong(String guildId, AISong song) async {}

  @override
  Future<int> confirmBatch(String guildId, List<AISong> songs) async =>
      songs.length;

  @override
  Future<AIAutoQueueConfig> fetchAutoQueueConfig(String guildId) async {
    return const AIAutoQueueConfig(
      enabled: true,
      prompt: 'Synthwave & Chillwave',
      count: 3,
    );
  }

  @override
  Future<AIAutoQueueConfig> saveAutoQueueConfig(
    String guildId,
    AIAutoQueueConfig config,
  ) async =>
      config;

  @override
  Future<GeminiKeysResponse> fetchGeminiKeys() async {
    return const GeminiKeysResponse(
      keys: [
        GeminiKeyInfo(
          id: 1,
          maskedKey: 'AIzaSy...9876',
          addedByUserId: 'u_1',
          addedByUsername: 'TheAnh',
          addedAt: 1712000000,
          isOwn: true,
        ),
      ],
      totalKeys: 1,
      totalActive: 1,
    );
  }

  @override
  Future<String> contributeGeminiKey(String apiKey) async => 'Key added!';

  @override
  Future<void> deleteGeminiKey(int keyId) async {}
}

class FakeScheduleGateway implements ScheduleGateway {
  @override
  Future<ScheduleDataResponse> fetchSchedule(String guildId) async {
    final startIso =
        DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String();
    return ScheduleDataResponse(
      events: [
        ScheduleEvent(
          id: 'ev_1',
          guildId: guildId,
          title: 'Friday Synthwave Listening Party',
          description: 'Bring your favorite retro tracks!',
          category: 'other',
          start: startIso,
          durationMinutes: 90,
          organizerId: 'u_1',
          organizerName: 'TheAnh',
          inviteEveryone: true,
        ),
      ],
      members: const [
        ServerMember(id: 'u_1', name: 'TheAnh', avatar: ''),
      ],
      channels: const [
        ServerChannel(id: 'c_1', name: 'General Voice', type: 'voice'),
      ],
    );
  }

  @override
  Future<ScheduleEvent> createEvent(
    String guildId,
    Map<String, dynamic> payload,
  ) async {
    return ScheduleEvent(
      id: 'ev_new',
      guildId: guildId,
      title: (payload['title'] ?? 'New Event').toString(),
      start: DateTime.now().toUtc().toIso8601String(),
      organizerId: 'u_1',
    );
  }

  @override
  Future<ScheduleEvent> updateEvent(
    String guildId,
    String eventId,
    Map<String, dynamic> payload,
  ) async {
    return ScheduleEvent(
      id: eventId,
      guildId: guildId,
      title: (payload['title'] ?? 'Updated Event').toString(),
      start: DateTime.now().toUtc().toIso8601String(),
      organizerId: 'u_1',
    );
  }

  @override
  Future<void> deleteEvent(
    String guildId,
    String eventId, {
    String? occurrence,
  }) async {}

  @override
  Future<ScheduleEvent> respondToEvent(
    String guildId,
    String eventId, {
    required String key,
    required RsvpStatus status,
    required RsvpScope scope,
  }) async {
    return ScheduleEvent(
      id: eventId,
      guildId: guildId,
      title: 'Friday Synthwave Listening Party',
      start: DateTime.now().toUtc().toIso8601String(),
      organizerId: 'u_1',
    );
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('1. Deterministic FSM & OS Lifecycle Reconciliation', () {
    testWidgets(
      'StatefulEntityController transitions deterministically, tears down data on resting states, and reconciles OS lifecycle',
      (tester) async {
        var resyncCalled = false;
        final fsm = StatefulEntityController<String>(
          id: 'test_entity',
          onForegroundResync: () {
            resyncCalled = true;
          },
        );

        expect(fsm.status.value, EntityStatus.disconnected);
        expect(fsm.activeData.value, isNull);

        fsm.transitionTo(
          EntityStatus.active,
          reason: 'Track started',
          data: 'Midnight City',
        );
        expect(fsm.status.value, EntityStatus.active);
        expect(fsm.activeData.value, 'Midnight City');

        var tickCount = 0;
        fsm.startPeriodicTicker(
          interval: const Duration(milliseconds: 50),
          onTick: () => tickCount++,
        );
        await tester.pump(const Duration(milliseconds: 160));
        expect(tickCount, greaterThanOrEqualTo(2));

        // Simulate OS backgrounding -> ticker must pause
        fsm.didChangeAppLifecycleState(AppLifecycleState.paused);
        final ticksAtPause = tickCount;
        await tester.pump(const Duration(milliseconds: 160));
        expect(tickCount, equals(ticksAtPause));

        // Simulate OS foreground resume -> transitions to loading & invokes resync
        fsm.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(fsm.status.value, EntityStatus.loading);
        expect(resyncCalled, isTrue);

        // Resting state atomic teardown
        fsm.transitionTo(EntityStatus.idle, reason: 'Queue finished');
        expect(fsm.status.value, EntityStatus.idle);
        expect(fsm.activeData.value, isNull);

        fsm.dispose();
      },
    );
  });

  group('2. Pure Domain Utilities (YouTubeUtils & ScheduleUtils)', () {
    test('YouTubeUtils detects playlists and strips list params for single songs', () {
      const videoWithPlaylist =
          'https://www.youtube.com/watch?v=dX3k_QDnzHE&list=PL1234567890&index=3';
      const purePlaylist =
          'https://www.youtube.com/playlist?list=PL1234567890';

      expect(YouTubeUtils.isYouTubePlaylistUrl(videoWithPlaylist), isTrue);
      expect(YouTubeUtils.isYouTubePlaylistUrl(purePlaylist), isTrue);
      expect(YouTubeUtils.isPurePlaylistUrl(purePlaylist), isTrue);
      expect(YouTubeUtils.isPurePlaylistUrl(videoWithPlaylist), isFalse);

      final stripped = YouTubeUtils.stripPlaylistFromUrl(videoWithPlaylist);
      expect(stripped.contains('list='), isFalse);
      expect(stripped.contains('v=dX3k_QDnzHE'), isTrue);

      final cleanedPlaylist = YouTubeUtils.cleanPlaylistUrl(videoWithPlaylist);
      expect(
        cleanedPlaylist,
        'https://www.youtube.com/playlist?list=PL1234567890',
      );
    });

    test('ScheduleUtils expands recurring weekly events and summarizes RSVPs', () {
      final start = DateTime(2026, 4, 1, 20, 0); // Wednesday
      final event = ScheduleEvent(
        id: 'ev_rec',
        guildId: 'g_1',
        title: 'Weekly Jam',
        start: start.toUtc().toIso8601String(),
        durationMinutes: 60,
        organizerId: 'u_1',
        recurrence: const ScheduleEventRecurrence(
          freq: 'weekly',
          interval: 1,
          count: 3,
        ),
        seriesResponses: const {'u_1': 'accepted'},
      );

      final occurrences = ScheduleUtils.expandEvent(
        event,
        start.subtract(const Duration(days: 1)),
        start.add(const Duration(days: 30)),
      );
      expect(occurrences.length, 3);

      final summary = ScheduleUtils.summarizeResponses(
        event,
        occurrences.first.key,
        const [ServerMember(id: 'u_1', name: 'TheAnh')],
      );
      expect(summary['accepted']?.length, 1);
    });
  });

  group('3. Multi-Viewport Responsive Overflow & Leaf-Reactive UI Audit', () {
    const viewports = <String, Size>{
      'iPhone SE Portrait (375x667)': Size(375, 667),
      'iPhone 14 Pro Portrait (390x844)': Size(390, 844),
      'Phone Landscape (844x390)': Size(844, 390),
      'iPad Portrait (768x1024)': Size(768, 1024),
      'iPad Landscape (1024x768)': Size(1024, 768),
    };

    for (final entry in viewports.entries) {
      testWidgets(
        'Zero RenderFlex overflow on ${entry.key} across Listening Room & Schedule views',
        (tester) async {
          await tester.binding.setSurfaceSize(entry.value);
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final db = AppDatabase(NativeDatabase.memory());
          final musicGateway = FakeMusicGateway();
          final scheduleGateway = FakeScheduleGateway();

          final authStore = AuthStore(
            authGateway: musicGateway,
            database: db,
          );
          final roomStore = RoomStore(
            guildVoice: musicGateway,
            playbackQueue: musicGateway,
            playlistGateway: musicGateway,
            db: db,
          );
          final aiStore = AiStore(musicGateway);
          final scheduleStore = ScheduleStore(gateway: scheduleGateway);
          final patchNotesStore = PatchNotesStore(database: db);

          await patchNotesStore.load();
          await authStore.initialize();
          await roomStore.refreshGuilds();
          await aiStore.loadAutoQueueConfig('g_1');
          await scheduleStore.fetchSchedule('g_1');

          await tester.pumpWidget(
            MusicBotMobileApp(
              authStore: authStore,
              roomStore: roomStore,
              aiStore: aiStore,
              scheduleStore: scheduleStore,
              patchNotesStore: patchNotesStore,
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));

          // Verify Listening Room Queue view renders current track & queue
          expect(
            find.text('Midnight City', skipOffstage: false),
            findsOneWidget,
          );
          expect(
            find.text('Nightcall', skipOffstage: false),
            findsOneWidget,
          );

          // Switch to Synchronized Lyrics tab
          roomStore.activeTab.value = 'lyrics';
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.text('Waiting for a ride in the dark', skipOffstage: false),
            findsOneWidget,
          );

          // Switch to Server Schedule view (Agenda, Month, Week)
          roomStore.roomView.value = 'schedule';
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.text(
              'Friday Synthwave Listening Party',
              skipOffstage: false,
            ),
            findsOneWidget,
          );

          scheduleStore.viewMode.value = CalendarViewMode.month;
          await tester.pump(const Duration(milliseconds: 350));

          scheduleStore.viewMode.value = CalendarViewMode.week;
          await tester.pump(const Duration(milliseconds: 350));

          // Clean up timers & database before test ends
          roomStore.dispose();
          aiStore.dispose();
          scheduleStore.dispose();
          authStore.dispose();
          patchNotesStore.dispose();
          await db.close();
        },
      );
    }
  });

  test('RoomStore addSingleSong exposes loading FSM and prevents duplicate spam', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final db = AppDatabase(NativeDatabase.memory());
    final gateway = FakeMusicGateway()..addSongCompleter = Completer<void>();
    final roomStore = RoomStore(
      guildVoice: gateway,
      playbackQueue: gateway,
      playlistGateway: gateway,
      db: db,
    );
    roomStore.currentGuildId.value = 'g_1';

    final firstFuture = roomStore.addSingleSong(
      'https://www.youtube.com/watch?v=XUrmskUYoas',
    );
    expect(roomStore.addSongFsm.status.value, EntityStatus.loading);
    expect(gateway.addSongCalls, 1);

    // Spam call while still loading must be ignored
    final duplicateAccepted = await roomStore.addSingleSong(
      'https://www.youtube.com/watch?v=XUrmskUYoas',
    );
    expect(duplicateAccepted, isFalse);
    expect(gateway.addSongCalls, 1);

    gateway.addSongCompleter!.complete();
    final firstOk = await firstFuture;
    expect(firstOk, isTrue);
    expect(roomStore.addSongFsm.status.value, EntityStatus.idle);

    roomStore.dispose();
    await db.close();
  });
}
