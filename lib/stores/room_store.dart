import 'dart:async';
import 'package:signals_flutter/signals_flutter.dart';
import '../core/database/app_database.dart';
import '../core/repositories/music_repository.dart';
import '../core/utils/youtube_utils.dart';
import '../models/music_models.dart';
import '../models/state_machine_dto.dart';
import 'entity_fsm_store.dart';

/// Reactive Room Store managing Guild voice sessions, SSE Playback/Queue FSM,
/// and Synchronized Lyrics FSM.
/// Zero scattered boolean flags (`isLoading`, `isError`, `isActive`) — uses
/// `StatefulEntityController` exclusively.
class RoomStore {
  final GuildVoiceGateway _guildVoice;
  final PlaybackQueueGateway _playbackQueue;
  final PlaylistGateway _playlistGateway;
  final AppDatabase _db;

  late final StatefulEntityController<QueueStateDto> playbackFsm;
  late final StatefulEntityController<LyricsData> lyricsFsm;
  late final StatefulEntityController<PlaylistPreviewResponse> playlistFsm;
  late final StatefulEntityController<String> addSongFsm;

  final Signal<List<GuildSession>> guilds = signal(const []);
  final Signal<String?> currentGuildId = signal(null);
  final Signal<String> roomView = signal('room'); // 'room' | 'schedule'
  final Signal<String> activeTab = signal('queue'); // 'queue' | 'lyrics'
  final Signal<int> currentPage = signal(1);
  final Signal<double> position = signal(0.0);
  final Signal<double> userOffset = signal(0.0);
  final Signal<String?> notice = signal(null);
  final Signal<String?> trackError = signal(null);
  final Signal<String> songInput = signal('');
  final Signal<bool> playlistLoadingMore = signal(false);

  static const int itemsPerPage = 10;

  StreamSubscription<QueueStateDto>? _sseSubscription;
  Timer? _guildPollTimer;
  Timer? _noticeTimer;
  Timer? _sseReconnectTimer;
  String? _lastTrackTitle;
  String? _dismissedServerError;
  String? _lastServerError;

  late final Computed<GuildSession?> currentGuild = computed(() {
    final id = currentGuildId.value;
    if (id == null) return null;
    for (final g in guilds.value) {
      if (g.guildId == id) return g;
    }
    return null;
  });

  late final Computed<TrackModel?> currentTrack = computed(
    () => playbackFsm.activeData.value?.current,
  );

  late final Computed<List<TrackModel>> upcomingQueue = computed(
    () => playbackFsm.activeData.value?.upcoming ?? const [],
  );

  late final Computed<int> totalPages = computed(() {
    final total = upcomingQueue.value.length;
    final pages = (total / itemsPerPage).ceil();
    return pages < 1 ? 1 : pages;
  });

  late final Computed<List<({TrackModel track, int originalIndex})>>
      paginatedQueue = computed(() {
    final list = upcomingQueue.value;
    final page = currentPage.value.clamp(1, totalPages.value);
    final start = (page - 1) * itemsPerPage;
    if (start >= list.length) return const [];
    final end = (start + itemsPerPage).clamp(0, list.length);
    final slice = <({TrackModel track, int originalIndex})>[];
    for (var i = start; i < end; i++) {
      slice.add((track: list[i], originalIndex: i));
    }
    return slice;
  });

  late final Computed<int> activeLyricLineIndex = computed(() {
    final lyrics = lyricsFsm.activeData.value;
    if (lyrics == null || lyrics.lines.isEmpty) return -1;
    final effectivePos = position.value - userOffset.value;
    var idx = -1;
    for (var i = 0; i < lyrics.lines.length; i++) {
      if (effectivePos >= lyrics.lines[i].time) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  });

  RoomStore({
    required GuildVoiceGateway guildVoice,
    required PlaybackQueueGateway playbackQueue,
    required PlaylistGateway playlistGateway,
    required AppDatabase db,
  })  : _guildVoice = guildVoice,
        _playbackQueue = playbackQueue,
        _playlistGateway = playlistGateway,
        _db = db {
    playbackFsm = StatefulEntityController<QueueStateDto>(
      id: 'room_playback',
      onForegroundResync: () {
        final gid = currentGuildId.value;
        if (gid != null) {
          refreshQueueSnapshot(gid);
        }
      },
    );
    lyricsFsm = StatefulEntityController<LyricsData>(
      id: 'room_lyrics',
    );
    playlistFsm = StatefulEntityController<PlaylistPreviewResponse>(
      id: 'playlist_preview',
    );
    addSongFsm = StatefulEntityController<String>(
      id: 'add_song',
    );
  }

  void showNotice(String message) {
    _noticeTimer?.cancel();
    notice.value = message;
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      notice.value = null;
    });
  }

  Future<void> startSessionPolling() async {
    await refreshGuilds();
    _guildPollTimer?.cancel();
    _guildPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refreshGuilds(),
    );
  }

  void stopSessionPolling() {
    _guildPollTimer?.cancel();
    _guildPollTimer = null;
    _cancelSse();
    playbackFsm.transitionTo(
      EntityStatus.disconnected,
      reason: 'Session polling stopped',
    );
    lyricsFsm.transitionTo(
      EntityStatus.idle,
      reason: 'Session polling stopped',
    );
  }

  Future<void> refreshGuilds() async {
    final fetched = await _guildVoice.fetchGuilds();
    guilds.value = fetched;

    if (fetched.isEmpty) return;

    final currentId = currentGuildId.value;
    final activeVoiceGuild = fetched.where((g) => g.inVoice).firstOrNull;
    if (currentId == null) {
      final initial = (activeVoiceGuild ?? fetched.first).guildId;
      await selectGuild(initial);
    } else if (activeVoiceGuild != null &&
        activeVoiceGuild.guildId != currentId) {
      final currentObj =
          fetched.where((g) => g.guildId == currentId).firstOrNull;
      if (currentObj == null || !currentObj.inVoice) {
        await selectGuild(activeVoiceGuild.guildId);
      }
    }
  }

  Future<void> selectGuild(String guildId) async {
    if (currentGuildId.value == guildId && _sseSubscription != null) return;
    currentGuildId.value = guildId;
    currentPage.value = 1;
    _lastTrackTitle = null;
    await refreshQueueSnapshot(guildId);
    _connectSse(guildId);
  }

  Future<void> refreshQueueSnapshot(String guildId) async {
    try {
      final snapshot = await _playbackQueue.fetchQueue(guildId);
      await _applyQueueSnapshot(snapshot, reason: 'HTTP queue snapshot');
    } catch (e) {
      playbackFsm.transitionTo(
        EntityStatus.error,
        reason: 'Queue fetch failed: $e',
        error: e.toString(),
      );
    }
  }

  void _connectSse(String guildId) {
    _cancelSse();
    _sseSubscription = _playbackQueue.watchQueueSse(guildId).listen(
      (snapshot) {
        _applyQueueSnapshot(snapshot, reason: 'SSE stream frame');
      },
      onError: (Object err) {
        _sseReconnectTimer?.cancel();
        _sseReconnectTimer = Timer(const Duration(seconds: 3), () {
          if (currentGuildId.value == guildId) {
            _connectSse(guildId);
          }
        });
      },
      onDone: () {
        _sseReconnectTimer?.cancel();
        _sseReconnectTimer = Timer(const Duration(seconds: 3), () {
          if (currentGuildId.value == guildId) {
            _connectSse(guildId);
          }
        });
      },
    );
  }

  void _cancelSse() {
    _sseReconnectTimer?.cancel();
    _sseReconnectTimer = null;
    _sseSubscription?.cancel();
    _sseSubscription = null;
  }

  Future<void> _applyQueueSnapshot(
    QueueStateDto snapshot, {
    required String reason,
  }) async {
    final resolvedStatus = snapshot.resolveStatus();
    final incomingErr = snapshot.playbackError?.trim();
    final hasServerErr = incomingErr != null && incomingErr.isNotEmpty;
    batch(() {
      position.value = snapshot.position;
      playbackFsm.transitionTo(
        resolvedStatus,
        reason: reason,
        data: snapshot,
      );
      if (resolvedStatus == EntityStatus.active) {
        trackError.value = null;
        _dismissedServerError = null;
      } else if (hasServerErr) {
        if (incomingErr != _dismissedServerError) {
          trackError.value = incomingErr;
        }
      } else if (_lastServerError != null && trackError.value == _lastServerError) {
        trackError.value = null;
        _dismissedServerError = null;
      }
      _lastServerError = hasServerErr ? incomingErr : null;
      if (currentPage.value > totalPages.value) {
        currentPage.value = totalPages.value;
      }
    });

    if (resolvedStatus == EntityStatus.active) {
      playbackFsm.startPeriodicTicker(
        interval: const Duration(milliseconds: 100),
        onTick: () {
          final current = playbackFsm.activeData.value?.current;
          if (current == null) return;
          final maxDur = current.duration.toDouble();
          final nextPos = position.value + 0.1;
          position.value = maxDur > 0 && nextPos > maxDur ? maxDur : nextPos;
        },
      );
    }

    final trackTitle = snapshot.current?.title;
    if (trackTitle != _lastTrackTitle) {
      _lastTrackTitle = trackTitle;
      if (trackTitle != null && trackTitle.isNotEmpty) {
        await _loadLyricsAndOffset(trackTitle);
      } else {
        userOffset.value = 0.0;
        lyricsFsm.transitionTo(
          EntityStatus.idle,
          reason: 'No active track',
        );
      }
    }
  }

  Future<void> _loadLyricsAndOffset(String trackTitle) async {
    final gid = currentGuildId.value;
    if (gid == null) return;

    final savedOffset = await _db.loadTrackOffset(trackTitle);
    userOffset.value = savedOffset;

    lyricsFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Fetching lyrics for "$trackTitle"',
    );
    try {
      final lyrics = await _playbackQueue.fetchLyrics(gid);
      if (lyrics != null && lyrics.lines.isNotEmpty) {
        lyricsFsm.transitionTo(
          EntityStatus.active,
          reason: 'Lyrics loaded (${lyrics.lines.length} lines)',
          data: lyrics,
        );
      } else {
        lyricsFsm.transitionTo(
          EntityStatus.idle,
          reason: 'No synchronized lyrics found',
        );
      }
    } catch (e) {
      lyricsFsm.transitionTo(
        EntityStatus.error,
        reason: 'Lyrics fetch error: $e',
        error: e.toString(),
      );
    }
  }

  Future<void> syncToLine(double lineTime) async {
    final track = currentTrack.value;
    if (track == null) return;
    final rawOffset = position.value - lineTime;
    final rounded = (rawOffset * 10).roundToDouble() / 10.0;
    userOffset.value = rounded;
    await _db.saveTrackOffset(track.title, rounded);
    final sign = rounded > 0 ? '+' : '';
    showNotice('Synced lyrics! Offset: $sign${rounded.toStringAsFixed(1)}s');
  }

  Future<void> adjustOffset(double delta) async {
    final track = currentTrack.value;
    if (track == null) return;
    final next = ((userOffset.value + delta) * 10).roundToDouble() / 10.0;
    userOffset.value = next;
    await _db.saveTrackOffset(track.title, next);
  }

  Future<void> resetOffset() async {
    final track = currentTrack.value;
    userOffset.value = 0.0;
    if (track != null) {
      await _db.saveTrackOffset(track.title, 0.0);
    }
    showNotice('Lyrics timing reset to default');
  }

  Future<void> summonBot() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _guildVoice.joinVoiceChannel(gid);
      showNotice('Summoned bot to voice channel!');
      await refreshGuilds();
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> stopBot() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _guildVoice.stopBot(gid);
      showNotice('Stopped playback & cleared queue.');
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> togglePlayPause() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      if (playbackFsm.status.value == EntityStatus.paused) {
        await _playbackQueue.resume(gid);
      } else {
        await _playbackQueue.pause(gid);
      }
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> skipTrack() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _playbackQueue.skip(gid);
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> toggleLoop() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _playbackQueue.toggleLoop(gid);
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> setVolume(int volume) async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    final clamped = volume.clamp(0, 200);
    final existing = playbackFsm.activeData.value;
    if (existing != null) {
      playbackFsm.transitionTo(
        playbackFsm.status.value,
        reason: 'Optimistic volume update ($clamped%)',
        data: existing.copyWith(volume: clamped),
      );
    }
    try {
      await _playbackQueue.setVolume(gid, clamped);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  void dismissTrackError() {
    _dismissedServerError = _lastServerError;
    trackError.value = null;
  }

  Future<void> skipToQueueIndex(int zeroBasedIndex) async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    trackError.value = null;
    try {
      await _playbackQueue.skipTo(gid, zeroBasedIndex + 1);
      showNotice('Skipped to song #${zeroBasedIndex + 1}!');
      await refreshQueueSnapshot(gid);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      trackError.value = msg;
      showNotice(msg);
    }
  }

  Future<void> removeQueueIndex(int zeroBasedIndex) async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _playbackQueue.removeTrack(gid, zeroBasedIndex + 1);
      showNotice('Removed song from queue.');
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  Future<void> clearQueue() async {
    final gid = currentGuildId.value;
    if (gid == null) return;
    try {
      await _playbackQueue.clearQueue(gid);
      currentPage.value = 1;
      showNotice('Queue cleared!');
      await refreshQueueSnapshot(gid);
    } catch (e) {
      showNotice(e.toString());
    }
  }

  /// Adds a single song or search query to the queue, stripping any `&list=` parameters
  /// so playlists are never accidentally imported from the single-song input.
  Future<bool> addSingleSong(String rawInput) async {
    if (addSongFsm.status.value == EntityStatus.loading) return false;
    final gid = currentGuildId.value;
    final trimmed = rawInput.trim();
    if (gid == null || trimmed.isEmpty) return false;

    if (YouTubeUtils.isPurePlaylistUrl(trimmed)) {
      showNotice(
        'Direct playlist URL detected. Use the Playlist button to import playlists.',
      );
      return false;
    }

    final cleanUrl = YouTubeUtils.stripPlaylistFromUrl(trimmed);
    trackError.value = null;
    addSongFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Submitting "$trimmed" to queue',
      data: trimmed,
    );
    showNotice('Processing track request...');
    try {
      await _playbackQueue.addSong(gid, cleanUrl);
      songInput.value = '';
      addSongFsm.transitionTo(
        EntityStatus.idle,
        reason: 'Track added to queue',
      );
      showNotice('Added to queue!');
      await refreshQueueSnapshot(gid);
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      trackError.value = msg;
      addSongFsm.transitionTo(
        EntityStatus.error,
        reason: 'Failed to add track: $msg',
        error: msg,
      );
      showNotice(msg);
      return false;
    }
  }

  Future<PlaylistPreviewResponse?> previewPlaylist(String rawUrl) async {
    final gid = currentGuildId.value;
    if (gid == null) return null;
    final cleaned = YouTubeUtils.cleanPlaylistUrl(rawUrl.trim());
    playlistFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Fetching playlist preview',
    );
    try {
      final preview = await _playlistGateway.previewPlaylist(
        gid,
        cleaned,
        offset: 0,
        limit: 20,
      );
      playlistFsm.transitionTo(
        EntityStatus.active,
        reason: 'Loaded playlist preview (${preview.tracks.length} tracks)',
        data: preview,
      );
      return preview;
    } catch (e) {
      playlistFsm.transitionTo(
        EntityStatus.error,
        reason: 'Playlist preview failed: $e',
        error: e.toString(),
      );
      return null;
    }
  }

  Future<PlaylistPreviewResponse?> loadMorePlaylistTracks(String rawUrl) async {
    final gid = currentGuildId.value;
    final current = playlistFsm.activeData.value;
    if (gid == null ||
        current == null ||
        !current.hasMore ||
        playlistLoadingMore.value) {
      return null;
    }
    final cleaned = YouTubeUtils.cleanPlaylistUrl(rawUrl.trim());
    playlistLoadingMore.value = true;
    try {
      final nextPage = await _playlistGateway.previewPlaylist(
        gid,
        cleaned,
        offset: current.tracks.length,
        limit: 20,
      );
      final existingIndices = current.tracks.map((t) => t.index).toSet();
      final appended = nextPage.tracks
          .where((t) => !existingIndices.contains(t.index))
          .toList();
      final merged = [...current.tracks, ...appended];
      final updated = PlaylistPreviewResponse(
        title: current.title,
        uploader: current.uploader,
        thumbnail: current.thumbnail,
        totalTracks: nextPage.totalTracks > merged.length
            ? nextPage.totalTracks
            : merged.length,
        offset: nextPage.offset,
        hasMore: nextPage.hasMore && appended.isNotEmpty,
        tracks: merged,
      );
      playlistFsm.transitionTo(
        EntityStatus.active,
        reason: 'Loaded ${appended.length} more playlist tracks',
        data: updated,
      );
      return updated;
    } catch (e) {
      showNotice(e.toString());
      return null;
    } finally {
      playlistLoadingMore.value = false;
    }
  }

  Future<bool> importPlaylistSelection({
    required String title,
    required int startIndex,
    required int endIndex,
    required List<PlaylistTrack> selectedTracks,
  }) async {
    final gid = currentGuildId.value;
    if (gid == null || selectedTracks.isEmpty) return false;
    playlistFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Importing ${selectedTracks.length} playlist tracks',
    );
    try {
      final res = await _playlistGateway.addPlaylistRange(
        guildId: gid,
        title: title,
        startIndex: startIndex,
        endIndex: endIndex,
        selectedTracks: selectedTracks,
      );
      playlistFsm.transitionTo(
        EntityStatus.idle,
        reason: 'Playlist import finished',
      );
      showNotice('Added ${res.addedCount} songs from "${res.playlistTitle}"!');
      await refreshQueueSnapshot(gid);
      return true;
    } catch (e) {
      playlistFsm.transitionTo(
        EntityStatus.error,
        reason: 'Playlist import failed: $e',
        error: e.toString(),
      );
      return false;
    }
  }

  void resetPlaylistPreview() {
    playlistFsm.transitionTo(
      EntityStatus.idle,
      reason: 'Playlist modal reset',
    );
  }

  void dispose() {
    stopSessionPolling();
    _noticeTimer?.cancel();
    playbackFsm.dispose();
    lyricsFsm.dispose();
    playlistFsm.dispose();
    addSongFsm.dispose();
    guilds.dispose();
    currentGuildId.dispose();
    roomView.dispose();
    activeTab.dispose();
    currentPage.dispose();
    position.dispose();
    userOffset.dispose();
    notice.dispose();
    trackError.dispose();
    songInput.dispose();
    playlistLoadingMore.dispose();
  }
}
