import 'package:meta/meta.dart';

@immutable
class LeaveDto {
  final String id;
  final String userId;
  final String reason;
  final String startDate;
  final String endDate;
  final String status;
  final String createdAt;

  const LeaveDto({
    required this.id,
    required this.userId,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory LeaveDto.fromJson(Map<String, dynamic> j) => LeaveDto(
    id: j['_id']?.toString() ?? '',
    userId: j['userId']?.toString() ?? '',
    reason: j['reason'] ?? '',
    startDate: j['startDate'] ?? '',
    endDate: j['endDate'] ?? '',
    status: j['status'] ?? 'pending',
    createdAt: j['createdAt'] ?? DateTime.now().toIso8601String(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'userId': userId,
    'reason': reason,
    'startDate': startDate,
    'endDate': endDate,
    'status': status,
    'createdAt': createdAt,
  };
}
