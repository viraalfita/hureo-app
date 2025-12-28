import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;
  final String companyCode;
  const AuthLoginRequested(this.username, this.password, this.companyCode);
  @override
  List<Object?> get props => [username, password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthRestoreRequested extends AuthEvent {}
