import 'package:json_annotation/json_annotation.dart';

part 'schedule_models.g.dart';

enum RsvpStatus {
  accepted,
  tentative,
  declined;

  static RsvpStatus? fromWire(String? raw) {
    if (raw == null) return null;
    for (final v in RsvpStatus.values) {
      if (v.name == raw.toLowerCase()) return v;
    }
    return null;
  }
}

enum RsvpScope {
  occurrence,
  series;
}

enum EventCategory {
  gaming,
  food,
  outdoor,
  other;

  static EventCategory fromWire(String? raw) {
    if (raw == null) return EventCategory.other;
    for (final v in EventCategory.values) {
      if (v.name == raw.toLowerCase()) return v;
    }
    return EventCategory.other;
  }
}

enum CalendarViewMode {
  agenda,
  month,
  week;
}

enum ScheduleFilterMode {
  all,
  invited,
  pending,
  mine;
}

@JsonSerializable()
class ServerMember {
  final String id;
  final String name;
  @JsonKey(defaultValue: '')
  final String avatar;

  const ServerMember({
    required this.id,
    required this.name,
    this.avatar = '',
  });

  factory ServerMember.fromJson(Map<String, dynamic> json) =>
      _$ServerMemberFromJson(json);

  Map<String, dynamic> toJson() => _$ServerMemberToJson(this);
}

@JsonSerializable()
class ServerChannel {
  final String id;
  final String name;
  @JsonKey(defaultValue: 'voice')
  final String type; // 'voice' | 'stage'

  const ServerChannel({
    required this.id,
    required this.name,
    this.type = 'voice',
  });

  factory ServerChannel.fromJson(Map<String, dynamic> json) =>
      _$ServerChannelFromJson(json);

  Map<String, dynamic> toJson() => _$ServerChannelToJson(this);
}

@JsonSerializable()
class ScheduleEventLocation {
  final String kind; // 'discord' | 'address' | 'link'
  final String? channelId;
  final String? channelName;
  final String? address;
  final String? url;

  const ScheduleEventLocation({
    required this.kind,
    this.channelId,
    this.channelName,
    this.address,
    this.url,
  });

  factory ScheduleEventLocation.fromJson(Map<String, dynamic> json) =>
      _$ScheduleEventLocationFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleEventLocationToJson(this);
}

@JsonSerializable()
class ScheduleEventLink {
  final String label;
  final String url;

  const ScheduleEventLink({
    required this.label,
    required this.url,
  });

  factory ScheduleEventLink.fromJson(Map<String, dynamic> json) =>
      _$ScheduleEventLinkFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleEventLinkToJson(this);
}

@JsonSerializable()
class ScheduleEventRecurrence {
  final String freq; // 'daily' | 'weekly' | 'monthly'
  @JsonKey(defaultValue: 1)
  final int interval;
  final List<int>? weekdays;
  final String? until;
  final int? count;

  const ScheduleEventRecurrence({
    required this.freq,
    this.interval = 1,
    this.weekdays,
    this.until,
    this.count,
  });

  factory ScheduleEventRecurrence.fromJson(Map<String, dynamic> json) =>
      _$ScheduleEventRecurrenceFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleEventRecurrenceToJson(this);
}

@JsonSerializable()
class ScheduleEvent {
  final String id;
  final String guildId;
  final String title;
  @JsonKey(defaultValue: '')
  final String description;
  final String? category;
  final String start;
  @JsonKey(defaultValue: 60)
  final int durationMinutes;
  final ScheduleEventRecurrence? recurrence;
  final ScheduleEventLocation? location;
  final String? imageUrl;
  @JsonKey(defaultValue: [])
  final List<ScheduleEventLink> links;
  final String organizerId;
  final String? organizerName;
  final String? organizerAvatar;
  @JsonKey(defaultValue: true)
  final bool inviteEveryone;
  @JsonKey(defaultValue: [])
  final List<String> inviteeIds;
  @JsonKey(defaultValue: {})
  final Map<String, String> seriesResponses;
  @JsonKey(defaultValue: {})
  final Map<String, Map<String, String>> occurrenceResponses;
  @JsonKey(defaultValue: [])
  final List<String> cancelledOccurrences;
  final num? createdAt;
  final num? updatedAt;

  const ScheduleEvent({
    required this.id,
    required this.guildId,
    required this.title,
    this.description = '',
    this.category,
    required this.start,
    this.durationMinutes = 60,
    this.recurrence,
    this.location,
    this.imageUrl,
    this.links = const [],
    required this.organizerId,
    this.organizerName,
    this.organizerAvatar,
    this.inviteEveryone = true,
    this.inviteeIds = const [],
    this.seriesResponses = const {},
    this.occurrenceResponses = const {},
    this.cancelledOccurrences = const [],
    this.createdAt,
    this.updatedAt,
  });

  EventCategory get resolvedCategory => EventCategory.fromWire(category);

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) =>
      _$ScheduleEventFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleEventToJson(this);
}

@JsonSerializable()
class ScheduleDataResponse {
  @JsonKey(defaultValue: [])
  final List<ScheduleEvent> events;
  @JsonKey(defaultValue: [])
  final List<ServerMember> members;
  @JsonKey(defaultValue: [])
  final List<ServerChannel> channels;

  const ScheduleDataResponse({
    this.events = const [],
    this.members = const [],
    this.channels = const [],
  });

  factory ScheduleDataResponse.fromJson(Map<String, dynamic> json) =>
      _$ScheduleDataResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ScheduleDataResponseToJson(this);
}

class ScheduleOccurrence {
  final ScheduleEvent event;
  final String key; // yyyy-MM-dd
  final DateTime start;
  final DateTime end;

  const ScheduleOccurrence({
    required this.event,
    required this.key,
    required this.start,
    required this.end,
  });
}
