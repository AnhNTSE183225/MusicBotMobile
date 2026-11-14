import '../../models/schedule_models.dart';
import '../network/api_client.dart';

/// Segregated SOLID interface for Server Schedule & Calendar operations.
abstract interface class ScheduleGateway {
  Future<ScheduleDataResponse> fetchSchedule(String guildId);
  Future<ScheduleEvent> createEvent(
    String guildId,
    Map<String, dynamic> eventData,
  );
  Future<ScheduleEvent> updateEvent(
    String guildId,
    String eventId,
    Map<String, dynamic> eventData,
  );
  Future<void> deleteEvent(
    String guildId,
    String eventId, {
    String? occurrence,
  });
  Future<ScheduleEvent> respondToEvent(
    String guildId,
    String eventId, {
    required String key,
    required RsvpStatus status,
    required RsvpScope scope,
  });
}

class LiveScheduleRepository implements ScheduleGateway {
  final ApiClient _client;

  LiveScheduleRepository(this._client);

  @override
  Future<ScheduleDataResponse> fetchSchedule(String guildId) async {
    final raw = await _client.get('/schedule/$guildId');
    return ScheduleDataResponse.fromJson(raw);
  }

  @override
  Future<ScheduleEvent> createEvent(
    String guildId,
    Map<String, dynamic> eventData,
  ) async {
    final raw = await _client.post('/schedule/$guildId', body: eventData);
    final eventMap = raw['event'];
    if (eventMap is Map<String, dynamic>) {
      return ScheduleEvent.fromJson(eventMap);
    }
    throw const ApiException('Invalid event response');
  }

  @override
  Future<ScheduleEvent> updateEvent(
    String guildId,
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    final raw = await _client.put(
      '/schedule/$guildId/$eventId',
      body: eventData,
    );
    final eventMap = raw['event'];
    if (eventMap is Map<String, dynamic>) {
      return ScheduleEvent.fromJson(eventMap);
    }
    throw const ApiException('Invalid event update response');
  }

  @override
  Future<void> deleteEvent(
    String guildId,
    String eventId, {
    String? occurrence,
  }) async {
    final endpoint = (occurrence != null && occurrence.isNotEmpty)
        ? '/schedule/$guildId/$eventId?occurrence=${Uri.encodeQueryComponent(occurrence)}'
        : '/schedule/$guildId/$eventId';
    await _client.delete(endpoint);
  }

  @override
  Future<ScheduleEvent> respondToEvent(
    String guildId,
    String eventId, {
    required String key,
    required RsvpStatus status,
    required RsvpScope scope,
  }) async {
    final raw = await _client.post(
      '/schedule/$guildId/$eventId/respond',
      body: {
        'key': key,
        'status': status.name,
        'scope': scope.name,
      },
    );
    final eventMap = raw['event'];
    if (eventMap is Map<String, dynamic>) {
      return ScheduleEvent.fromJson(eventMap);
    }
    throw const ApiException('Invalid RSVP response');
  }
}
