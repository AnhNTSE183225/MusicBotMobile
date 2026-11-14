import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../models/state_machine_dto.dart';
import '../stores/room_store.dart';
import 'glass_panel.dart';
import 'musicbot_logo.dart';
import 'status_badge.dart';

/// Left/Top Playback Deck matching MusicBotUI's PlayerPanel.
/// Zero `setState` at page roots; uses leaf `Watch` widgets for 100ms progress ticks.
class PlayerPanel extends StatelessWidget {
  final RoomStore roomStore;
  final VoidCallback onOpenConnectionGuide;

  const PlayerPanel({
    super.key,
    required this.roomStore,
    required this.onOpenConnectionGuide,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Now Playing + StatusBadge
          Row(
            children: [
              const Icon(
                Icons.album_outlined,
                size: 16,
                color: AppThemeTokens.accentGreen,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'NOW PLAYING',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: AppThemeTokens.textSecondary,
                  ),
                ),
              ),
              StatusBadge(statusSignal: roomStore.playbackFsm.status),
            ],
          ),
          const SizedBox(height: 14),

          // Artwork & Metadata
          Watch((context) {
            final track = roomStore.currentTrack.value;
            final status = roomStore.playbackFsm.status.value;
            final hasTrack = track != null &&
                (status == EntityStatus.active ||
                    status == EntityStatus.paused);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Artwork container
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 220,
                      maxHeight: 220,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: AppThemeTokens.borderStrong),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 24,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (hasTrack &&
                                track.thumbnail != null &&
                                track.thumbnail!.isNotEmpty)
                              Image.network(
                                track.thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/coastline.jpg',
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Image.asset(
                                'assets/coastline.jpg',
                                fit: BoxFit.cover,
                              ),
                            if (!hasTrack)
                              Container(
                                color: const Color(0x880B1014),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  size: 46,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Track Title & Artist
                Text(
                  hasTrack ? track.title : 'Ready to Play',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppThemeTokens.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasTrack
                      ? track.artist
                      : 'Summon the bot & add a song or playlist to start',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppThemeTokens.textSecondary,
                  ),
                ),

                // Requester Badge
                if (hasTrack &&
                    track.requester != null &&
                    track.requester!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _RequesterPill(
                    requester: track.requester!,
                    avatarUrl: track.requesterAvatar,
                  ),
                ],
              ],
            );
          }),

          const SizedBox(height: 16),

          // Clamped Progress Bar & Tabular Timestamps (Leaf Watch for 100ms ticks)
          RepaintBoundary(
            child: Watch((context) {
              final track = roomStore.currentTrack.value;
              final pos = roomStore.position.value;
              final duration = (track?.duration ?? 0).toDouble();
              final progress = duration > 0
                  ? (pos / duration).clamp(0.0, 1.0)
                  : 0.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: const Color(0x22FFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppThemeTokens.accentGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppThemeTokens.formatDuration(
                          duration > 0 ? pos.clamp(0, duration) : 0,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppThemeTokens.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        AppThemeTokens.formatDuration(duration),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppThemeTokens.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 14),

          // Playback Transport Controls + Vote Badges
          Watch((context) {
            final snapshot = roomStore.playbackFsm.activeData.value;
            final status = roomStore.playbackFsm.status.value;
            final hasCurrent = snapshot?.current != null;
            final isLoop = snapshot?.loop ?? false;
            final pauseVotes = snapshot?.pauseVotes ?? 0;
            final pauseReq = snapshot?.pauseVotesReq ?? 1;
            final skipVotes = snapshot?.skipVotes ?? 0;
            final skipReq = snapshot?.skipVotesReq ?? 1;

            return Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                // Loop toggle
                _TransportIconButton(
                  icon: Icons.repeat_rounded,
                  tooltip: isLoop ? 'Loop Enabled' : 'Enable Loop',
                  isActive: isLoop,
                  enabled: hasCurrent,
                  onPressed: roomStore.toggleLoop,
                ),

                // Play / Pause main button with vote badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: hasCurrent
                          ? AppThemeTokens.textPrimary
                          : const Color(0x22FFFFFF),
                      shape: const CircleBorder(),
                      elevation: hasCurrent ? 6 : 0,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: hasCurrent ? roomStore.togglePlayPause : null,
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: Icon(
                            status == EntityStatus.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            size: 28,
                            color: hasCurrent
                                ? AppThemeTokens.bgDeep
                                : AppThemeTokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                    if (pauseVotes > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: _VoteBadge(
                          text: '$pauseVotes/$pauseReq',
                          color: AppThemeTokens.accentEmerald,
                        ),
                      ),
                  ],
                ),

                // Skip button with vote badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _TransportIconButton(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Skip Track',
                      enabled: hasCurrent,
                      onPressed: roomStore.skipTrack,
                    ),
                    if (skipVotes > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: _VoteBadge(
                          text: '$skipVotes/$skipReq',
                          color: AppThemeTokens.accentGreen,
                        ),
                      ),
                  ],
                ),

                // Stop / Summon shortcut
                _TransportIconButton(
                  icon: Icons.stop_rounded,
                  tooltip: 'Stop & Clear',
                  enabled: hasCurrent,
                  danger: true,
                  onPressed: roomStore.stopBot,
                ),
              ],
            );
          }),

          const SizedBox(height: 14),

          // Volume Slider (0% - 200%)
          Watch((context) {
            final vol =
                (roomStore.playbackFsm.activeData.value?.volume ?? 100)
                    .clamp(0, 200);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x4D000000),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppThemeTokens.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(
                    vol == 0
                        ? Icons.volume_off_rounded
                        : vol < 80
                            ? Icons.volume_down_rounded
                            : Icons.volume_up_rounded,
                    size: 18,
                    color: AppThemeTokens.textSecondary,
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: AppThemeTokens.accentGreen,
                        inactiveTrackColor: const Color(0x28FFFFFF),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: vol.toDouble(),
                        min: 0,
                        max: 200,
                        onChanged: (v) => roomStore.setVolume(v.round()),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '$vol%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppThemeTokens.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Active Server & Voice Footer
          Watch((context) {
            final guild = roomStore.currentGuild.value;
            final inVoice = guild?.inVoice ?? false;
            return Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: inVoice
                        ? AppThemeTokens.accentGreen
                        : AppThemeTokens.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guild != null
                        ? '${guild.guildName}${guild.channelName != null ? " • #${guild.channelName}" : ""}'
                        : 'No Discord voice session active',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onOpenConnectionGuide,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.help_outline_rounded,
                    size: 13,
                    color: AppThemeTokens.accentGreen,
                  ),
                  label: const Text(
                    'Guide',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppThemeTokens.accentGreen,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _RequesterPill extends StatelessWidget {
  final String requester;
  final String? avatarUrl;

  const _RequesterPill({
    required this.requester,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = requester == 'AI Auto-Queue';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAi
            ? AppThemeTokens.accentPurple.withValues(alpha: 0.14)
            : const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isAi
              ? AppThemeTokens.accentPurple.withValues(alpha: 0.35)
              : AppThemeTokens.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAi)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: MusicBotLogoIcon(size: 14),
            )
          else if (avatarUrl != null && avatarUrl!.isNotEmpty)
            ClipOval(
              child: Image.network(
                avatarUrl!,
                width: 15,
                height: 15,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  size: 13,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
            )
          else
            const Icon(
              Icons.person_rounded,
              size: 13,
              color: AppThemeTokens.textSecondary,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isAi ? 'Picked by AI Auto-Queue' : 'Added by $requester',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isAi
                    ? const Color(0xFFD8B4FE)
                    : AppThemeTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final bool isActive;
  final bool danger;
  final VoidCallback onPressed;

  const _TransportIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    this.isActive = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = !enabled
        ? AppThemeTokens.textMuted
        : danger
            ? AppThemeTokens.accentRose
            : isActive
                ? AppThemeTokens.accentGreen
                : AppThemeTokens.textPrimary;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppThemeTokens.accentGreen.withValues(alpha: 0.16)
                : const Color(0x14FFFFFF),
            border: Border.all(
              color: isActive
                  ? AppThemeTokens.accentGreen.withValues(alpha: 0.45)
                  : AppThemeTokens.borderSubtle,
            ),
          ),
          child: Icon(icon, size: 20, color: fgColor),
        ),
      ),
    );
  }
}

class _VoteBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _VoteBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 4),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppThemeTokens.bgDeep,
        ),
      ),
    );
  }
}
