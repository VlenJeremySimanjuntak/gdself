import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../services/google_auth_service.dart';

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UserNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void setUser(UserModel user) {
    state = AuthState(user: user);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ApiService().login(email, password);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(errorMessage: e.toString());
      return false;
    }
  }

  /// Return: 'success' | 'new_user' | 'error'
  /// Kalau 'new_user', caller harus buka GoogleCompleteRegisterScreen
  Future<Map<String, dynamic>> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleService = GoogleAuthService();
      final idToken = await googleService.signIn();

      if (idToken == null) {
        state = state.copyWith(isLoading: false, errorMessage: "Google Sign-In dibatalkan.");
        return {'status': 'cancelled'};
      }

      // Cek ke backend apakah user sudah ada atau belum
      final result = await ApiService().googleCheck(idToken);
      final bool isNewUser = result['is_new_user'] ?? false;

      if (isNewUser) {
        // User baru — kembalikan data Google untuk pre-fill form
        state = state.copyWith(isLoading: false);
        return {
          'status': 'new_user',
          'id_token': idToken,
          'google_email': result['google_email'] ?? '',
          'google_name': result['google_name'] ?? '',
          'google_photo': result['google_photo'] ?? '',
        };
      }

      // User sudah ada — login langsung
      // Backend sudah return token di response googleCheck untuk existing user
      final token = result['token'] ?? '';
      final userData = result['user'];

      if (token.isNotEmpty && userData != null) {
        final user = UserModel.fromJson(userData as Map<String, dynamic>);
        // Simpan token dan user ke storage
        await ApiService().saveSessionFromGoogle(token, user);
        state = AuthState(user: user);
        return {'status': 'success'};
      }

      state = state.copyWith(isLoading: false, errorMessage: "Gagal login dengan Google.");
      return {'status': 'error'};
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Gagal masuk dengan Google: ${e.toString()}",
      );
      return {'status': 'error'};
    }
  }

  /// Selesaikan registrasi Google user baru
  Future<bool> completeGoogleRegister({
    required String idToken,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ApiService().googleComplete(
        idToken: idToken,
        password: password,
        jenisKelamin: jenisKelamin,
        tglLahir: tglLahir,
        tglTerdiagnosis: tglTerdiagnosis,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String nama,
    required String email,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await ApiService().register(
        nama: nama,
        email: email,
        password: password,
        jenisKelamin: jenisKelamin,
        tglLahir: tglLahir,
        tglTerdiagnosis: tglTerdiagnosis,
      );
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService().logout();
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
    state = const AuthState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, AuthState>(
  UserNotifier.new,
);