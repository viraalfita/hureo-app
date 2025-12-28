import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../services/api_service.dart';

class AuthRepository {
  const AuthRepository();

  Future<User> login(
    String username,
    String password,
    String companyCode,
  ) async {
    final ok = await ApiService.login(username, password, companyCode);
    if (!ok) {
      throw Exception('Login gagal: kredensial/response tidak valid');
    }

    // username & id disimpan saat login() di ApiService
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId') ?? ApiService.userId ?? '';
    final uname = prefs.getString('username') ?? username;

    if (uid.isEmpty) throw Exception('Login gagal: userId kosong');
    return User(id: uid, username: uname);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('username');
    await prefs.remove('companyCode');
    await prefs.remove('deviceTimezone');
    await ApiService.logout();
  }

  Future<User?> restoreSession() async {
    await ApiService.loadSession();
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId');
    final uname = prefs.getString('username');
    if (uid != null && uname != null) {
      return User(id: uid, username: uname);
    }
    return null;
  }
}
