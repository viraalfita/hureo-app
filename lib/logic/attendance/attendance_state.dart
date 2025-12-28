part of 'attendance_cubit.dart';

abstract class AttendanceState extends Equatable {
  const AttendanceState();
  @override
  List<Object?> get props => [];
}

class AttendanceInitial extends AttendanceState {}

class AttendanceLoading extends AttendanceState {}

class AttendanceLoaded extends AttendanceState {
  final List<Attendance> items;
  const AttendanceLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class AttendanceActionSuccess extends AttendanceState {
  final Attendance item;
  const AttendanceActionSuccess(this.item);
  @override
  List<Object?> get props => [item];
}

class AttendanceFailure extends AttendanceState {
  final String message;
  const AttendanceFailure(this.message);
  @override
  List<Object?> get props => [message];
}
