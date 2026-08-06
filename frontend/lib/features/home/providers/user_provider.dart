import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';
import '../../../services/google_auth_service.dart';

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;
  final String? token;
  final String? baseUrl;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.token,
    this.baseUrl,
  });

  bool get isAuthenticated => user != null && token != null;

  // Token yang HANYA berubah saat foto benar-benar diganti (nama file acak
  // dari backend). Ini kunci cache yang stabil → repeat-load instan.
  String get _photoToken => user?.fotoProfil ?? '';

  // ✅ URL foto profil (cache-buster berbasis nama file, bukan timestamp)
  String? get avatarUrl {
    if (user == null || baseUrl == null) return null;
    final v = Uri.encodeComponent(_photoToken);
    return '$baseUrl/users/${user!.idUser}/avatar${v.isEmpty ? '' : '?v=$v'}';
  }

  // ✅ Cache key stabil untuk CachedNetworkImage
  String? get avatarCacheKey {
    if (user == null) return null;
    return 'avatar_${user!.idUser}_$_photoToken';
  }

  // ✅ Header untuk request gambar (NetworkImage/CachedNetworkImage TIDAK lewat
  // Dio, jadi ngrok-skip harus disisipkan manual di sini).
  Map<String, String>? get authHeaders {
    if (token == null) return null;
    return {
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
    String? token,
    String? baseUrl,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      token: token ?? this.token,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }
}

class UserNotifier extends Notifier<AuthState> {
  late final ApiService _api;

  @override
  AuthState build() {
    _api = ApiService();
    return const AuthState();
  }

  void _updateStateWithUserAndToken(UserModel user) {
    state = state.copyWith(
      user: user,
      token: _api.token,
      baseUrl: _api.baseUrl,
      isLoading: false,
      clearError: true,
    );
  }

  void setUser(UserModel user) {
    _updateStateWithUserAndToken(user);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _api.login(email, password);
      _updateStateWithUserAndToken(user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Return: 'success' | 'new_user' | 'error'
  Future<Map<String, dynamic>> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleService = GoogleAuthService();
      final idToken = await googleService.signIn();

      if (idToken == null) {
        state = state.copyWith(isLoading: false, clearError: true);
        return {'status': 'cancelled'};
      }

      final result = await _api.googleCheck(idToken);
      final bool isNewUser = result['is_new_user'] ?? false;

      if (isNewUser) {
        state = state.copyWith(isLoading: false);
        return {
          'status': 'new_user',
          'id_token': idToken,
          'google_email': result['google_email'] ?? '',
          'google_name': result['google_name'] ?? '',
          'google_photo': result['google_photo'] ?? '',
        };
      }

      final token = result['token'] ?? '';
      final userData = result['user'];

      if (token.isNotEmpty && userData != null) {
        final user = UserModel.fromJson(userData as Map<String, dynamic>);
        await _api.saveSessionFromGoogle(token, user);
        _updateStateWithUserAndToken(user);
        return {'status': 'success'};
      }

      state = state.copyWith(
          isLoading: false, errorMessage: "Gagal login dengan Google.");
      return {'status': 'error'};
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Gagal masuk dengan Google: ${e.toString()}",
      );
      return {'status': 'error'};
    }
  }

  Future<bool> completeGoogleRegister({
    required String idToken,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _api.googleComplete(
        idToken: idToken,
        password: password,
        jenisKelamin: jenisKelamin,
        tglLahir: tglLahir,
        tglTerdiagnosis: tglTerdiagnosis,
      );
      _updateStateWithUserAndToken(user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
      final user = await _api.register(
        nama: nama,
        email: email,
        password: password,
        jenisKelamin: jenisKelamin,
        tglLahir: tglLahir,
        tglTerdiagnosis: tglTerdiagnosis,
      );
      _updateStateWithUserAndToken(user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint(
          '⚠️ Google SignOut gagal (mungkin tidak tersedia di platform ini): $e');
    }
    state = const AuthState();
  }

  Future<void> refreshUser(int userId) async {
    try {
      final response = await _api.get('/users/$userId');
      if (response.statusCode == 200) {
        final userData = response.data['data'];
        if (userData != null) {
          final updatedUser =
          UserModel.fromJson(userData as Map<String, dynamic>);
          await _api.saveSessionFromGoogle(_api.token, updatedUser);
          _updateStateWithUserAndToken(updatedUser);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Gagal refresh user: $e');
    }
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