import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../models/music_models.dart';
import '../models/state_machine_dto.dart';
import '../stores/ai_store.dart';
import '../stores/room_store.dart';
import 'glass_panel.dart';
import 'sliding_segmented_pill.dart';

/// Right/Bottom Queue & Synchronized Lyrics Panel matching MusicBotUI.
class QueueLyricsPanel extends StatefulWidget {
  final RoomStore roomStore;
  final AiStore aiStore;
  final VoidCallback onOpenPlaylistModal;
  final ValueChanged<String> onOpenAiModal;

  const QueueLyricsPanel({
    super.key,
    required this.roomStore,
    required this.aiStore,
    required this.onOpenPlaylistModal,
    required this.onOpenAiModal,
  });

  @override
  State<QueueLyricsPanel> createState() => _QueueLyricsPanelState();
}

class _QueueLyricsPanelState extends State<QueueLyricsPanel> {
  late final TextEditingController _songController;

  @override
  void initState() {
    super.initState();
    _songController = TextEditingController();
  }

  @override
  void dispose() {
    _songController.dispose();
    super.dispose();
  }

  Future<void> _submitSingleSong() async {
    final text = _songController.text.trim();
    if (text.isEmpty) return;
    final ok = await widget.roomStore.addSingleSong(text);
    if (ok && mounted) {
      _songController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomStore = widget.roomStore;
    final aiStore = widget.aiStore;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header: Queue/Lyrics Segmented Pill + AI Search / Auto-fill / Clear buttons
          Watch((context) {
            final queueCount = roomStore.upcomingQueue.value.length;
            final lyricsReady =
                roomStore.lyricsFsm.status.value == EntityStatus.active;
            final activeTab = roomStore.activeTab.value;
            final autoQueue = aiStore.autoQueueFsm.activeData.value;
            final autoEnabled = autoQueue?.enabled ?? false;

            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 210,
                    maxWidth: 270,
                  ),
                  child: SlidingSegmentedPill<String>(
                    selectedValue: activeTab,
                    onSelected: (v) => roomStore.activeTab.value = v,
                    options: [
                      SlidingPillOption(
                        value: 'queue',
                        label: 'Up Next',
                        icon: Icons.queue_music_rounded,
                        badge: '$queueCount',
                      ),
                      SlidingPillOption(
                        value: 'lyrics',
                        label: 'Lyrics',
                        icon: Icons.lyrics_outlined,
                        showLiveDot: lyricsReady,
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // AI Search button
                    _HeaderActionChip(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Search',
                      color: AppThemeTokens.accentIndigo,
                      onTap: () => widget.onOpenAiModal('search'),
                    ),
                    // Auto-fill button
                    _HeaderActionChip(
                      icon: Icons.bolt_rounded,
                      label: autoEnabled ? 'Auto-fill ON' : 'Auto-fill',
                      color: autoEnabled
                          ? AppThemeTokens.accentPurple
                          : AppThemeTokens.textSecondary,
                      isHighlighted: autoEnabled,
                      onTap: () => widget.onOpenAiModal('auto'),
                    ),
                    // Clear Queue button
                    if (activeTab == 'queue' && queueCount > 0)
                      _HeaderActionChip(
                        icon: Icons.delete_sweep_rounded,
                        label: 'Clear',
                        color: AppThemeTokens.accentRose,
                        onTap: roomStore.clearQueue,
                      ),
                  ],
                ),
              ],
            );
          }),

          // Active Auto-Queue Vibe Banner
          Watch((context) {
            final autoCfg = aiStore.autoQueueFsm.activeData.value;
            if (autoCfg == null || !autoCfg.enabled) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemeTokens.accentPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppThemeTokens.accentPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppThemeTokens.accentPurple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Auto-Queue Active: "${autoCfg.prompt}" (+${autoCfg.count} songs when queue ends)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE9D5FF),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => widget.onOpenAiModal('auto'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppThemeTokens.accentPurple,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Add Single Song Input Bar + Dedicated Playlist Button
          Watch((context) {
            if (roomStore.activeTab.value != 'queue') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppThemeTokens.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppThemeTokens.borderSubtle),
                      ),
                      child: TextField(
                        controller: _songController,
                        onSubmitted: (_) => _submitSingleSong(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppThemeTokens.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Paste YouTube song URL or search title...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: AppThemeTokens.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppThemeTokens.textMuted,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: _submitSingleSong,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeTokens.accentGreen,
                        foregroundColor: AppThemeTokens.bgDeep,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenPlaylistModal,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppThemeTokens.accentEmerald,
                        side: BorderSide(
                          color: AppThemeTokens.accentEmerald
                              .withValues(alpha: 0.45),
                        ),
                        backgroundColor: AppThemeTokens.accentEmerald
                            .withValues(alpha: 0.10),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 18),
                      label: const Text(
                        'Playlist',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Main Content Area: Queue List or Synchronized Lyrics
          Expanded(
            child: Watch((context) {
              if (roomStore.activeTab.value == 'lyrics') {
                return _SynchronizedLyricsView(roomStore: roomStore);
              }
              return _PaginatedQueueView(roomStore: roomStore);
            }),
          ),
        ],
      ),
    );
  }
}

class _PaginatedQueueView extends StatelessWidget {
  final RoomStore roomStore;

  const _PaginatedQueueView({required this.roomStore});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final slice = roomStore.paginatedQueue.value;
      final totalItems = roomStore.upcomingQueue.value.length;
      final page = roomStore.currentPage.value;
      final pages = roomStore.totalPages.value;

      if (slice.isEmpty) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      size: 28,
                      color: AppThemeTokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Queue is Empty',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppThemeTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Paste a YouTube link above, import a playlist, or use AI Search to fill the room.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: slice.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final entry = slice[idx];
                final track = entry.track;
                final zeroBasedIndex = entry.originalIndex;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x12FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppThemeTokens.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      // Position number
                      SizedBox(
                        width: 26,
                        child: Text(
                          '#${zeroBasedIndex + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppThemeTokens.textMuted,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),

                      // Thumbnail with duration pill
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 36,
                          child: track.thumbnail != null &&
                                  track.thumbnail!.isNotEmpty
                              ? Image.network(
                                  track.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppThemeTokens.bgElevated,
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      size: 16,
                                      color: AppThemeTokens.textMuted,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppThemeTokens.bgElevated,
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    size: 16,
                                    color: AppThemeTokens.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Title, Artist, Requester
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppThemeTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    track.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppThemeTokens.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '• ${AppThemeTokens.formatDuration(track.duration)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppThemeTokens.textMuted,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // SkipTo & Remove Actions
                      IconButton(
                        onPressed: () =>
                            roomStore.skipToQueueIndex(zeroBasedIndex),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 20,
                          color: AppThemeTokens.accentGreen,
                        ),
                        tooltip: 'Play Now (Skip To)',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () =>
                            roomStore.removeQueueIndex(zeroBasedIndex),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: AppThemeTokens.textSecondary,
                        ),
                        tooltip: 'Remove from Queue',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Pagination Footer when > 10 tracks
          if (pages > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$totalItems tracks queued',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppThemeTokens.textMuted,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: page > 1
                          ? () => roomStore.currentPage.value = page - 1
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Page $page of $pages',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                    IconButton(
                      onPressed: page < pages
                          ? () => roomStore.currentPage.value = page + 1
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

class _SynchronizedLyricsView extends StatelessWidget {
  final RoomStore roomStore;

  const _SynchronizedLyricsView({required this.roomStore});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final status = roomStore.lyricsFsm.status.value;
      final lyrics = roomStore.lyricsFsm.activeData.value;
      final offset = roomStore.userOffset.value;

      if (status == EntityStatus.loading) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppThemeTokens.accentGreen),
              SizedBox(height: 12),
              Text(
                'Searching synchronized lyrics...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
            ],
          ),
        );
      }

      if (lyrics == null || lyrics.lines.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lyrics_outlined,
                  size: 40,
                  color: AppThemeTokens.textMuted,
                ),
                SizedBox(height: 10),
                Text(
                  'No Synchronized Lyrics Found',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppThemeTokens.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Lyrics will automatically appear here when a matching track plays.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final activeIdx = roomStore.activeLyricLineIndex.value;
      final effectivePos = roomStore.position.value - offset;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Click-to-Sync & Timing Offset Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0x4D000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppThemeTokens.borderSubtle),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 14,
                      color: AppThemeTokens.accentGreen,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Tap any line to sync • ${lyrics.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _OffsetStepButton(
                      label: '-0.5s',
                      onTap: () => roomStore.adjustOffset(-0.5),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${offset >= 0 ? "+" : ""}${offset.toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: offset == 0
                              ? AppThemeTokens.textSecondary
                              : AppThemeTokens.accentGreen,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    _OffsetStepButton(
                      label: '+0.5s',
                      onTap: () => roomStore.adjustOffset(0.5),
                    ),
                    if (offset != 0) ...[
                      const SizedBox(width: 6),
                      _OffsetStepButton(
                        label: 'Reset',
                        onTap: roomStore.resetOffset,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Lyric Lines List
          Expanded(
            child: ListView.builder(
              itemCount: lyrics.lines.length,
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemBuilder: (context, index) {
                final line = lyrics.lines[index];
                final isActive = index == activeIdx;
                final isPast = index < activeIdx;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => roomStore.syncToLine(line.time),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppThemeTokens.accentGreen.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isActive
                          ? Border.all(
                              color: AppThemeTokens.accentGreen
                                  .withValues(alpha: 0.35),
                            )
                          : null,
                    ),
                    child: _buildLyricLineContent(
                      line: line,
                      isActive: isActive,
                      isPast: isPast,
                      effectivePos: effectivePos,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildLyricLineContent({
    required LyricLine line,
    required bool isActive,
    required bool isPast,
    required double effectivePos,
  }) {
    if (isActive && line.words != null && line.words!.isNotEmpty) {
      return Wrap(
        spacing: 4,
        runSpacing: 2,
        children: [
          for (final w in line.words!)
            Text(
              w.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: effectivePos >= w.time
                    ? AppThemeTokens.accentGreen
                    : AppThemeTokens.textPrimary.withValues(alpha: 0.55),
              ),
            ),
        ],
      );
    }

    return Text(
      line.text,
      style: TextStyle(
        fontSize: isActive ? 16 : 14,
        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
        color: isActive
            ? AppThemeTokens.accentGreen
            : isPast
                ? AppThemeTokens.textMuted
                : AppThemeTokens.textSecondary,
      ),
    );
  }
}

class _HeaderActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _HeaderActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isHighlighted ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: isHighlighted ? 0.55 : 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffsetStepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OffsetStepButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppThemeTokens.textPrimary,
          ),
        ),
      ),
    );
  }
}
