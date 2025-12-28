import 'package:shared_preferences/shared_preferences.dart';

import '../../models/company_profile.dart';
import '../../services/api_service.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("username") ?? "Unknown";
  }

  Future<CompanyProfile?> getCompanyProfile() async {
    final data =
        await ApiService.getCompanyProfile(); // sudah handle token/companyCode di ApiService
    if (data.isEmpty) return null;
    return CompanyProfile.fromJson(data);
  }
}
