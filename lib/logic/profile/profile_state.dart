part of 'profile_cubit.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final String username;
  final CompanyProfile? company;
  const ProfileLoaded({required this.username, required this.company});

  @override
  List<Object?> get props => [username, company];
}

class ProfileFailure extends ProfileState {
  final String message;
  const ProfileFailure(this.message);
  @override
  List<Object?> get props => [message];
}
