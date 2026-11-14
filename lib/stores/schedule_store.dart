import 'package:signals_flutter/signals_flutter.dart';
import '../core/repositories/schedule_repository.dart';
import '../core/utils/schedule_utils.dart';
import '../models/schedule_models.dart';
import '../models/state_machine_dto.dart';
import 'entity_fsm_store.dart';

class ScheduleStore {
  final ScheduleGateway _gateway;

  late final StatefulEntityController<ScheduleDataResponse> scheduleFsm;
  final Signal<CalendarViewMode> viewMode = signal(CalendarViewMode.agenda);
  final Signal<ScheduleFilterMode> filterMode = signal(ScheduleFilterMode.all);
  final Signal<DateTime> cursorDate =
      signal(ScheduleUtils.startOfDay(DateTime.now()));
  final Signal<({String id, String key})?> selectedOccurrence = signal(null);
  final Signal<String?> activeGuildId = signal(null);

  late final ReadonlySignal<List<ScheduleEvent>> events;
  late final ReadonlySignal<List<ServerMember>> members;
  late final ReadonlySignal<List<ServerChannel>> channels;

  ScheduleStore({required ScheduleGateway gateway}) : _gateway = gateway {
    scheduleFsm = StatefulEntityController<ScheduleDataResponse>(
      id: 'server_schedule',
      onForegroundResync: () {
        final gid = activeGuildId.value;
        if (gid != null && gid.isNotEmpty) {
          fetchSchedule(gid);
        }
      },
    );

    events = computed(() => scheduleFsm.activeData.value?.events ?? const []);
    members = computed(() => scheduleFsm.activeData.value?.members ?? const []);
    channels =
        computed(() => scheduleFsm.activeData.value?.channels ?? const []);
  }

  int countPendingForUser(String userId) {
    return ScheduleUtils.countPendingInvites(
      events.value,
      userId,
      members.value,
    );
  }

  List<ScheduleOccurrence> visibleOccurrencesForUser(String userId) {
    final cur = cursorDate.value;
    final mode = viewMode.value;
    late final DateTime from;
    late final DateTime to;

    if (mode == CalendarViewMode.month) {
      final firstOfMonth = DateTime(cur.year, cur.month, 1);
      from = firstOfMonth.subtract(Duration(days: firstOfMonth.weekday % 7));
      final lastOfMonth = DateTime(cur.year, cur.month + 1, 0);
      to = lastOfMonth.add(Duration(days: 7 - (lastOfMonth.weekday % 7)));
    } else if (mode == CalendarViewMode.week) {
      from = cur.subtract(Duration(days: cur.weekday % 7));
      to = from.add(const Duration(days: 7));
    } else {
      from = ScheduleUtils.startOfDay(cur);
      to = from.add(const Duration(days: 60));
    }

    final expanded = ScheduleUtils.expandEvents(events.value, from, to);
    final filter = filterMode.value;
    final mems = members.value;

    return expanded.where((o) {
      switch (filter) {
        case ScheduleFilterMode.mine:
          return o.event.organizerId == userId;
        case ScheduleFilterMode.invited:
          return ScheduleUtils.isInvited(o.event, userId, mems);
        case ScheduleFilterMode.pending:
          return ScheduleUtils.isInvited(o.event, userId, mems) &&
              ScheduleUtils.getResponse(o.event, o.key, userId) == null;
        case ScheduleFilterMode.all:
          return true;
      }
    }).toList();
  }

  void stepCursor(int direction) {
    final cur = cursorDate.value;
    final mode = viewMode.value;
    if (mode == CalendarViewMode.month) {
      cursorDate.value = DateTime(cur.year, cur.month + direction, 1);
    } else if (mode == CalendarViewMode.week) {
      cursorDate.value = cur.add(Duration(days: 7 * direction));
    } else {
      cursorDate.value = cur.add(Duration(days: 30 * direction));
    }
  }

  void goToday() {
    cursorDate.value = ScheduleUtils.startOfDay(DateTime.now());
  }

  Future<void> fetchSchedule(String guildId) async {
    if (guildId.isEmpty) return;
    activeGuildId.value = guildId;
    final prevData = scheduleFsm.activeData.value;
    scheduleFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Fetching schedule for guild $guildId',
      data: prevData,
    );
    try {
      final data = await _gateway.fetchSchedule(guildId);
      scheduleFsm.transitionTo(
        EntityStatus.active,
        reason: 'Loaded ${data.events.length} schedule events',
        data: data,
      );
    } catch (e) {
      scheduleFsm.transitionTo(
        EntityStatus.error,
        reason: 'Failed to load schedule',
        error: e.toString(),
      );
    }
  }

  Future<ScheduleEvent?> createEvent(Map<String, dynamic> payload) async {
    final gid = activeGuildId.value;
    if (gid == null || gid.isEmpty) return null;
    final created = await _gateway.createEvent(gid, payload);
    await fetchSchedule(gid);
    return created;
  }

  Future<ScheduleEvent?> updateEvent(
    String eventId,
    Map<String, dynamic> payload,
  ) async {
    final gid = activeGuildId.value;
    if (gid == null || gid.isEmpty) return null;
    final updated = await _gateway.updateEvent(gid, eventId, payload);
    await fetchSchedule(gid);
    return updated;
  }

  Future<void> deleteEvent(String eventId, {String? occurrence}) async {
    final gid = activeGuildId.value;
    if (gid == null || gid.isEmpty) return;
    await _gateway.deleteEvent(gid, eventId, occurrence: occurrence);
    selectedOccurrence.value = null;
    await fetchSchedule(gid);
  }

  Future<ScheduleEvent?> respondToEvent({
    required String eventId,
    required String key,
    required RsvpStatus status,
    required RsvpScope scope,
  }) async {
    final gid = activeGuildId.value;
    if (gid == null || gid.isEmpty) return null;
    final updated = await _gateway.respondToEvent(
      gid,
      eventId,
      key: key,
      status: status,
      scope: scope,
    );
    await fetchSchedule(gid);
    return updated;
  }

  void dispose() {
    scheduleFsm.dispose();
    viewMode.dispose();
    filterMode.dispose();
    cursorDate.dispose();
    selectedOccurrence.dispose();
    activeGuildId.dispose();
  }
}
