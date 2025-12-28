import 'package:equatable/equatable.dart';

abstract class LeaveEvent extends Equatable {
  const LeaveEvent();
  @override
  List<Object?> get props => [];
}

class LeaveLoadAll extends LeaveEvent {
  const LeaveLoadAll();
}

class LeaveCreateRequested extends LeaveEvent {
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  const LeaveCreateRequested({
    required this.reason,
    required this.startDate,
    required this.endDate,
  });
  @override
  List<Object?> get props => [reason, startDate, endDate];
}
