import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../components/ai_assistant_modal.dart';
import '../components/connection_dialogs.dart';
import '../components/glass_panel.dart';
import '../components/musicbot_logo.dart';
import '../components/patch_notes_modal.dart';
import '../components/player_panel.dart';
import '../components/playlist_modal.dart';
import '../components/queue_lyrics_panel.dart';
import '../components/schedule_view.dart';
import '../components/sliding_segmented_pill.dart';
import '../models/music_models.dart';
import '../stores/ai_store.dart';
import '../stores/auth_store.dart';
import '../stores/patch_notes_store.dart';
import '../stores/room_store.dart';
import '../stores/schedule_store.dart';

/// Root Listening Room & Server Schedule Page.
/// Strictly a StatelessWidget with ZERO `setState` at the page root
/// (honoring MOBILE_TECHSTACK.md Section 3 & VIBE_CODING_RULES.md).
class HomePage extends StatelessWidget {
  final AuthStore authStore;
  final RoomStore roomStore;
  final AiStore aiStore;
  final ScheduleStore scheduleStore;
  final PatchNotesStore patchNotesStore;

  const HomePage({
    super.key,
    required this.authStore,
    required this.roomStore,
    required this.aiStore,
    required this.scheduleStore,
    required this.patchNotesStore,
  });

  void _openPlaylistModal(BuildContext context) {
    roomStore.resetPlaylistPreview();
    showDialog<void>(
      context: context,
      builder: (_) => PlaylistModal(roomStore: roomStore),
    );
  }

  void _openAiModal(BuildContext context, String initialTab) {
    aiStore.activeModalTab.value = initialTab;
    showDialog<void>(
      context: context,
      builder: (_) => AiAssistantModal(
        aiStore: aiStore,
        roomStore: roomStore,
      ),
    );
  }

  void _openPatchNotesModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => PatchNotesModal(patchNotesStore: patchNotesStore),
    );
  }

  void _openConnectionGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ConnectionGuideDialog(onSummonBot: roomStore.summonBot),
    );
  }

  void _openContributeDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ContributeDialog(
        onOpenKeyPool: () => _openAiModal(context, 'keys'),
      ),
    );
  }

  void _openAuthDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AuthConfigDialog(
        authStore: authStore,
        onAuthenticated: () {
          roomStore.startSessionPolling();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeTokens.bgDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Dynamic Ambient Artwork Blur Background (isolated in RepaintBoundary)
          RepaintBoundary(
            child: Watch((context) {
              final thumb = roomStore.currentTrack.value?.thumbnail;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb != null && thumb.isNotEmpty)
                    Image.network(
                      thumb,
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
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xD80B1014),
                            Color(0xF20B1014),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),

          // 2. Main SafeArea Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation & Status Bar
                  _TopNavigationHeader(
                    authStore: authStore,
                    roomStore: roomStore,
                    scheduleStore: scheduleStore,
                    patchNotesStore: patchNotesStore,
                    onOpenPatchNotes: () => _openPatchNotesModal(context),
                    onOpenContribute: () => _openContributeDialog(context),
                    onOpenAuth: () => _openAuthDialog(context),
                  ),

                  // Notice Banner
                  Watch((context) {
                    final msg = roomStore.notice.value;
                    if (msg == null || msg.isEmpty) {
                      return const SizedBox(height: 10);
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppThemeTokens.accentGreen.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppThemeTokens.accentGreen
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppThemeTokens.accentGreen,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              msg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppThemeTokens.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Workspace Area: Listening Room vs Server Schedule
                  Expanded(
                    child: Watch((context) {
                      final currentView = roomStore.roomView.value;
                      final userId =
                          authStore.authFsm.activeData.value?.id ?? '';

                      if (currentView == 'schedule') {
                        return ScheduleView(
                          scheduleStore: scheduleStore,
                          roomStore: roomStore,
                          currentUserId: userId,
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 820 &&
                              constraints.maxHeight >= 460;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: (constraints.maxWidth * 0.38)
                                      .clamp(310.0, 400.0),
                                  child: SingleChildScrollView(
                                    child: PlayerPanel(
                                      roomStore: roomStore,
                                      onOpenConnectionGuide: () =>
                                          _openConnectionGuide(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: QueueLyricsPanel(
                                    roomStore: roomStore,
                                    aiStore: aiStore,
                                    onOpenPlaylistModal: () =>
                                        _openPlaylistModal(context),
                                    onOpenAiModal: (tab) =>
                                        _openAiModal(context, tab),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Compact / Portrait / Short Landscape Adaptive Scrollable Layout
                          final queueHeight =
                              (constraints.maxHeight * 0.65).clamp(320.0, 520.0);
                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PlayerPanel(
                                  roomStore: roomStore,
                                  onOpenConnectionGuide: () =>
                                      _openConnectionGuide(context),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: queueHeight,
                                  child: QueueLyricsPanel(
                                    roomStore: roomStore,
                                    aiStore: aiStore,
                                    onOpenPlaylistModal: () =>
                                        _openPlaylistModal(context),
                                    onOpenAiModal: (tab) =>
                                        _openAiModal(context, tab),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavigationHeader extends StatelessWidget {
  final AuthStore authStore;
  final RoomStore roomStore;
  final ScheduleStore scheduleStore;
  final PatchNotesStore patchNotesStore;
  final VoidCallback onOpenPatchNotes;
  final VoidCallback onOpenContribute;
  final VoidCallback onOpenAuth;

  const _TopNavigationHeader({
    required this.authStore,
    required this.roomStore,
    required this.scheduleStore,
    required this.patchNotesStore,
    required this.onOpenPatchNotes,
    required this.onOpenContribute,
    required this.onOpenAuth,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 18,
      child: Watch((context) {
        final guilds = roomStore.guilds.value;
        final gid = roomStore.currentGuildId.value;
        final view = roomStore.roomView.value;
        final user = authStore.authFsm.activeData.value;
        final unreadNotes = patchNotesStore.unreadCount.value;
        final pendingInvites =
            scheduleStore.countPendingForUser(user?.id ?? '');

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            // Brand + Guild Dropdown
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                const MusicBotBrandWordmark(
                  iconSize: 28,
                  fontSize: 16,
                ),
                if (guilds.isNotEmpty)
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppThemeTokens.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppThemeTokens.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: guilds.any((g) => g.guildId == gid)
                            ? gid
                            : guilds.first.guildId,
                        dropdownColor: AppThemeTokens.bgElevated,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppThemeTokens.textPrimary,
                        ),
                        items: [
                          for (final GuildSession g in guilds)
                            DropdownMenuItem(
                              value: g.guildId,
                              child: Text(g.guildName),
                            ),
                        ],
                        onChanged: (nextId) {
                          if (nextId != null) {
                            roomStore.selectGuild(nextId);
                            scheduleStore.fetchSchedule(nextId);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),

            // Room vs Schedule Sliding Pill
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 195, maxWidth: 235),
              child: SlidingSegmentedPill<String>(
                selectedValue: view,
                height: 34,
                onSelected: (next) {
                  roomStore.roomView.value = next;
                  if (next == 'schedule' && gid != null) {
                    scheduleStore.fetchSchedule(gid);
                  }
                },
                options: [
                  const SlidingPillOption(
                    value: 'room',
                    label: 'Room',
                    icon: Icons.headphones_rounded,
                  ),
                  SlidingPillOption(
                    value: 'schedule',
                    label: 'Schedule',
                    icon: Icons.calendar_today_rounded,
                    badge: pendingInvites > 0 ? '$pendingInvites' : null,
                  ),
                ],
              ),
            ),

            // Action Buttons (Summon, Release Notes, Contribute, Account)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Summon Bot
                _NavPillButton(
                  icon: Icons.bolt_rounded,
                  label: 'Summon',
                  color: AppThemeTokens.accentGreen,
                  onTap: roomStore.summonBot,
                ),

                // Release Notes with Unread Badge
                _NavPillButton(
                  icon: Icons.new_releases_outlined,
                  label: unreadNotes > 0 ? 'Notes ($unreadNotes)' : 'Notes',
                  color: unreadNotes > 0
                      ? AppThemeTokens.accentEmerald
                      : AppThemeTokens.textSecondary,
                  onTap: onOpenPatchNotes,
                ),

                // Contribute
                _NavPillButton(
                  icon: Icons.favorite_border_rounded,
                  label: 'Contribute',
                  color: AppThemeTokens.accentRose,
                  onTap: onOpenContribute,
                ),

                // Auth / Profile
                _NavPillButton(
                  icon: user != null
                      ? Icons.verified_user_outlined
                      : Icons.login_rounded,
                  label: user?.username ?? 'Connect',
                  color: user != null
                      ? AppThemeTokens.accentSky
                      : AppThemeTokens.textPrimary,
                  onTap: onOpenAuth,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _NavPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NavPillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
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
