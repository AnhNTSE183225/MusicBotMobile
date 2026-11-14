import 'package:intl/intl.dart';
import '../../models/schedule_models.dart';

/// Pure recurrence & RSVP rules matching MusicBotUI/src/lib/schedule.ts.
abstract final class ScheduleUtils {
  static const List<String> weekdayShort = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _shortDateFormat = DateFormat('MMM d, yyyy');

  static String occurrenceKey(DateTime d) => _keyFormat.format(d);

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool isOccurrenceOnDay(ScheduleOccurrence o, DateTime d) {
    final dayStart = startOfDay(d);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return o.start.isBefore(dayEnd) && o.end.isAfter(dayStart);
  }

  static bool canManageEvent(
    ScheduleEvent event,
    String userId, {
    bool isAdmin = false,
  }) {
    return event.organizerId == userId || isAdmin;
  }

  static int _jsWeekday(DateTime d) => d.weekday % 7; // 0 = Sun .. 6 = Sat

  static int _diffInCalendarWeeks(DateTime a, DateTime b) {
    final startA = startOfDay(a).subtract(Duration(days: _jsWeekday(a)));
    final startB = startOfDay(b).subtract(Duration(days: _jsWeekday(b)));
    return startA.difference(startB).inDays ~/ 7;
  }

  static int _diffInCalendarMonths(DateTime a, DateTime b) {
    return (a.year - b.year) * 12 + (a.month - b.month);
  }

  static List<ScheduleOccurrence> expandEvent(
    ScheduleEvent event,
    DateTime from,
    DateTime to,
  ) {
    DateTime first;
    try {
      first = DateTime.parse(event.start).toLocal();
    } catch (_) {
      return const [];
    }

    ScheduleOccurrence make(DateTime start) => ScheduleOccurrence(
          event: event,
          key: occurrenceKey(start),
          start: start,
          end: start.add(Duration(minutes: event.durationMinutes)),
        );

    final r = event.recurrence;
    if (r == null) {
      final occ = make(first);
      if (first.isBefore(to) &&
          occ.end.isAfter(from) &&
          !event.cancelledOccurrences.contains(occurrenceKey(first))) {
        return [occ];
      }
      return const [];
    }

    final interval = r.interval < 1 ? 1 : r.interval;
    DateTime? until;
    if (r.until != null && r.until!.isNotEmpty) {
      try {
        until = startOfDay(DateTime.parse(r.until!).toLocal())
            .add(const Duration(days: 1));
      } catch (_) {}
    }

    final weekdays = (r.freq == 'weekly' &&
            r.weekdays != null &&
            r.weekdays!.isNotEmpty)
        ? r.weekdays!
        : <int>[_jsWeekday(first)];

    final out = <ScheduleOccurrence>[];
    var produced = 0;
    final firstDay = startOfDay(first);

    for (var i = 0; i < 3660; i++) {
      final day = firstDay.add(Duration(days: i));
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        first.hour,
        first.minute,
      );
      if (!start.isBefore(to)) break;
      if (until != null && !start.isBefore(until)) break;

      var matches = false;
      if (r.freq == 'daily') {
        matches = i % interval == 0;
      } else if (r.freq == 'weekly') {
        matches = weekdays.contains(_jsWeekday(day)) &&
            _diffInCalendarWeeks(day, first) % interval == 0;
      } else {
        matches = day.day == first.day &&
            _diffInCalendarMonths(day, first) % interval == 0;
      }

      if (!matches) continue;
      produced++;
      if (r.count != null && produced > r.count!) break;
      final key = occurrenceKey(start);
      if (event.cancelledOccurrences.contains(key)) continue;

      final occ = make(start);
      if (occ.end.isAfter(from)) {
        out.add(occ);
      }
    }
    return out;
  }

  static List<ScheduleOccurrence> expandEvents(
    List<ScheduleEvent> events,
    DateTime from,
    DateTime to,
  ) {
    final list = <ScheduleOccurrence>[];
    for (final e in events) {
      list.addAll(expandEvent(e, from, to));
    }
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  static List<String> getInviteeIds(
    ScheduleEvent event,
    List<ServerMember> members,
  ) {
    final ids = event.inviteEveryone
        ? members.map((m) => m.id).toList()
        : event.inviteeIds;
    return <String>{event.organizerId, ...ids}.toList();
  }

  static bool isInvited(
    ScheduleEvent event,
    String userId,
    List<ServerMember> members,
  ) {
    if (userId.isEmpty) return false;
    return getInviteeIds(event, members).contains(userId);
  }

  static RsvpStatus? getResponse(
    ScheduleEvent event,
    String key,
    String userId,
  ) {
    final occRaw = event.occurrenceResponses[key]?[userId];
    if (occRaw != null) return RsvpStatus.fromWire(occRaw);
    final seriesRaw = event.seriesResponses[userId];
    return RsvpStatus.fromWire(seriesRaw);
  }

  static Map<String, List<ServerMember>> summarizeResponses(
    ScheduleEvent event,
    String key,
    List<ServerMember> members,
  ) {
    final groups = <String, List<ServerMember>>{
      'accepted': <ServerMember>[],
      'tentative': <ServerMember>[],
      'declined': <ServerMember>[],
      'pending': <ServerMember>[],
    };
    for (final id in getInviteeIds(event, members)) {
      final member = members.firstWhere(
        (m) => m.id == id,
        orElse: () => ServerMember(id: id, name: 'Member', avatar: ''),
      );
      final resp = getResponse(event, key, id)?.name ?? 'pending';
      (groups[resp] ?? groups['pending']!).add(member);
    }
    return groups;
  }

  static String describeRecurrence(
    ScheduleEventRecurrence? r,
    DateTime start,
  ) {
    if (r == null) return 'Does not repeat';
    final every = r.interval > 1 ? 'Every ${r.interval} ' : 'Every ';
    String base;
    if (r.freq == 'daily') {
      base = r.interval > 1 ? '${every}days' : 'Daily';
    } else if (r.freq == 'weekly') {
      final days = ((r.weekdays != null && r.weekdays!.isNotEmpty)
              ? List<int>.from(r.weekdays!)
              : <int>[_jsWeekday(start)])
        ..sort();
      final dayNames = days.map((d) => weekdayShort[d % 7]).join(', ');
      base = '${r.interval > 1 ? '${every}weeks' : 'Weekly'} on $dayNames';
    } else {
      base =
          '${r.interval > 1 ? '${every}months' : 'Monthly'} on day ${start.day}';
    }
    if (r.until != null && r.until!.isNotEmpty) {
      try {
        final untilDate = DateTime.parse(r.until!).toLocal();
        base += ' · until ${_shortDateFormat.format(untilDate)}';
      } catch (_) {}
    } else if (r.count != null) {
      base += ' · ${r.count} times';
    }
    return base;
  }

  static int countPendingInvites(
    List<ScheduleEvent> events,
    String userId,
    List<ServerMember> members, {
    int days = 30,
  }) {
    if (userId.isEmpty) return 0;
    final now = DateTime.now();
    final expanded = expandEvents(
      events,
      now,
      now.add(Duration(days: days)),
    );
    return expanded
        .where(
          (o) =>
              o.end.isAfter(now) &&
              isInvited(o.event, userId, members) &&
              getResponse(o.event, o.key, userId) == null,
        )
        .length;
  }

  static String googleMapsUrl(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(trimmed)}';
  }
}
