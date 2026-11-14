import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/utils/schedule_utils.dart';
import '../models/music_models.dart';
import '../models/schedule_models.dart';
import '../models/state_machine_dto.dart';
import '../stores/room_store.dart';
import '../stores/schedule_store.dart';
import 'glass_panel.dart';
import 'sliding_segmented_pill.dart';

/// Server Schedule & Calendar View matching MusicBotUI's ScheduleView.tsx.
class ScheduleView extends StatelessWidget {
  final ScheduleStore scheduleStore;
  final RoomStore roomStore;
  final String currentUserId;

  const ScheduleView({
    super.key,
    required this.scheduleStore,
    required this.roomStore,
    required this.currentUserId,
  });

  static final DateFormat _monthYearFmt = DateFormat('MMMM yyyy');
  static final DateFormat _dayFmt = DateFormat('EEE, MMM d');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  void _openEditor(BuildContext context, {ScheduleEvent? existing}) {
    showDialog<void>(
      context: context,
      builder: (_) => _ScheduleEventEditorDialog(
        scheduleStore: scheduleStore,
        roomStore: roomStore,
        existing: existing,
      ),
    );
  }

  void _openDetails(BuildContext context, ScheduleOccurrence occ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ScheduleEventDetailsDialog(
        occurrence: occ,
        scheduleStore: scheduleStore,
        roomStore: roomStore,
        currentUserId: currentUserId,
        onEdit: (event) {
          Navigator.of(context).pop();
          _openEditor(context, existing: event);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Toolbar: Server Selector + View Switcher + Filter Pills + Create Button
          Watch((context) {
            final guilds = roomStore.guilds.value;
            final gid = roomStore.currentGuildId.value;
            final mode = scheduleStore.viewMode.value;
            final filter = scheduleStore.filterMode.value;
            final cur = scheduleStore.cursorDate.value;
            final pendingCount =
                scheduleStore.countPendingForUser(currentUserId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Title + Server Selector
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                              color: AppThemeTokens.accentGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _monthYearFmt.format(cur),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppThemeTokens.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (guilds.isNotEmpty)
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppThemeTokens.bgInput,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppThemeTokens.borderSubtle,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: guilds.any((g) => g.guildId == gid)
                                    ? gid
                                    : guilds.first.guildId,
                                dropdownColor: AppThemeTokens.bgElevated,
                                style: const TextStyle(
                                  fontSize: 12,
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

                    // Navigation & Create Event
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => scheduleStore.stepCursor(-1),
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Previous',
                        ),
                        OutlinedButton(
                          onPressed: scheduleStore.goToday,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeTokens.textPrimary,
                            side: const BorderSide(
                              color: AppThemeTokens.borderSubtle,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: const Text(
                            'Today',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => scheduleStore.stepCursor(1),
                          icon:
                              const Icon(Icons.chevron_right_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Next',
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openEditor(context),
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
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'New Event',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // View Mode Switcher & Filter Chips
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 230,
                        maxWidth: 290,
                      ),
                      child: SlidingSegmentedPill<CalendarViewMode>(
                        selectedValue: mode,
                        onSelected: (m) => scheduleStore.viewMode.value = m,
                        height: 34,
                        options: const [
                          SlidingPillOption(
                            value: CalendarViewMode.agenda,
                            label: 'Agenda',
                            icon: Icons.view_agenda_outlined,
                          ),
                          SlidingPillOption(
                            value: CalendarViewMode.month,
                            label: 'Month',
                            icon: Icons.calendar_view_month_rounded,
                          ),
                          SlidingPillOption(
                            value: CalendarViewMode.week,
                            label: 'Week',
                            icon: Icons.view_week_outlined,
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _FilterChipButton(
                          label: 'All',
                          selected: filter == ScheduleFilterMode.all,
                          onTap: () => scheduleStore.filterMode.value =
                              ScheduleFilterMode.all,
                        ),
                        _FilterChipButton(
                          label: 'Invited',
                          selected: filter == ScheduleFilterMode.invited,
                          onTap: () => scheduleStore.filterMode.value =
                              ScheduleFilterMode.invited,
                        ),
                        _FilterChipButton(
                          label: pendingCount > 0
                              ? 'Pending ($pendingCount)'
                              : 'Pending',
                          selected: filter == ScheduleFilterMode.pending,
                          onTap: () => scheduleStore.filterMode.value =
                              ScheduleFilterMode.pending,
                        ),
                        _FilterChipButton(
                          label: 'My Events',
                          selected: filter == ScheduleFilterMode.mine,
                          onTap: () => scheduleStore.filterMode.value =
                              ScheduleFilterMode.mine,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }),

          const SizedBox(height: 14),

          // Main Calendar Area
          Expanded(
            child: Watch((context) {
              final status = scheduleStore.scheduleFsm.status.value;
              final mode = scheduleStore.viewMode.value;
              final occurrences =
                  scheduleStore.visibleOccurrencesForUser(currentUserId);
              final members = scheduleStore.members.value;

              if (status == EntityStatus.loading && occurrences.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppThemeTokens.accentGreen,
                  ),
                );
              }

              if (mode == CalendarViewMode.month) {
                return _buildMonthView(context, occurrences, members);
              }
              if (mode == CalendarViewMode.week) {
                return _buildWeekView(context, occurrences, members);
              }
              return _buildAgendaView(context, occurrences, members);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaView(
    BuildContext context,
    List<ScheduleOccurrence> occurrences,
    List<ServerMember> members,
  ) {
    if (occurrences.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 42,
                color: AppThemeTokens.textMuted,
              ),
              const SizedBox(height: 10),
              const Text(
                'No Upcoming Events',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppThemeTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create a listening party, gaming night, or hangout for your Discord server.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _openEditor(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeTokens.accentGreen,
                  foregroundColor: AppThemeTokens.bgDeep,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Create First Event',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Balanced Adaptive Card Grid per MOBILE_TECHSTACK.md Section 11.1
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = constraints.maxWidth;
        final cols = width >= 900 ? 3 : (width >= 580 ? 2 : 1);
        final cardWidth = (width - spacing * (cols - 1)) / cols;

        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final occ in occurrences)
                SizedBox(
                  width: cardWidth,
                  child: _OccurrenceCard(
                    occurrence: occ,
                    members: members,
                    currentUserId: currentUserId,
                    dayLabel: _dayFmt.format(occ.start),
                    timeLabel:
                        '${_timeFmt.format(occ.start)} – ${_timeFmt.format(occ.end)}',
                    onTap: () => _openDetails(context, occ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthView(
    BuildContext context,
    List<ScheduleOccurrence> occurrences,
    List<ServerMember> members,
  ) {
    final cur = scheduleStore.cursorDate.value;
    final firstOfMonth = DateTime(cur.year, cur.month, 1);
    final gridStart =
        firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
    final selectedDay = ScheduleUtils.startOfDay(cur);
    final dayOccurrences = occurrences
        .where((o) => ScheduleUtils.isOccurrenceOnDay(o, selectedDay))
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekday Header
          Row(
            children: [
              for (final wd in ScheduleUtils.weekdayShort)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        wd,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppThemeTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // 6 weeks x 7 days compact grid
          for (var week = 0; week < 6; week++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final cellDate =
                              gridStart.add(Duration(days: week * 7 + d));
                          final inMonth = cellDate.month == cur.month;
                          final isSelected =
                              cellDate.year == selectedDay.year &&
                                  cellDate.month == selectedDay.month &&
                                  cellDate.day == selectedDay.day;
                          final count = occurrences
                              .where(
                                (o) => ScheduleUtils.isOccurrenceOnDay(
                                  o,
                                  cellDate,
                                ),
                              )
                              .length;

                          return GestureDetector(
                            onTap: () =>
                                scheduleStore.cursorDate.value = cellDate,
                            child: Container(
                              height: 42,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppThemeTokens.accentGreen
                                        .withValues(alpha: 0.18)
                                    : const Color(0x0DFFFFFF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppThemeTokens.accentGreen
                                      : AppThemeTokens.borderSubtle,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${cellDate.day}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: inMonth
                                          ? AppThemeTokens.textPrimary
                                          : AppThemeTokens.textMuted,
                                    ),
                                  ),
                                  if (count > 0)
                                    Container(
                                      margin: const EdgeInsets.only(top: 2),
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppThemeTokens.accentGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Text(
            'Events on ${_dayFmt.format(selectedDay)} (${dayOccurrences.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppThemeTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (dayOccurrences.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No events scheduled for this day.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppThemeTokens.textMuted,
                ),
              ),
            )
          else
            for (final occ in dayOccurrences)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OccurrenceCard(
                  occurrence: occ,
                  members: members,
                  currentUserId: currentUserId,
                  dayLabel: _dayFmt.format(occ.start),
                  timeLabel:
                      '${_timeFmt.format(occ.start)} – ${_timeFmt.format(occ.end)}',
                  onTap: () => _openDetails(context, occ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildWeekView(
    BuildContext context,
    List<ScheduleOccurrence> occurrences,
    List<ServerMember> members,
  ) {
    final cur = scheduleStore.cursorDate.value;
    final weekStart =
        ScheduleUtils.startOfDay(cur).subtract(Duration(days: cur.weekday % 7));

    return ListView.separated(
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final day = weekStart.add(Duration(days: idx));
        final dayList = occurrences
            .where((o) => ScheduleUtils.isOccurrenceOnDay(o, day))
            .toList();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x12FFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppThemeTokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _dayFmt.format(day),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppThemeTokens.textPrimary,
                    ),
                  ),
                  Text(
                    '${dayList.length} event${dayList.length == 1 ? "" : "s"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppThemeTokens.textMuted,
                    ),
                  ),
                ],
              ),
              if (dayList.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final occ in dayList)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _OccurrenceCard(
                      occurrence: occ,
                      members: members,
                      currentUserId: currentUserId,
                      dayLabel: _dayFmt.format(occ.start),
                      timeLabel:
                          '${_timeFmt.format(occ.start)} – ${_timeFmt.format(occ.end)}',
                      onTap: () => _openDetails(context, occ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  final ScheduleOccurrence occurrence;
  final List<ServerMember> members;
  final String currentUserId;
  final String dayLabel;
  final String timeLabel;
  final VoidCallback onTap;

  const _OccurrenceCard({
    required this.occurrence,
    required this.members,
    required this.currentUserId,
    required this.dayLabel,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ev = occurrence.event;
    final myRsvp =
        ScheduleUtils.getResponse(ev, occurrence.key, currentUserId);
    final summary =
        ScheduleUtils.summarizeResponses(ev, occurrence.key, members);
    final goingCount = summary['accepted']?.length ?? 0;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x16FFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppThemeTokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeTokens.accentGreen.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppThemeTokens.accentGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppThemeTokens.textSecondary,
                    ),
                  ),
                ),
                if (ev.recurrence != null)
                  const Icon(
                    Icons.repeat_rounded,
                    size: 14,
                    color: AppThemeTokens.accentSky,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ev.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppThemeTokens.textPrimary,
              ),
            ),
            if (ev.description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                ev.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppThemeTokens.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$goingCount going • by ${ev.organizerName ?? "Member"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppThemeTokens.textMuted,
                    ),
                  ),
                ),
                if (myRsvp != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeTokens.accentEmerald
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      myRsvp.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppThemeTokens.accentEmerald,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeTokens.accentGreen.withValues(alpha: 0.18)
              : const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppThemeTokens.accentGreen
                : AppThemeTokens.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected
                ? AppThemeTokens.accentGreen
                : AppThemeTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ScheduleEventDetailsDialog extends StatefulWidget {
  final ScheduleOccurrence occurrence;
  final ScheduleStore scheduleStore;
  final RoomStore roomStore;
  final String currentUserId;
  final ValueChanged<ScheduleEvent> onEdit;

  const _ScheduleEventDetailsDialog({
    required this.occurrence,
    required this.scheduleStore,
    required this.roomStore,
    required this.currentUserId,
    required this.onEdit,
  });

  @override
  State<_ScheduleEventDetailsDialog> createState() =>
      _ScheduleEventDetailsDialogState();
}

class _ScheduleEventDetailsDialogState
    extends State<_ScheduleEventDetailsDialog> {
  RsvpScope _scope = RsvpScope.occurrence;

  Future<void> _respond(RsvpStatus status) async {
    await widget.scheduleStore.respondToEvent(
      eventId: widget.occurrence.event.id,
      key: widget.occurrence.key,
      status: status,
      scope: widget.occurrence.event.recurrence != null
          ? _scope
          : RsvpScope.series,
    );
    widget.roomStore.showNotice('RSVP updated (${status.name})!');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final occ = widget.occurrence;
    final ev = occ.event;
    final canManage =
        ScheduleUtils.canManageEvent(ev, widget.currentUserId);
    final loc = ev.location;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ev.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppThemeTokens.textPrimary,
                        ),
                      ),
                    ),
                    if (canManage) ...[
                      IconButton(
                        onPressed: () => widget.onEdit(ev),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppThemeTokens.accentSky,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await widget.scheduleStore.deleteEvent(ev.id);
                          widget.roomStore.showNotice('Deleted event.');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppThemeTokens.accentRose,
                        ),
                      ),
                    ],
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppThemeTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ScheduleUtils.describeRecurrence(ev.recurrence, occ.start),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppThemeTokens.accentGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (ev.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    ev.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppThemeTokens.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                if (loc != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      if (loc.kind == 'address' && loc.address != null) {
                        launchUrl(
                          Uri.parse(ScheduleUtils.googleMapsUrl(loc.address!)),
                          mode: LaunchMode.externalApplication,
                        );
                      } else if (loc.kind == 'link' && loc.url != null) {
                        launchUrl(
                          Uri.parse(loc.url!),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x14FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: AppThemeTokens.accentSky,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.channelName ??
                                  loc.address ??
                                  loc.url ??
                                  'Discord Voice Room',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppThemeTokens.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (ev.recurrence != null) ...[
                  const SizedBox(height: 14),
                  SegmentedButton<RsvpScope>(
                    segments: const [
                      ButtonSegment(
                        value: RsvpScope.occurrence,
                        label: Text('This occurrence'),
                      ),
                      ButtonSegment(
                        value: RsvpScope.series,
                        label: Text('Entire series'),
                      ),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) =>
                        setState(() => _scope = s.first),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _respond(RsvpStatus.accepted),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeTokens.accentGreen,
                        foregroundColor: AppThemeTokens.bgDeep,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Going',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _respond(RsvpStatus.tentative),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: const Text(
                        'Maybe',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _respond(RsvpStatus.declined),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Decline',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleEventEditorDialog extends StatefulWidget {
  final ScheduleStore scheduleStore;
  final RoomStore roomStore;
  final ScheduleEvent? existing;

  const _ScheduleEventEditorDialog({
    required this.scheduleStore,
    required this.roomStore,
    this.existing,
  });

  @override
  State<_ScheduleEventEditorDialog> createState() =>
      _ScheduleEventEditorDialogState();
}

class _ScheduleEventEditorDialogState
    extends State<_ScheduleEventEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  String _freq = 'none'; // 'none' | 'daily' | 'weekly' | 'monthly'
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleController = TextEditingController(text: ex?.title ?? '');
    _descController = TextEditingController(text: ex?.description ?? '');
    _addressController =
        TextEditingController(text: ex?.location?.address ?? '');
    _freq = ex?.recurrence?.freq ?? 'none';
    _durationMinutes = ex?.durationMinutes ?? 60;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final startIso = widget.existing?.start ??
        DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String();

    final payload = <String, dynamic>{
      'title': title,
      'description': _descController.text.trim(),
      'start': startIso,
      'durationMinutes': _durationMinutes,
      'inviteEveryone': true,
      if (_freq != 'none')
        'recurrence': {
          'freq': _freq,
          'interval': 1,
        },
      if (_addressController.text.trim().isNotEmpty)
        'location': {
          'kind': 'address',
          'address': _addressController.text.trim(),
        },
    };

    if (widget.existing != null) {
      await widget.scheduleStore.updateEvent(widget.existing!.id, payload);
      widget.roomStore.showNotice('Updated event "$title"!');
    } else {
      await widget.scheduleStore.createEvent(payload);
      widget.roomStore.showNotice('Created event "$title"!');
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassPanel(
          backgroundColor: const Color(0xF511171D),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing != null ? 'Edit Event' : 'Create Event',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppThemeTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Event Title',
                    labelStyle: const TextStyle(fontSize: 12),
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: const TextStyle(fontSize: 12),
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Location / Google Maps Address (optional)',
                    labelStyle: const TextStyle(fontSize: 12),
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _freq,
                  dropdownColor: AppThemeTokens.bgElevated,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppThemeTokens.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Recurrence',
                    filled: true,
                    fillColor: AppThemeTokens.bgInput,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text('Does not repeat'),
                    ),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _freq = v);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeTokens.accentGreen,
                        foregroundColor: AppThemeTokens.bgDeep,
                      ),
                      child: const Text(
                        'Save Event',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
