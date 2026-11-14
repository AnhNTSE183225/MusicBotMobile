import 'package:json_annotation/json_annotation.dart';

part 'state_machine_dto.g.dart';

enum EntityStatus {
  disconnected,
  idle,
  loading,
  active,
  paused,
  error;

  static EntityStatus fromWire(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == 'playing') {
      return EntityStatus.active;
    }
    return EntityStatus.values.firstWhere(
      (e) => e.name == normalized,
      orElse: () => EntityStatus.idle,
    );
  }
}

@JsonSerializable(genericArgumentFactories: true)
class StateMachineDTO<T> {
  final EntityStatus status;
  final T? data;
  final int timestamp;

  const StateMachineDTO({
    required this.status,
    required this.data,
    required this.timestamp,
  });

  factory StateMachineDTO.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$StateMachineDTOFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$StateMachineDTOToJson(this, toJsonT);

  /// Resilient backwards-compatible resolver matching FRONTEND_TECHSTACK.md & MOBILE_TECHSTACK.md
  static EntityStatus resolveEntityStatus(Map<String, dynamic> json) {
    if (json['status'] is String) {
      return EntityStatus.fromWire(json['status'] as String);
    }
    if (json['bot_connected'] == false) {
      return EntityStatus.disconnected;
    }
    if (json['is_active'] == false &&
        json['data'] == null &&
        json['current'] == null) {
      return EntityStatus.idle;
    }
    if (json['is_loading'] == true) {
      return EntityStatus.loading;
    }
    if (json['is_paused'] == true && json['current'] != null) {
      return EntityStatus.paused;
    }
    if ((json['is_active'] == true || json['is_playing'] == true) &&
        json['current'] != null) {
      return EntityStatus.active;
    }
    if (json['current'] != null && json['stopped'] != true) {
      return EntityStatus.active;
    }
    return EntityStatus.idle;
  }
}
