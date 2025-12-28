import 'package:meta/meta.dart';

@immutable
class AuthDto {
  final String accessToken;
  final String userId;
  final String username;

  const AuthDto({
    required this.accessToken,
    required this.userId,
    required this.username,
  });

  factory AuthDto.fromJson(Map<String, dynamic> j) => AuthDto(
    accessToken: j['token'] ?? '',
    userId: j['user']?['_id']?.toString() ?? '',
    username: j['user']?['username'] ?? '',
  );
}
