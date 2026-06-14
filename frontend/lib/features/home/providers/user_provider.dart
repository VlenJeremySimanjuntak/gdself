import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../services/google_auth_service.dart';

// ----------------------------------------------------------------
// State
// ----------------------------------------------------------------
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
    bool clearUser  = false,
  }) {
    return AuthState(
      isLoading:    isLoading ?? this.isLoading,
      user:         clearUser  ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ----------------------------------------------------------------
// Notifier (Riverpod v2/v3 style)
// ----------------------------------------------------------------
class UserNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Restore session saat pertama kali provider dibuat
    Future.microtask(() => restoreSession());
    return const AuthState();
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

  // 👇 METHOD BARU UNTUK GOOGLE SIGN-IN
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Ambil ID Token dari Google
      final googleService = GoogleAuthService();
      final idToken = await googleService.signIn();

      // Jika user menutup pop-up akun Google (batal memilih)
      if (idToken == null) {
        state = state.copyWith(isLoading: false, errorMessage: "Google Sign-In dibatalkan.");
        return false;
      }

      // 2. Kirim token tersebut ke backend Golang melalui ApiService
      final user = await ApiService().loginWithGoogle(idToken);

      // 3. Update state menjadi sukses login
      state = AuthState(user: user);
      return true;

    } catch (e) {
      // Tangkap error jika validasi token di backend gagal atau masalah jaringan
      state = state.copyWith(isLoading: false, errorMessage: "Gagal masuk dengan Google: ${e.toString()}");
      return false;
    }
  }
  // 👆 BATAS METHOD BARU

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
        nama:            nama,
        email:           email,
        password:        password,
        jenisKelamin:    jenisKelamin,
        tglLahir:        tglLahir,
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
    // 1. Hapus token dari memori lokal / secure storage
    // authService.logout() atau hapus shared preferences Anda

    // 👇 2. TAMBAHKAN BARIS INI UNTUK LOGOUT DARI GOOGLE
    final GoogleSignIn googleSignIn = GoogleSignIn();
    await googleSignIn.signOut(); // Ini yang akan mereset ingatan Google

    // 3. Arahkan user kembali ke halaman Login
  }

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true);
    final hasSession = await ApiService().restoreSession();
    state = state.copyWith(isLoading: false, clearUser: !hasSession);
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

// ----------------------------------------------------------------
// Provider
// ----------------------------------------------------------------
final userProvider = NotifierProvider<UserNotifier, AuthState>(
  UserNotifier.new,
);