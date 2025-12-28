part of 'dashboard_cubit.dart';

class DashboardState extends Equatable {
  final bool loading;
  final String? error;

  final String username;
  final String timeStart;
  final String timeEnd;

  final List<Attendance> todayAttendances;
  final List<Attendance> myAttendances;

  final int onTimeCount;
  final int lateCount;

  /// penanda singkat setelah aksi (checkin_ok, checkout_ok, *_fail)
  final String? actionMessage;

  const DashboardState({
    required this.loading,
    required this.error,
    required this.username,
    required this.timeStart,
    required this.timeEnd,
    required this.todayAttendances,
    required this.myAttendances,
    required this.onTimeCount,
    required this.lateCount,
    required this.actionMessage,
  });

  const DashboardState.initial()
    : loading = true,
      error = null,
      username = '',
      timeStart = '',
      timeEnd = '',
      todayAttendances = const [],
      myAttendances = const [],
      onTimeCount = 0,
      lateCount = 0,
      actionMessage = null;

  DashboardState copyWith({
    bool? loading,
    String? error,
    String? username,
    String? timeStart,
    String? timeEnd,
    List<Attendance>? todayAttendances,
    List<Attendance>? myAttendances,
    int? onTimeCount,
    int? lateCount,
    String? actionMessage, // bisa null untuk clear
  }) {
    return DashboardState(
      loading: loading ?? this.loading,
      error: error,
      username: username ?? this.username,
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      todayAttendances: todayAttendances ?? this.todayAttendances,
      myAttendances: myAttendances ?? this.myAttendances,
      onTimeCount: onTimeCount ?? this.onTimeCount,
      lateCount: lateCount ?? this.lateCount,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    error,
    username,
    timeStart,
    timeEnd,
    todayAttendances,
    myAttendances,
    onTimeCount,
    lateCount,
    actionMessage,
  ];
}
