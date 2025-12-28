import 'package:attendance/data/repositories/company_repository.dart';
import 'package:attendance/data/repositories/profile_repository.dart';
import 'package:attendance/logic/dashboard/dashboard_cubit.dart';
import 'package:attendance/logic/profile/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/attendance_repository.dart';
// Repos
import 'data/repositories/auth_repository.dart';
import 'data/repositories/leave_repository.dart';
import 'logic/attendance/attendance_cubit.dart';
// Cubits
import 'logic/auth/auth_cubit.dart';
import 'logic/leave/leave_cubit.dart';
import 'pages/login_page.dart';
import 'pages/login_success_page.dart';
import 'pages/main_page.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => const AuthRepository()),
        RepositoryProvider(create: (_) => const AttendanceRepository()),
        RepositoryProvider(create: (_) => const LeaveRepository()),
        RepositoryProvider(create: (_) => const CompanyRepository()),
        RepositoryProvider(create: (_) => const ProfileRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (ctx) => AuthCubit(ctx.read<AuthRepository>())..restore(),
          ),
          BlocProvider(
            create: (ctx) => AttendanceCubit(ctx.read<AttendanceRepository>()),
          ),
          BlocProvider(
            create: (ctx) => LeaveCubit(ctx.read<LeaveRepository>()),
          ),
          BlocProvider(
            create: (ctx) => ProfileCubit(ctx.read<ProfileRepository>()),
          ),
          BlocProvider(
            create: (ctx) => DashboardCubit(
              attendanceRepo: ctx.read<AttendanceRepository>(),
              companyRepo: ctx.read<CompanyRepository>(),
              profileRepo: ctx.read<ProfileRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Attendance App',
          theme: ThemeData(
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.grey[100],
              foregroundColor: const Color.fromRGBO(0, 0, 0, 0.867),
              elevation: 0,
              centerTitle: true,
            ),
            cardColor: Colors.white,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey[100],
          ),
          debugShowCheckedModeBanner: false,
          initialRoute: "/",
          routes: {
            "/": (_) => const RootGate(),
            "/login": (_) => const LoginPage(),
            "/main": (_) => const MainPage(),
            "/login-success": (_) => const LoginSuccessPage(),
          },
        ),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (_, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const SplashPage();
        }
        if (state is AuthAuthenticated) {
          return const MainPage();
        }
        return const LoginPage();
      },
    );
  }
}
