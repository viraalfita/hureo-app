import '../../models/attendance.dart';
import '../../services/api_service.dart';

class AttendanceRepository {
  const AttendanceRepository();

  Future<List<Attendance>> fetchHistory() => ApiService.getMyAttendance();

  Future<List<Attendance>> fetchToday() => ApiService.getAttendanceByDay();

  Future<Attendance> checkIn({required double lat, required double lng}) async {
    await ApiService.checkIn(lat, lng);

    final today = await ApiService.getAttendanceByDay();
    if (today.isNotEmpty) return today.first;

    final all = await ApiService.getMyAttendance();
    if (all.isNotEmpty) return all.first;

    throw Exception('Check-in sukses tapi record attendance tidak ditemukan');
  }

  Future<Attendance> checkOut({
    required double lat,
    required double lng,
  }) async {
    await ApiService.checkOut(lat, lng);

    final today = await ApiService.getAttendanceByDay();
    if (today.isNotEmpty) return today.first;

    final all = await ApiService.getMyAttendance();
    if (all.isNotEmpty) return all.first;

    throw Exception('Check-out sukses tapi record attendance tidak ditemukan');
  }
}
