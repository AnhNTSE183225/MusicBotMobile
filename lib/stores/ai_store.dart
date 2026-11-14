import 'package:signals_flutter/signals_flutter.dart';
import '../core/repositories/music_repository.dart';
import '../models/music_models.dart';
import '../models/state_machine_dto.dart';
import 'entity_fsm_store.dart';

/// Reactive AI Music Assistant Store managing AI song search/suggestions,
/// Auto-Queue configuration, and Community Gemini API Key pool.
class AiStore {
  final AiMusicGateway _gateway;

  final StatefulEntityController<List<AISong>> searchFsm =
      StatefulEntityController<List<AISong>>(id: 'ai_search');
  final StatefulEntityController<AIAutoQueueConfig> autoQueueFsm =
      StatefulEntityController<AIAutoQueueConfig>(id: 'ai_autoqueue');
  final StatefulEntityController<GeminiKeysResponse> keysFsm =
      StatefulEntityController<GeminiKeysResponse>(id: 'ai_keys_pool');

  final Signal<String> activeModalTab = signal('search'); // 'search' | 'auto' | 'keys'
  final Signal<String> prompt = signal('');
  final Signal<int> suggestCount = signal(3);
  final Signal<Set<String>> addingUrls = signal(<String>{});

  final Signal<AIAutoQueueConfig> autoQueueDraft = signal(
    const AIAutoQueueConfig(enabled: false, prompt: '', count: 3),
  );

  AiStore(this._gateway);

  Future<void> suggestSongs(String guildId) async {
    final trimmed = prompt.value.trim();
    if (trimmed.isEmpty) return;

    final clampedCount = suggestCount.value.clamp(1, 20);
    searchFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Requesting $clampedCount AI suggestions for "$trimmed"',
    );
    try {
      final results = await _gateway.suggestSongs(
        guildId,
        prompt: trimmed,
        count: clampedCount,
      );
      if (results.isEmpty) {
        searchFsm.transitionTo(
          EntityStatus.idle,
          reason: 'No AI song matches returned',
        );
      } else {
        searchFsm.transitionTo(
          EntityStatus.active,
          reason: 'Received ${results.length} AI song suggestions',
          data: results,
        );
      }
    } catch (e) {
      searchFsm.transitionTo(
        EntityStatus.error,
        reason: 'AI suggestion failed: $e',
        error: e.toString(),
      );
    }
  }

  Future<bool> confirmSingleSong(String guildId, AISong song) async {
    addingUrls.value = {...addingUrls.value, song.url};
    try {
      await _gateway.confirmSong(guildId, song);
      final currentList = searchFsm.activeData.value ?? const [];
      final remaining =
          currentList.where((item) => item.url != song.url).toList();
      if (remaining.isEmpty) {
        searchFsm.transitionTo(
          EntityStatus.idle,
          reason: 'All suggested songs queued',
        );
      } else {
        searchFsm.transitionTo(
          EntityStatus.active,
          reason: 'Removed confirmed song from AI preview',
          data: remaining,
        );
      }
      return true;
    } catch (e) {
      searchFsm.transitionTo(
        EntityStatus.error,
        reason: 'Confirm song failed: $e',
        error: e.toString(),
      );
      return false;
    } finally {
      final copy = {...addingUrls.value}..remove(song.url);
      addingUrls.value = copy;
    }
  }

  Future<int?> confirmAllSongs(String guildId) async {
    final songs = searchFsm.activeData.value ?? const [];
    if (songs.isEmpty) return null;
    searchFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Batch confirming ${songs.length} AI songs',
      data: songs,
    );
    try {
      final added = await _gateway.confirmBatch(guildId, songs);
      searchFsm.transitionTo(
        EntityStatus.idle,
        reason: 'Batch confirmed $added AI songs',
      );
      return added;
    } catch (e) {
      searchFsm.transitionTo(
        EntityStatus.error,
        reason: 'Batch confirm failed: $e',
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> loadAutoQueueConfig(String guildId) async {
    autoQueueFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Loading AI auto-queue config',
    );
    try {
      final cfg = await _gateway.fetchAutoQueueConfig(guildId);
      autoQueueDraft.value = cfg;
      autoQueueFsm.transitionTo(
        cfg.enabled ? EntityStatus.active : EntityStatus.idle,
        reason: 'Loaded AI auto-queue config (enabled=${cfg.enabled})',
        data: cfg,
      );
    } catch (e) {
      autoQueueFsm.transitionTo(
        EntityStatus.error,
        reason: 'Failed to load auto-queue config: $e',
        error: e.toString(),
      );
    }
  }

  Future<bool> saveAutoQueueConfig(
    String guildId,
    AIAutoQueueConfig config,
  ) async {
    autoQueueFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Saving AI auto-queue config',
      data: config,
    );
    try {
      final saved = await _gateway.saveAutoQueueConfig(guildId, config);
      autoQueueDraft.value = saved;
      autoQueueFsm.transitionTo(
        saved.enabled ? EntityStatus.active : EntityStatus.idle,
        reason: 'Saved AI auto-queue config (enabled=${saved.enabled})',
        data: saved,
      );
      return true;
    } catch (e) {
      autoQueueFsm.transitionTo(
        EntityStatus.error,
        reason: 'Failed to save auto-queue config: $e',
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> loadGeminiKeys() async {
    keysFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Fetching Gemini community key pool',
    );
    try {
      final res = await _gateway.fetchGeminiKeys();
      keysFsm.transitionTo(
        EntityStatus.active,
        reason: 'Loaded ${res.totalPoolSize} Gemini pool keys',
        data: res,
      );
    } catch (e) {
      keysFsm.transitionTo(
        EntityStatus.error,
        reason: 'Failed to fetch Gemini keys: $e',
        error: e.toString(),
      );
    }
  }

  Future<String?> contributeKey(String rawKey) async {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) return null;
    try {
      final msg = await _gateway.contributeGeminiKey(trimmed);
      await loadGeminiKeys();
      return msg;
    } catch (e) {
      keysFsm.transitionTo(
        EntityStatus.error,
        reason: 'Key contribution failed: $e',
        error: e.toString(),
      );
      return null;
    }
  }

  Future<bool> deleteKey(int keyId) async {
    try {
      await _gateway.deleteGeminiKey(keyId);
      await loadGeminiKeys();
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    searchFsm.dispose();
    autoQueueFsm.dispose();
    keysFsm.dispose();
    activeModalTab.dispose();
    prompt.dispose();
    suggestCount.dispose();
    addingUrls.dispose();
    autoQueueDraft.dispose();
  }
}
