import 'package:attendance/services/api_service.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../models/attendance.dart';

part 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final AttendanceRepository attendanceRepo;
  final CompanyRepository companyRepo;
  final ProfileRepository profileRepo;

  DashboardCubit({
    required this.attendanceRepo,
    required this.companyRepo,
    required this.profileRepo,
  }) : super(const DashboardState.initial());

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final username = await profileRepo.getUsername();
      final hours = await companyRepo.getCompanyHours();
      final timeStart = hours['time_start'] ?? '';
      final timeEnd = hours['time_end'] ?? '';
      final today = await attendanceRepo.fetchToday();
      final history = await attendanceRepo.fetchHistory();

      final (onTime, late) = _calcStats(history);

      emit(
        state.copyWith(
          loading: false,
          username: username,
          timeStart: timeStart,
          timeEnd: timeEnd,
          todayAttendances: today,
          myAttendances: history,
          onTimeCount: onTime,
          lateCount: late,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> refresh() async {
    try {
      final today = await attendanceRepo.fetchToday();
      final history = await attendanceRepo.fetchHistory();
      final (onTime, late) = _calcStats(history);
      emit(
        state.copyWith(
          todayAttendances: today,
          myAttendances: history,
          onTimeCount: onTime,
          lateCount: late,
        ),
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> checkIn({required double lat, required double lng}) async {
    try {
      await attendanceRepo.checkIn(lat: lat, lng: lng);
      await refresh();
      emit(state.copyWith(actionMessage: 'checkin_ok', error: null));
    } catch (e) {
      emit(
        state.copyWith(error: _toIndoError(e), actionMessage: 'checkin_fail'),
      );
    }
  }

  Future<void> checkOut({required double lat, required double lng}) async {
    try {
      await attendanceRepo.checkOut(lat: lat, lng: lng);
      await refresh();
      emit(state.copyWith(actionMessage: 'checkout_ok', error: null));
    } catch (e) {
      emit(
        state.copyWith(error: _toIndoError(e), actionMessage: 'checkout_fail'),
      );
    }
  }

  // ===================== Helper terjemahan error =====================
  String _toIndoError(Object e) {
    if (e is ApiError) {
      final msg = (e.message).toString();

      final lower = msg.toLowerCase();
      if (lower.contains('outside company area')) {
        return 'Anda berada di luar area perusahaan.';
      }
      if (lower.contains('already checked in')) {
        return 'Anda sudah melakukan check-in.';
      }
      if (lower.contains('already checked out')) {
        return 'Anda sudah melakukan check-out.';
      }
      if (lower.contains('not logged in')) {
        return 'Sesi berakhir. Silakan login kembali.';
      }

      switch (e.status) {
        case 400:
          return msg.isNotEmpty ? msg : 'Permintaan tidak valid.';
        case 401:
          return 'Sesi berakhir atau tidak valid. Silakan login kembali.';
        case 403:
          return 'Akses ditolak.';
        case 404:
          return 'Data tidak ditemukan.';
        case 409:
          return 'Terjadi konflik data.';
        case 500:
          return 'Terjadi kesalahan pada server.';
      }
      return msg.isNotEmpty ? msg : 'Terjadi kesalahan yang tidak diketahui.';
    }

    // Jika bukan ApiError (mis. exception jaringan)
    final s = e.toString();
    if (s.contains('SocketException')) {
      return 'Koneksi internet bermasalah.';
    }
    if (s.toLowerCase().contains('timeout')) {
      return 'Koneksi timeout. Coba lagi nanti.';
    }
    // fallback umum
    return s.replaceFirst('Exception: ', '');
  }

  (int onTime, int late) _calcStats(List<Attendance> list) {
    int onTime = 0;
    int late = 0;
    for (final a in list) {
      if (a.type == 'checkin') {
        if (a.late == true) {
          late++;
        } else {
          onTime++;
        }
      }
    }
    return (onTime, late);
  }

  void clearTransientFlags() {
    // hilangkan actionMessage agar listener tidak ter-trigger berulang
    emit(state.copyWith(actionMessage: null, error: null));
  }
}
