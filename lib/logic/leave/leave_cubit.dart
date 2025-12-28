import 'package:attendance/models/leave.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/leave_repository.dart';

part 'leave_state.dart';

class LeaveCubit extends Cubit<LeaveState> {
  final LeaveRepository repo;
  LeaveCubit(this.repo) : super(LeaveInitial());

  Future<void> loadAll() async {
    emit(LeaveLoading());
    try {
      final list = await repo.fetchLeaves();
      emit(LeaveLoaded(list));
    } catch (e) {
      emit(LeaveFailure(e.toString()));
    }
  }

  Future<void> create({
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    emit(LeaveLoading());
    try {
      final item = await repo.createLeave(
        reason: reason,
        startDate: startDate,
        endDate: endDate,
      );
      emit(LeaveActionSuccess(item));
    } catch (e) {
      emit(LeaveFailure(e.toString()));
    }
  }
}
