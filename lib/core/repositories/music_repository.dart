import 'dart:async';
import '../../models/music_models.dart';
import '../network/api_client.dart';

/// Segregated SOLID interfaces (ISP + DIP + LSP) for Music Room & AI operations.
abstract interface class AuthGateway {
  String get loginUrl;
  String get apiBaseUrl;
  void updateServerUrl(String baseUrl);
  Future<String?> getStoredToken();
  Future<void> saveToken(String token);
  Future<UserProfile?> checkAuth();
  Future<void> logout();
}

abstract interface class GuildVoiceGateway {
  Future<List<GuildSession>> fetchGuilds();
  Future<void> joinVoiceChannel(String guildId);
  Future<void> stopBot(String guildId);
}

abstract interface class PlaybackQueueGateway {
  Future<QueueStateDto> fetchQueue(String guildId);
  Stream<QueueStateDto> watchQueueSse(String guildId);
  Future<void> addSong(String guildId, String url);
  Future<void> skip(String guildId);
  Future<void> pause(String guildId);
  Future<void> resume(String guildId);
  Future<void> toggleLoop(String guildId);
  Future<void> setVolume(String guildId, int volume);
  Future<void> skipTo(String guildId, int oneBasedIndex);
  Future<void> removeTrack(String guildId, int oneBasedIndex);
  Future<void> clearQueue(String guildId);
  Future<LyricsData?> fetchLyrics(String guildId);
}

abstract interface class PlaylistGateway {
  Future<PlaylistPreviewResponse> previewPlaylist(String guildId, String url);
  Future<({int addedCount, String playlistTitle})> addPlaylistRange({
    required String guildId,
    required String title,
    required int startIndex,
    required int endIndex,
    required List<PlaylistTrack> selectedTracks,
  });
}

abstract interface class AiMusicGateway {
  Future<List<AISong>> suggestSongs(
    String guildId, {
    required String prompt,
    required int count,
  });
  Future<void> confirmSong(String guildId, AISong song);
  Future<int> confirmBatch(String guildId, List<AISong> songs);
  Future<AIAutoQueueConfig> fetchAutoQueueConfig(String guildId);
  Future<AIAutoQueueConfig> saveAutoQueueConfig(
    String guildId,
    AIAutoQueueConfig config,
  );
  Future<GeminiKeysResponse> fetchGeminiKeys();
  Future<String> contributeGeminiKey(String apiKey);
  Future<void> deleteGeminiKey(int keyId);
}

/// Concrete Dio implementation honoring all gateway contracts.
class LiveMusicRepository
    implements
        AuthGateway,
        GuildVoiceGateway,
        PlaybackQueueGateway,
        PlaylistGateway,
        AiMusicGateway {
  final ApiClient _client;

  LiveMusicRepository(this._client);

  @override
  String get loginUrl => _client.loginUrl;

  @override
  String get apiBaseUrl => _client.apiBaseUrl;

  @override
  void updateServerUrl(String baseUrl) {
    _client.updateEndpoints(apiBaseUrl: baseUrl);
  }

  @override
  Future<String?> getStoredToken() => _client.tokenStorage.readToken();

  @override
  Future<void> saveToken(String token) =>
      _client.tokenStorage.writeToken(token.trim());

  @override
  Future<UserProfile?> checkAuth() async {
    final token = await _client.tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    try {
      final res = await _client.get('/me');
      final rawUser = res['user'];
      if (rawUser is Map<String, dynamic>) {
        return UserProfile.fromJson(rawUser);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.post('/logout');
    } catch (_) {}
    await _client.tokenStorage.deleteToken();
  }

  @override
  Future<List<GuildSession>> fetchGuilds() async {
    try {
      Map<String, dynamic> data;
      try {
        data = await _client.get('/guilds');
      } catch (_) {
        data = await _client.get('/voice_status');
      }
      final rawGuilds = data['guilds'] ?? data['sessions'];
      if (rawGuilds is List) {
        return rawGuilds
            .whereType<Map<String, dynamic>>()
            .map(GuildSession.fromFlexibleJson)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> joinVoiceChannel(String guildId) async {
    await _client.post('/controls/$guildId/join');
  }

  @override
  Future<void> stopBot(String guildId) async {
    await _client.post('/controls/$guildId/stop');
  }

  @override
  Future<QueueStateDto> fetchQueue(String guildId) async {
    final raw = await _client.get('/queue/$guildId');
    return QueueStateDto.fromBackendPayload(raw);
  }

  @override
  Stream<QueueStateDto> watchQueueSse(String guildId) {
    return _client
        .connectQueueSse(guildId)
        .map(QueueStateDto.fromBackendPayload);
  }

  @override
  Future<void> addSong(String guildId, String url) async {
    await _client.post('/queue/$guildId', body: {'url': url});
  }

  @override
  Future<void> skip(String guildId) async {
    await _client.post('/controls/$guildId/skip');
  }

  @override
  Future<void> pause(String guildId) async {
    await _client.post('/controls/$guildId/pause');
  }

  @override
  Future<void> resume(String guildId) async {
    await _client.post('/controls/$guildId/resume');
  }

  @override
  Future<void> toggleLoop(String guildId) async {
    await _client.post('/controls/$guildId/loop');
  }

  @override
  Future<void> setVolume(String guildId, int volume) async {
    await _client.post('/controls/$guildId/volume', body: {'volume': volume});
  }

  @override
  Future<void> skipTo(String guildId, int oneBasedIndex) async {
    await _client.post(
      '/controls/$guildId/skipto',
      body: {'index': oneBasedIndex},
    );
  }

  @override
  Future<void> removeTrack(String guildId, int oneBasedIndex) async {
    await _client.post(
      '/controls/$guildId/remove',
      body: {'index': oneBasedIndex},
    );
  }

  @override
  Future<void> clearQueue(String guildId) async {
    await _client.post('/controls/$guildId/clear');
  }

  @override
  Future<LyricsData?> fetchLyrics(String guildId) async {
    final raw = await _client.get('/lyrics/$guildId');
    final lyricsJson = raw['lyrics'];
    if (lyricsJson is Map<String, dynamic>) {
      return LyricsData.fromJson(lyricsJson);
    }
    return null;
  }

  @override
  Future<PlaylistPreviewResponse> previewPlaylist(
    String guildId,
    String url,
  ) async {
    final raw = await _client.post(
      '/playlist/$guildId/preview',
      body: {'url': url},
    );
    return PlaylistPreviewResponse.fromJson(raw);
  }

  @override
  Future<({int addedCount, String playlistTitle})> addPlaylistRange({
    required String guildId,
    required String title,
    required int startIndex,
    required int endIndex,
    required List<PlaylistTrack> selectedTracks,
  }) async {
    final raw = await _client.post(
      '/playlist/$guildId/add',
      body: {
        'title': title,
        'start_index': startIndex,
        'end_index': endIndex,
        'tracks': selectedTracks
            .map(
              (t) => {
                'url': t.url,
                'title': t.title,
                'artist': t.artist,
                'thumbnail': t.thumbnail,
                'duration': t.duration,
              },
            )
            .toList(),
      },
    );
    final added =
        (raw['added_count'] as num?)?.toInt() ?? selectedTracks.length;
    final plTitle = (raw['playlist_title'] ?? title).toString();
    return (addedCount: added, playlistTitle: plTitle);
  }

  @override
  Future<List<AISong>> suggestSongs(
    String guildId, {
    required String prompt,
    required int count,
  }) async {
    final raw = await _client.post(
      '/ai/$guildId/suggest',
      body: {'prompt': prompt, 'count': count},
    );
    final list = raw['songs'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(AISong.fromJson)
          .take(count < 1 ? 1 : count)
          .toList();
    }
    return const [];
  }

  @override
  Future<void> confirmSong(String guildId, AISong song) async {
    await _client.post(
      '/ai/$guildId/confirm',
      body: {
        'url': song.url,
        'title': song.title,
        'artist': song.artist,
        'thumbnail': song.thumbnail,
        'duration': song.duration,
      },
    );
  }

  @override
  Future<int> confirmBatch(String guildId, List<AISong> songs) async {
    final raw = await _client.post(
      '/ai/$guildId/confirm_batch',
      body: {
        'songs': songs
            .map(
              (s) => {
                'url': s.url,
                'title': s.title,
                'artist': s.artist,
                'thumbnail': s.thumbnail,
                'duration': s.duration,
              },
            )
            .toList(),
      },
    );
    return (raw['added_count'] as num?)?.toInt() ?? songs.length;
  }

  @override
  Future<AIAutoQueueConfig> fetchAutoQueueConfig(String guildId) async {
    final raw = await _client.get('/ai/$guildId/autoqueue');
    return AIAutoQueueConfig.fromJson(raw);
  }

  @override
  Future<AIAutoQueueConfig> saveAutoQueueConfig(
    String guildId,
    AIAutoQueueConfig config,
  ) async {
    final raw = await _client.post(
      '/ai/$guildId/autoqueue',
      body: config.toJson(),
    );
    final cfgMap = raw['config'];
    if (cfgMap is Map<String, dynamic>) {
      return AIAutoQueueConfig.fromJson(cfgMap);
    }
    return config;
  }

  @override
  Future<GeminiKeysResponse> fetchGeminiKeys() async {
    final raw = await _client.get('/ai/keys');
    return GeminiKeysResponse.fromJson(raw);
  }

  @override
  Future<String> contributeGeminiKey(String apiKey) async {
    final raw = await _client.post(
      '/ai/keys/contribute',
      body: {'api_key': apiKey},
    );
    return (raw['message'] ?? 'Key added to the pool!').toString();
  }

  @override
  Future<void> deleteGeminiKey(int keyId) async {
    await _client.delete('/ai/keys/$keyId');
  }
}
