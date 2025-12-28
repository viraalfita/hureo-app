part of 'leave_cubit.dart';

abstract class LeaveState extends Equatable {
  const LeaveState();
  @override
  List<Object?> get props => [];
}

class LeaveInitial extends LeaveState {}

class LeaveLoading extends LeaveState {}

class LeaveLoaded extends LeaveState {
  final List<Leave> items;
  const LeaveLoaded(this.items);
  @override
  List<Object?> get props => [items];
}

class LeaveActionSuccess extends LeaveState {
  final Leave item;
  const LeaveActionSuccess(this.item);
  @override
  List<Object?> get props => [item];
}

class LeaveFailure extends LeaveState {
  final String message;
  const LeaveFailure(this.message);
  @override
  List<Object?> get props => [message];
}
