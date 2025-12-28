import 'package:equatable/equatable.dart';

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();
  @override
  List<Object?> get props => [];
}

class AttendanceLoadHistory extends AttendanceEvent {
  final String userId;
  const AttendanceLoadHistory(this.userId);
  @override
  List<Object?> get props => [userId];
}

class AttendanceCheckIn extends AttendanceEvent {
  final String userId;
  final double lat;
  final double lng;
  const AttendanceCheckIn({
    required this.userId,
    required this.lat,
    required this.lng,
  });
  @override
  List<Object?> get props => [userId, lat, lng];
}

class AttendanceCheckOut extends AttendanceEvent {
  final String userId;
  final double lat;
  final double lng;
  const AttendanceCheckOut({
    required this.userId,
    required this.lat,
    required this.lng,
  });
  @override
  List<Object?> get props => [userId, lat, lng];
}
