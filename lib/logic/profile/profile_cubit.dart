import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/profile_repository.dart';
import '../../models/company_profile.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repo;
  ProfileCubit(this.repo) : super(ProfileInitial());

  Future<void> load() async {
    emit(ProfileLoading());
    try {
      final username = await repo.getUsername();
      final company = await repo.getCompanyProfile();
      emit(ProfileLoaded(username: username, company: company));
    } catch (e) {
      emit(ProfileFailure(e.toString()));
    }
  }
}
