import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/auth_repository.dart';
import '../../models/user.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository repo;
  AuthCubit(this.repo) : super(AuthInitial());

  Future<void> restore() async {
    emit(AuthLoading());
    final u = await repo.restoreSession();
    emit(u != null ? AuthAuthenticated(u) : AuthLoggedOut());
  }

  Future<void> login(
    String username,
    String password,
    String companyCode,
  ) async {
    emit(AuthLoading());
    try {
      final u = await repo.login(username, password, companyCode);
      emit(AuthAuthenticated(u));
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> logout() async {
    await repo.logout();
    emit(AuthLoggedOut());
  }
}
