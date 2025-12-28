import 'package:meta/meta.dart';

@immutable
class AttendanceDto {
  final String id;
  final String userId;
  final String type;
  final String time; // ISO8601 from API
  final double latitude;
  final double longitude;
  final bool late;

  const AttendanceDto({
    required this.id,
    required this.userId,
    required this.type,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.late,
  });

  factory AttendanceDto.fromJson(Map<String, dynamic> j) {
    final loc = j['location'] ?? {};
    return AttendanceDto(
      id: j['_id']?.toString() ?? '',
      userId: j['userId']?.toString() ?? '',
      type: j['type'] ?? '',
      time: j['time'] ?? j['createdAt'] ?? DateTime.now().toIso8601String(),
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      late: (j['late'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'userId': userId,
    'type': type,
    'time': time,
    'location': {'latitude': latitude, 'longitude': longitude},
    'late': late,
  };
}
