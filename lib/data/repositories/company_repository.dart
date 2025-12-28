import '../../services/api_service.dart';

class CompanyRepository {
  const CompanyRepository();

  /// return ['time_start': 'HH:mm', 'time_end': 'HH:mm'] atau {}
  Future<Map<String, String>> getCompanyHours() async {
    return await ApiService.getCompanyHours();
  }
}
