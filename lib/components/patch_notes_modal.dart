import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import '../models/music_models.dart';
import '../stores/patch_notes_store.dart';
import 'glass_panel.dart';

/// Release Notes Modal matching MusicBotUI's PatchNotesModal.tsx.
class PatchNotesModal extends StatelessWidget {
  final PatchNotesStore patchNotesStore;

  const PatchNotesModal({
    super.key,
    required this.patchNotesStore,
  });

  @override
  Widget build(BuildContext context) {
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
              Watch((context) {
                final unread = patchNotesStore.unreadCount.value;
                return Row(
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
                        Icons.auto_awesome_rounded,
                        color: AppThemeTokens.accentEmerald,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Release Notes',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppThemeTokens.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: unread > 0
                                      ? AppThemeTokens.accentEmerald
                                          .withValues(alpha: 0.16)
                                      : const Color(0x18FFFFFF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  unread > 0
                                      ? '$unread unread'
                                      : 'All caught up',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: unread > 0
                                        ? AppThemeTokens.accentEmerald
                                        : AppThemeTokens.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "What's new in Music Bot",
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
                );
              }),

              const SizedBox(height: 10),

              // Mark all read/unread bar
              Watch((context) {
                final unread = patchNotesStore.unreadCount.value;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (unread > 0)
                      TextButton.icon(
                        onPressed: patchNotesStore.markAllAsRead,
                        icon: const Icon(
                          Icons.done_all_rounded,
                          size: 15,
                          color: AppThemeTokens.accentEmerald,
                        ),
                        label: const Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppThemeTokens.accentEmerald,
                          ),
                        ),
                      ),
                    if (unread < kPatchNotes.length)
                      TextButton.icon(
                        onPressed: patchNotesStore.markAllAsUnread,
                        icon: const Icon(
                          Icons.mark_email_unread_outlined,
                          size: 15,
                          color: AppThemeTokens.textSecondary,
                        ),
                        label: const Text(
                          'Mark all unread',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppThemeTokens.textSecondary,
                          ),
                        ),
                      ),
                  ],
                );
              }),

              const SizedBox(height: 8),

              // Release notes cards
              Flexible(
                child: Watch((context) {
                  final readSet = patchNotesStore.readVersions.value;
                  return ListView.separated(
                    itemCount: kPatchNotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final note = kPatchNotes[idx];
                      final isRead = readSet.contains(note.version);
                      final isLatest = idx == 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: !isRead
                              ? AppThemeTokens.accentEmerald
                                  .withValues(alpha: 0.08)
                              : const Color(0x12FFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: !isRead
                                ? AppThemeTokens.accentEmerald
                                    .withValues(alpha: 0.35)
                                : AppThemeTokens.borderSubtle,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLatest
                                        ? AppThemeTokens.accentEmerald
                                        : const Color(0x24FFFFFF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'v${note.version}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isLatest
                                          ? AppThemeTokens.bgDeep
                                          : AppThemeTokens.textPrimary,
                                    ),
                                  ),
                                ),
                                if (!isRead)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppThemeTokens.accentEmerald
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppThemeTokens.accentEmerald,
                                      ),
                                    ),
                                  ),
                                Text(
                                  note.date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppThemeTokens.textMuted,
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () =>
                                      patchNotesStore.toggleRead(note.version),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      isRead ? 'Read' : 'Mark read',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isRead
                                            ? AppThemeTokens.textSecondary
                                            : AppThemeTokens.accentEmerald,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppThemeTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            for (final h in note.highlights)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: Icon(
                                        Icons.circle,
                                        size: 5,
                                        color: AppThemeTokens.accentEmerald,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        h,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppThemeTokens.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
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
    );
  }
}
