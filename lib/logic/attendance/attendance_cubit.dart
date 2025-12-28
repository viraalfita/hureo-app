import 'package:attendance/services/api_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/attendance_repository.dart';
import '../../models/attendance.dart';

part 'attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  final AttendanceRepository repo;
  AttendanceCubit(this.repo) : super(AttendanceInitial());

  Future<void> loadHistory() async {
    emit(AttendanceLoading());
    try {
      final list = await repo.fetchHistory();
      emit(AttendanceLoaded(list));
    } catch (e) {
      emit(AttendanceFailure(_friendlyError(e)));
    }
  }

  Future<void> checkIn(double lat, double lng) async {
    emit(AttendanceLoading());
    try {
      final rec = await repo.checkIn(lat: lat, lng: lng);
      emit(AttendanceActionSuccess(rec));
    } catch (e) {
      emit(AttendanceFailure(_friendlyError(e)));
    }
  }

  Future<void> checkOut(double lat, double lng) async {
    emit(AttendanceLoading());
    try {
      final rec = await repo.checkOut(lat: lat, lng: lng);
      emit(AttendanceActionSuccess(rec));
    } catch (e) {
      emit(AttendanceFailure(_friendlyError(e)));
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiError) return e.message;
    final s = e.toString();
    if (s.contains('SocketException')) {
      return 'Koneksi internet bermasalah.';
    }
    if (s.contains('TimeoutException') || s.toLowerCase().contains('timeout')) {
      return 'Timeout. Coba lagi nanti.';
    }
    return s.replaceFirst('Exception: ', '');
  }
}
