import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

// ----------------------------------------------------------------
// State
// ----------------------------------------------------------------
class ApiState {
  final bool isLoading;
  final String? errorMessage;
  final dynamic data;

  const ApiState({
    this.isLoading = false,
    this.errorMessage,
    this.data,
  });

  ApiState copyWith({
    bool? isLoading,
    String? errorMessage,
    dynamic data,
    bool clearError = false,
  }) {
    return ApiState(
      isLoading:    isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      data:         data ?? this.data,
    );
  }
}

// ----------------------------------------------------------------
// Notifier (Riverpod v2/v3 style)
// ----------------------------------------------------------------
class ApiNotifier extends Notifier<ApiState> {
  @override
  ApiState build() => const ApiState();

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiService().post(endpoint, data: body);
      state = ApiState(data: response.data);
      return response.data;
    } catch (e) {
      state = ApiState(errorMessage: e.toString());
      return null;
    }
  }

  Future<dynamic> get(String endpoint) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await ApiService().get(endpoint);
      state = ApiState(data: response.data);
      return response.data;
    } catch (e) {
      state = ApiState(errorMessage: e.toString());
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

// ----------------------------------------------------------------
// Provider
// ----------------------------------------------------------------
final apiProvider = NotifierProvider<ApiNotifier, ApiState>(
  ApiNotifier.new,
);