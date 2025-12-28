import '../../models/leave.dart';
import '../../services/api_service.dart';

class LeaveRepository {
  const LeaveRepository();

  Future<List<Leave>> fetchLeaves() async {
    await ApiService.loadSession();

    if (ApiService.userId == null) {
      throw Exception('Belum login / userId tidak tersedia di session');
    }

    return await ApiService.getMyLeaves();
  }

  Future<Leave> createLeave({
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ok = await ApiService.requestLeave(reason, startDate, endDate);
    if (!ok) throw Exception('Pengajuan cuti gagal');

    // Ambil list terbaru, lalu kembalikan item yang paling baru.
    final list = await ApiService.getMyLeaves();
    if (list.isEmpty) {
      throw Exception('Pengajuan sukses, tetapi data cuti tidak ditemukan');
    }
    // asumsi backend mengurutkan terbaru di awal; kalau tidak, bisa sort by createdAt
    return list.first;
  }
}
