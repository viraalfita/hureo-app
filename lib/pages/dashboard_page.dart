import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:slide_to_act/slide_to_act.dart';

import '../logic/dashboard/dashboard_cubit.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../services/face_api_service.dart';
import '../services/face_recognition_service.dart';
import '../theme/app_colors.dart';
import '../widgets/face_capture_sheet.dart';
import '../widgets/face_enroll_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? checkInTime;
  String? checkOutTime;
  List<Attendance> todayAttendances = [];
  List<Attendance> myAttendances = [];
  bool isLoading = true;
  int onTimeCount = 0;
  int lateCount = 0;
  String _username = "";
  String _timeStart = "";
  String _timeEnd = "";
  bool _verifyingFace = false;

  final _faceService = FaceRecognitionService();
  final _faceApi = FaceApiService();

  final GlobalKey<SlideActionState> _sliderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // minta cubit load semua data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardCubit>().bootstrap();
    });
  }

  // ================== Lokasi device (tetap di page) ==================
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[CheckIn] GPS mati');
      _showSnack('Hidupkan lokasi/GPS dulu.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[CheckIn] Izin lokasi ditolak');
        _showSnack('Izin lokasi diperlukan untuk check-in.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[CheckIn] Izin lokasi ditolak permanen');
      _showSnack(
        'Izin lokasi ditolak permanen. Buka Pengaturan untuk mengaktifkan.',
      );
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _handleCheckIn() async {
    debugPrint('[CheckIn] Slider submit');
    final position = await _getCurrentLocation();
    if (position == null) return;
    debugPrint(
      '[CheckIn] Location ok lat=${position.latitude}, lng=${position.longitude}',
    );
    final verified = await _verifyFace(position.latitude, position.longitude);
    if (!verified) {
      debugPrint('[CheckIn] Face verify failed');
      return;
    }
    try {
      await context.read<DashboardCubit>().checkIn(
        lat: position.latitude,
        lng: position.longitude,
      );
      debugPrint('[CheckIn] API success');
      setState(() {
        checkInTime = DateFormat("HH:mm").format(DateTime.now());
      });
      context.read<DashboardCubit>().clearTransientFlags();
    } catch (e) {
      debugPrint('[CheckIn] error: $e');
      _showSnack('Check-in gagal: $e');
    }
  }

  Future<void> _handleCheckOut() async {
    debugPrint('[CheckOut] Slider submit');
    final position = await _getCurrentLocation();
    if (position == null) return;
    debugPrint(
      '[CheckOut] Location ok lat=${position.latitude}, lng=${position.longitude}',
    );
    final verified = await _verifyFace(position.latitude, position.longitude);
    if (!verified) {
      debugPrint('[CheckOut] Face verify failed');
      return;
    }
    try {
      await context.read<DashboardCubit>().checkOut(
        lat: position.latitude,
        lng: position.longitude,
      );
      debugPrint('[CheckOut] API success');
      setState(() {
        checkOutTime = DateFormat("HH:mm").format(DateTime.now());
      });
      context.read<DashboardCubit>().clearTransientFlags();
    } catch (e) {
      debugPrint('[CheckOut] error: $e');
      _showSnack('Check-out gagal: $e');
    }
  }

  /// Ambil 1 embedding wajah via kamera depan, kirim ke Face Verification API.
  Future<bool> _verifyFace(double lat, double lng) async {
    if (_verifyingFace) return false;
    _verifyingFace = true;
    const maxAttempts = 2;
    try {
      final uid = ApiService.userId ?? (await _loadUserId());
      if (uid == null) {
        _showSnack('Sesi tidak valid, silakan login ulang.');
        return false;
      }

      int attempt = 0;
      bool verified = false;
      void Function()? closeSheet;
      final embeddingCompleter = Completer<List<double>?>();

      await _captureEmbeddingWithPreview(
        onSheetReady: (closer) => closeSheet = closer,
        onSheetClosed: () {
          if (!embeddingCompleter.isCompleted)
            embeddingCompleter.complete(null);
        },
        onEmbedding: (embedding) async {
          if (verified) return;
          attempt++;
          try {
            final res = await _faceApi.verifyFace(
              userId: uid,
              embedding: embedding,
              latitude: lat,
              longitude: lng,
            );
            final data = res.data is Map ? res.data as Map : {};
            final faceVerified =
                (data['faceVerified'] ?? data['verified'] ?? false) == true;
            if (faceVerified) {
              verified = true;
              closeSheet?.call();
              embeddingCompleter.complete(embedding);
            } else {
              debugPrint(
                '[Face] verify response not verified attempt $attempt: ${res.data}',
              );
              if (attempt >= maxAttempts) {
                closeSheet?.call();
                _showSnack('Verifikasi wajah gagal');
              }
            }
          } catch (e) {
            debugPrint('[Face] verify error attempt $attempt: $e');
            if (attempt >= maxAttempts) {
              closeSheet?.call();
              _showSnack('Verifikasi wajah gagal: $e');
            }
          }
        },
      );

      if (verified) return true;

      final lastEmbedding = await embeddingCompleter.future;
      if (lastEmbedding == null) {
        _showSnack('Wajah tidak terdeteksi. Registrasi wajah dulu.');
        await _promptEnroll();
      }
      return false;
    } finally {
      _verifyingFace = false;
    }
  }

  Future<String?> _loadUserId() async {
    await ApiService.loadSession();
    return ApiService.userId;
  }

  Future<List<double>?> _captureEmbeddingWithPreview({
    required ValueChanged<void Function()> onSheetReady,
    required VoidCallback onSheetClosed,
    required ValueChanged<List<double>> onEmbedding,
  }) {
    return showModalBottomSheet<List<double>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        onSheetReady(() => Navigator.of(ctx).pop());
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: FaceCaptureSheet(
            autoCloseOnCapture: false,
            onEmbedding: onEmbedding,
          ),
        );
      },
    ).whenComplete(onSheetClosed);
  }

  Future<void> _promptEnroll() async {
    final userId = ApiService.userId ?? (await _loadUserId());
    if (userId == null) {
      _showSnack('Sesi tidak valid, silakan login ulang.');
      return;
    }
    final enrolled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: FaceEnrollSheet(userId: userId),
      ),
    );
    if (enrolled == true) {
      _showSnack('Registrasi wajah berhasil. Coba check-in lagi.');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showSuccessDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    final textTheme = Theme.of(context).textTheme;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/success.json',
                  repeat: false,
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Transform.scale(
          scale: 0.9 + 0.1 * curved.value,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (p, c) =>
          // listen kalau ada error baru atau action message
          p.error != c.error ||
          p.actionMessage != c.actionMessage ||
          p.loading != c.loading,
      listener: (context, state) async {
        // sinkronkan state cubit ke variabel lokal: UI TETAP sama
        setState(() {
          isLoading = state.loading;
          _username = state.username;
          _timeStart = state.timeStart;
          _timeEnd = state.timeEnd;
          todayAttendances = state.todayAttendances;
          myAttendances = state.myAttendances;
          onTimeCount = state.onTimeCount;
          lateCount = state.lateCount;
        });

        if (state.error != null && state.error!.isNotEmpty) {
          await showDialog(
            context: context,
            builder: (ctx) => Dialog(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      radius: 30,
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Peringatan',
                      style: TextStyle(
                        color: Colors.blue[800],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.error!,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // bersihkan error supaya tidak muncul lagi saat rebuild
          if (context.mounted) {
            context.read<DashboardCubit>().clearTransientFlags();
          }
        }

        // Opsional: feedback sukses singkat
        if (state.actionMessage == 'checkin_ok') {
          _showSuccessDialog(
            title: 'Check-in berhasil',
            message: 'Data absensi dan wajah sudah tercatat.',
          );
          context.read<DashboardCubit>().clearTransientFlags();
        } else if (state.actionMessage == 'checkout_ok') {
          _showSuccessDialog(
            title: 'Check-out berhasil',
            message: 'Terima kasih, perjalanan pulang aman.',
          );
          context.read<DashboardCubit>().clearTransientFlags();
        }
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    final totalAttendances = onTimeCount + lateCount;
    final onTimePercentage = totalAttendances > 0
        ? (onTimeCount / totalAttendances * 100)
        : 0;
    final bool hasCheckedIn = todayAttendances.any(
      (att) => att.type == 'checkin',
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // === Header Section (Putih) ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                        image: const DecorationImage(
                          image: AssetImage("assets/images/logo-hureo.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Selamat ${_greeting()}!",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _username.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat('EEE, MMM d').format(DateTime.now()),
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === Scrollable Content ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Schedule Cards ===
                    Row(
                      children: [
                        Expanded(
                          child: _ScheduleCard(
                            icon: Icons.login_rounded,
                            title: "Jam Masuk",
                            value: _timeStart,
                            color: Colors.green.shade500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ScheduleCard(
                            icon: Icons.logout_rounded,
                            title: "Jam Pulang",
                            value: _timeEnd,
                            color: Colors.orange.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // === Statistics Card ===
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.grey.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Overview Absensi",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                color: Colors.green.shade500,
                                icon: Icons.check_circle_outline_outlined,
                                count: onTimeCount,
                                label: "On Time",
                                percentage: totalAttendances > 0
                                    ? '${(onTimeCount / totalAttendances * 100).toStringAsFixed(0)}%'
                                    : '0%',
                              ),
                              _StatItem(
                                color: Colors.orange.shade500,
                                icon: Icons.schedule_rounded,
                                count: lateCount,
                                label: "Terlambat",
                                percentage: totalAttendances > 0
                                    ? '${(lateCount / totalAttendances * 100).toStringAsFixed(0)}%'
                                    : '0%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (totalAttendances > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: onTimePercentage / 100,
                              backgroundColor: Colors.grey.shade300,
                              color: Colors.green.shade500,
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "On Time Rate",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  "${onTimePercentage.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // === Activity Header ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Aktivitas Hari Ini",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            context.read<DashboardCubit>().refresh();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Refresh",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // === Activity List ===
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue,
                            ),
                          ),
                        ),
                      )
                    else if (todayAttendances.isEmpty)
                      _buildEmptyActivity()
                    else
                      ...todayAttendances.map(
                        (attendance) => ActivityItem(
                          icon: attendance.type == 'checkin'
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          title: attendance.type == 'checkin'
                              ? "Check In"
                              : "Check Out",
                          time: _formatTime(attendance.time),
                          date: _formatDate(attendance.time),
                          status: _getStatus(attendance),
                          isCheckIn: attendance.type == 'checkin',
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // === Fixed Slider ===
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SlideAction(
                key: _sliderKey,
                borderRadius: 16,
                elevation: 0,
                outerColor: !hasCheckedIn
                    ? Colors.blue.shade500
                    : Colors.amber.shade500,
                innerColor: Colors.white,
                height: 56,
                sliderButtonIcon: Icon(
                  !hasCheckedIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: !hasCheckedIn
                      ? Colors.blue.shade500
                      : Colors.amber.shade500,
                  size: 24,
                ),
                text: !hasCheckedIn
                    ? "Geser untuk masuk"
                    : "Geser untuk pulang",
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                onSubmit: () async {
                  if (!hasCheckedIn) {
                    await _handleCheckIn();
                  } else {
                    await _handleCheckOut();
                  }
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _sliderKey.currentState?.reset();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 24,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              "Aktivitas Hari Ini Kosong",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("HH:mm").format(local);
  }

  String _formatDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("MMM dd, yyyy").format(local);
  }

  String _getStatus(Attendance attendance) {
    if (attendance.type == 'checkin') {
      return attendance.late == true ? "Terlambat" : "On Time";
    }
    return "Completed";
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Pagi";
    if (hour < 17) return "Siang";
    if (hour < 19) return "Sore";
    return "Malam";
  }
}

// ===== Schedule Card =====
class _ScheduleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Stat Item Widget =====
class _StatItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int count;
  final String label;
  final String percentage;

  const _StatItem({
    required this.color,
    required this.icon,
    required this.count,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ===== Activity Item =====
class ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String date;
  final String status;
  final bool isCheckIn;

  const ActivityItem({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    required this.date,
    required this.status,
    required this.isCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCheckIn
                  ? Colors.green.shade50
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isCheckIn ? Colors.green.shade600 : Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == "Terlambat"
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: status == "Terlambat"
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status == "Terlambat"
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
