import 'package:gdself/services/api_service.dart';

class AssessmentService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> assess({
    required Map<String, dynamic> lab,
    dynamic prevLab,
    required Map<String, dynamic> wearable,
    required bool isLabDay,
  }) async {
    try {
      final response = await _api.post(
        '/assess',
        data: {
          "lab": lab,
          "prev_lab": prevLab,           // ← snake_case
          "wearable": wearable,
          "is_lab_day": isLabDay,        // ← snake_case
        },
      );

      // Return hanya bagian 'data' dari response
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map && responseData.containsKey('data')) {
          return responseData['data'] as Map<String, dynamic>;
        }
        return responseData as Map<String, dynamic>;
      }

      throw Exception('Failed to assess: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}
