import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../core/utils/youtube_utils.dart';
import '../models/state_machine_dto.dart';
import '../stores/room_store.dart';
import 'glass_panel.dart';

/// YouTube Playlist Preview & Range Import Modal matching MusicBotUI's PlaylistModal.tsx.
class PlaylistModal extends StatefulWidget {
  final RoomStore roomStore;

  const PlaylistModal({
    super.key,
    required this.roomStore,
  });

  @override
  State<PlaylistModal> createState() => _PlaylistModalState();
}

class _PlaylistModalState extends State<PlaylistModal> {
  final TextEditingController _urlController = TextEditingController();
  final Signal<int> _startIndex = signal(1);
  final Signal<int> _endIndex = signal(1);
  final Signal<String?> _localError = signal(null);

  @override
  void dispose() {
    _urlController.dispose();
    _startIndex.dispose();
    _endIndex.dispose();
    _localError.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return;
    if (!YouTubeUtils.isYouTubePlaylistUrl(raw)) {
      _localError.value =
          'Please paste a valid YouTube playlist URL containing a "list=" parameter.';
      return;
    }
    _localError.value = null;
    final preview = await widget.roomStore.previewPlaylist(raw);
    if (preview != null) {
      _startIndex.value = 1;
      _endIndex.value = preview.totalCount.clamp(1, 50);
    }
  }

  Future<void> _confirmImport() async {
    final preview = widget.roomStore.playlistFsm.activeData.value;
    if (preview == null) return;
    final start = _startIndex.value.clamp(1, preview.totalCount);
    final end = _endIndex.value.clamp(start, preview.totalCount);
    final selected = preview.tracks
        .where((t) => t.index >= start && t.index <= end)
        .toList();
    final ok = await widget.roomStore.importPlaylistSelection(
      title: preview.title,
      startIndex: start,
      endIndex: end,
      selectedTracks: selected,
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomStore = widget.roomStore;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
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
                          AppThemeTokens.accentEmerald.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppThemeTokens.accentEmerald
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_rounded,
                      color: AppThemeTokens.accentEmerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import YouTube Playlist',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppThemeTokens.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Preview tracks and choose a range to queue',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppThemeTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      roomStore.resetPlaylistPreview();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Body
              Flexible(
                child: Watch((context) {
                  final status = roomStore.playlistFsm.status.value;
                  final preview = roomStore.playlistFsm.activeData.value;
                  final err = _localError.value ??
                      roomStore.playlistFsm.errorMessage.value;
                  final start = _startIndex.value;
                  final end = _endIndex.value;

                  if (preview == null) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PLAYLIST URL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppThemeTokens.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _urlController,
                                  onSubmitted: (_) => _fetchPreview(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppThemeTokens.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText:
                                        'https://www.youtube.com/playlist?list=...',
                                    hintStyle: const TextStyle(
                                      fontSize: 12,
                                      color: AppThemeTokens.textMuted,
                                    ),
                                    filled: true,
                                    fillColor: AppThemeTokens.bgInput,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppThemeTokens.borderSubtle,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: status == EntityStatus.loading
                                    ? null
                                    : _fetchPreview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppThemeTokens.accentEmerald,
                                  foregroundColor: AppThemeTokens.bgDeep,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  status == EntityStatus.loading
                                      ? 'Loading...'
                                      : 'Preview',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (err != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppThemeTokens.accentRose
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppThemeTokens.accentRose
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                err,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFFECDD3),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0x0FFFFFFF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppThemeTokens.borderSubtle,
                              ),
                            ),
                            child: const Text(
                              'Tip: Paste any YouTube playlist link or video link with a ?list= parameter. We will automatically extract the playlist and let you select which tracks to import.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppThemeTokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final validStart = start.clamp(1, preview.totalCount);
                  final validEnd = end.clamp(validStart, preview.totalCount);
                  final selectedCount = validEnd - validStart + 1;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Playlist summary bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x14FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: AppThemeTokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preview.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppThemeTokens.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${preview.totalCount} tracks available • Importing #$validStart to #$validEnd ($selectedCount songs)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppThemeTokens.accentEmerald,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: roomStore.resetPlaylistPreview,
                              child: const Text(
                                'Change URL',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppThemeTokens.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Range presets & controls
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _PresetButton(
                            label: 'All (${preview.totalCount})',
                            onTap: () {
                              _startIndex.value = 1;
                              _endIndex.value = preview.totalCount;
                            },
                          ),
                          for (final count in [10, 25, 50])
                            if (preview.totalCount > count)
                              _PresetButton(
                                label: 'First $count',
                                onTap: () {
                                  _startIndex.value = 1;
                                  _endIndex.value = count;
                                },
                              ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Track list preview
                      Expanded(
                        child: ListView.separated(
                          itemCount: preview.tracks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final track = preview.tracks[idx];
                            final inRange = track.index >= validStart &&
                                track.index <= validEnd;

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                if (track.index < validStart) {
                                  _startIndex.value = track.index;
                                } else {
                                  _endIndex.value = track.index;
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: inRange
                                      ? AppThemeTokens.accentEmerald
                                          .withValues(alpha: 0.12)
                                      : const Color(0x0DFFFFFF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: inRange
                                        ? AppThemeTokens.accentEmerald
                                            .withValues(alpha: 0.35)
                                        : AppThemeTokens.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '#${track.index}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: inRange
                                              ? AppThemeTokens.accentEmerald
                                              : AppThemeTokens.textMuted,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppThemeTokens.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '${track.artist} • ${AppThemeTokens.formatDuration(track.duration)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppThemeTokens.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (inRange)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppThemeTokens.accentEmerald
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'IN RANGE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: AppThemeTokens.accentEmerald,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Confirm Import Button
                      ElevatedButton.icon(
                        onPressed: status == EntityStatus.loading
                            ? null
                            : _confirmImport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeTokens.accentEmerald,
                          foregroundColor: AppThemeTokens.bgDeep,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          status == EntityStatus.loading
                              ? 'Importing...'
                              : 'Import $selectedCount Songs (#$validStart - #$validEnd)',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0x18FFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppThemeTokens.borderSubtle),
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
