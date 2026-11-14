import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../models/music_models.dart';
import '../models/state_machine_dto.dart';
import '../stores/ai_store.dart';
import '../stores/room_store.dart';
import 'glass_panel.dart';
import 'sliding_segmented_pill.dart';

/// AI Music Assistant Modal (AI Search & Preview, Auto-Queue Rules, Gemini Key Pool).
class AiAssistantModal extends StatefulWidget {
  final AiStore aiStore;
  final RoomStore roomStore;

  const AiAssistantModal({
    super.key,
    required this.aiStore,
    required this.roomStore,
  });

  @override
  State<AiAssistantModal> createState() => _AiAssistantModalState();
}

class _AiAssistantModalState extends State<AiAssistantModal> {
  late final TextEditingController _promptController;
  late final TextEditingController _autoPromptController;
  late final TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _promptController =
        TextEditingController(text: widget.aiStore.prompt.value);
    _autoPromptController = TextEditingController(
      text: widget.aiStore.autoQueueDraft.value.prompt,
    );
    _apiKeyController = TextEditingController();

    final gid = widget.roomStore.currentGuildId.value;
    if (gid != null) {
      widget.aiStore.loadAutoQueueConfig(gid).then((_) {
        if (mounted) {
          _autoPromptController.text =
              widget.aiStore.autoQueueDraft.value.prompt;
        }
      });
    }
    widget.aiStore.loadGeminiKeys();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _autoPromptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiStore = widget.aiStore;
    final roomStore = widget.roomStore;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          AppThemeTokens.accentIndigo.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            AppThemeTokens.accentIndigo.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppThemeTokens.accentIndigo,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Music Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppThemeTokens.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Powered by Gemini • Smart Discovery, Auto-Queue & Community Pool',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppThemeTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Sliding Segmented Tab Pill
              Watch((context) {
                final tab = aiStore.activeModalTab.value;
                final poolCount =
                    aiStore.keysFsm.activeData.value?.totalPoolSize ?? 0;
                return SlidingSegmentedPill<String>(
                  selectedValue: tab,
                  onSelected: (v) => aiStore.activeModalTab.value = v,
                  options: [
                    const SlidingPillOption(
                      value: 'search',
                      label: 'AI Search',
                      icon: Icons.search_rounded,
                    ),
                    const SlidingPillOption(
                      value: 'auto',
                      label: 'Auto-Queue',
                      icon: Icons.bolt_rounded,
                    ),
                    SlidingPillOption(
                      value: 'keys',
                      label: 'Key Pool',
                      icon: Icons.vpn_key_rounded,
                      badge: '$poolCount',
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Active Tab Content
              Flexible(
                child: Watch((context) {
                  final tab = aiStore.activeModalTab.value;
                  if (tab == 'auto') {
                    return _buildAutoQueueTab(aiStore, roomStore);
                  }
                  if (tab == 'keys') {
                    return _buildKeyPoolTab(aiStore, roomStore);
                  }
                  return _buildSearchTab(aiStore, roomStore);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab(AiStore aiStore, RoomStore roomStore) {
    final status = aiStore.searchFsm.status.value;
    final songs = aiStore.searchFsm.activeData.value ?? const [];
    final error = aiStore.searchFsm.errorMessage.value;
    final count = aiStore.suggestCount.value;
    final addingUrls = aiStore.addingUrls.value;
    final gid = roomStore.currentGuildId.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prompt & Count Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promptController,
                onChanged: (v) => aiStore.prompt.value = v,
                onSubmitted: (_) {
                  if (gid != null) aiStore.suggestSongs(gid);
                },
                style: const TextStyle(
                  fontSize: 13,
                  color: AppThemeTokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Describe a vibe, genre, or mood (e.g. synthwave night drive)...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textMuted,
                  ),
                  filled: true,
                  fillColor: AppThemeTokens.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppThemeTokens.borderSubtle),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Count selector (1, 3, 5, 10)
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppThemeTokens.bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppThemeTokens.borderSubtle),
                ),
                child: DropdownButton<int>(
                  value: [1, 3, 5, 10].contains(count) ? count : 3,
                  dropdownColor: AppThemeTokens.bgElevated,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.textPrimary,
                  ),
                  items: [1, 3, 5, 10]
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('$c songs'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) aiStore.suggestCount.value = v;
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: status == EntityStatus.loading || gid == null
                  ? null
                  : () => aiStore.suggestSongs(gid),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeTokens.accentIndigo,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                status == EntityStatus.loading ? 'Thinking...' : 'Suggest',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppThemeTokens.accentRose.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppThemeTokens.accentRose.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFECDD3),
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Results List
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    status == EntityStatus.loading
                        ? 'Gemini is curating songs & verifying YouTube streams...'
                        : 'Enter a prompt above to preview AI song recommendations.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${songs.length} recommendations ready',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppThemeTokens.textSecondary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: gid == null
                              ? null
                              : () async {
                                  final added =
                                      await aiStore.confirmAllSongs(gid);
                                  if (added != null) {
                                    roomStore.showNotice(
                                      'Added $added AI songs to queue!',
                                    );
                                    await roomStore.refreshQueueSnapshot(gid);
                                  }
                                },
                          icon: const Icon(
                            Icons.playlist_add_rounded,
                            size: 16,
                            color: AppThemeTokens.accentGreen,
                          ),
                          label: Text(
                            'Add All (${songs.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppThemeTokens.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: songs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final song = songs[idx];
                          final isAdding = addingUrls.contains(song.url);

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x14FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppThemeTokens.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppThemeTokens.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${song.artist} • ${AppThemeTokens.formatDuration(song.duration)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppThemeTokens.textSecondary,
                                        ),
                                      ),
                                      if (song.reason.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          song.reason,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Color(0xFFC4B5FD),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: isAdding || gid == null
                                      ? null
                                      : () async {
                                          final ok = await aiStore
                                              .confirmSingleSong(gid, song);
                                          if (ok) {
                                            roomStore.showNotice(
                                              'Added "${song.title}"!',
                                            );
                                            await roomStore
                                                .refreshQueueSnapshot(gid);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppThemeTokens.accentGreen,
                                    foregroundColor: AppThemeTokens.bgDeep,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    isAdding ? '...' : '+ Add',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAutoQueueTab(AiStore aiStore, RoomStore roomStore) {
    final draft = aiStore.autoQueueDraft.value;
    final gid = roomStore.currentGuildId.value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: const Text(
              'Enable AI Auto-Queue',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppThemeTokens.textPrimary,
              ),
            ),
            subtitle: const Text(
              'Automatically queue matching songs when the current queue runs out',
              style: TextStyle(
                fontSize: 11,
                color: AppThemeTokens.textSecondary,
              ),
            ),
            value: draft.enabled,
            activeThumbColor: AppThemeTokens.accentPurple,
            onChanged: (val) {
              aiStore.autoQueueDraft.value = AIAutoQueueConfig(
                enabled: val,
                prompt: _autoPromptController.text,
                count: draft.count,
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'AUTO-QUEUE VIBE / PROMPT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppThemeTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _autoPromptController,
            maxLines: 2,
            onChanged: (val) {
              aiStore.autoQueueDraft.value = AIAutoQueueConfig(
                enabled: draft.enabled,
                prompt: val,
                count: draft.count,
              );
            },
            style: const TextStyle(
              fontSize: 13,
              color: AppThemeTokens.textPrimary,
            ),
            decoration: InputDecoration(
              hintText:
                  'e.g. Chill lo-fi beats, acoustic indie, or late night R&B...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppThemeTokens.textMuted,
              ),
              filled: true,
              fillColor: AppThemeTokens.bgInput,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppThemeTokens.borderSubtle),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SONGS PER REFILL BATCH',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                ],
                selected: {draft.count.clamp(1, 5)},
                onSelectionChanged: (s) {
                  aiStore.autoQueueDraft.value = AIAutoQueueConfig(
                    enabled: draft.enabled,
                    prompt: _autoPromptController.text,
                    count: s.first,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: gid == null
                ? null
                : () async {
                    final cfg = AIAutoQueueConfig(
                      enabled: aiStore.autoQueueDraft.value.enabled,
                      prompt: _autoPromptController.text.trim(),
                      count: aiStore.autoQueueDraft.value.count,
                    );
                    final ok = await aiStore.saveAutoQueueConfig(gid, cfg);
                    if (ok && mounted) {
                      roomStore.showNotice(
                        cfg.enabled
                            ? 'AI Auto-Queue enabled!'
                            : 'AI Auto-Queue disabled.',
                      );
                      Navigator.of(context).pop();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeTokens.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'Save Auto-Queue Settings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPoolTab(AiStore aiStore, RoomStore roomStore) {
    final keysRes = aiStore.keysFsm.activeData.value;
    final keys = keysRes?.keys ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _apiKeyController,
                obscureText: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppThemeTokens.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste free Gemini API key (AIzaSy...)...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textMuted,
                  ),
                  filled: true,
                  fillColor: AppThemeTokens.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppThemeTokens.borderSubtle),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                final msg =
                    await aiStore.contributeKey(_apiKeyController.text);
                if (msg != null) {
                  _apiKeyController.clear();
                  roomStore.showNotice(msg);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeTokens.accentGreen,
                foregroundColor: AppThemeTokens.bgDeep,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Contribute',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: keys.isEmpty
              ? const Center(
                  child: Text(
                    'No community Gemini keys registered yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: keys.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final k = keys[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppThemeTokens.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.vpn_key_rounded,
                            size: 16,
                            color: AppThemeTokens.accentGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  k.maskedKey,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppThemeTokens.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Contributed by ${k.addedByName}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppThemeTokens.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (k.isOwn)
                            IconButton(
                              onPressed: () => aiStore.deleteKey(k.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppThemeTokens.accentRose,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
