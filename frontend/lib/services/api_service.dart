import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../main.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _loadToken();

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.headers['ngrok-skip-browser-warning'] = 'true';

        String? token;
        try {
          token = await _secureStorage.read(key: _tokenKey);
        } catch (e) {
          debugPrint('⚠️ Gagal baca token dari secure storage (interceptor): $e');
          await _clearCorruptedStorage();
        }

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'cached_user';
  static const _secureStorage = FlutterSecureStorage();

  String? _token;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://engaged-kick-utilize.ngrok-free.dev/api',
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  Dio get sendRequest => _dio;

  // =======================================================================
  // ✅ TAMBAHAN BARU: Helper untuk mempermudah UI mengambil URL & Token
  // =======================================================================
  String get baseUrl => _dio.options.baseUrl;
  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};
  // =======================================================================

  String _addPrefix(String endpoint) {
    return endpoint.startsWith('/') ? endpoint : '/$endpoint';
  }

  // ── Token helpers ─────────────────────────────────────────────────────────
  Future<void> _loadToken() async {
    try {
      _token = await _secureStorage.read(key: _tokenKey);
      if (_token != null) _setAuthHeader(_token!);
    } catch (e) {
      debugPrint('⚠️ Gagal load token (kemungkinan data terenkripsi corrupt): $e');
      await _clearCorruptedStorage();
      _token = null;
    }
  }

  Future<void> _clearCorruptedStorage() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('🧹 Secure storage yang corrupt sudah dibersihkan.');
    } catch (e) {
      debugPrint('⚠️ Gagal membersihkan secure storage: $e');
    }
  }

  void _setAuthHeader(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';
  void _clearAuthHeader() => _dio.options.headers.remove('Authorization');

  String get token => _token ?? '';
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  // ── User cache helpers ────────────────────────────────────────────────────
  Future<void> _saveUser(UserModel user) async {
    await _secureStorage.write(key: _userKey, value: user.toJsonString());
  }

  Future<UserModel?> _loadUser() async {
    try {
      final raw = await _secureStorage.read(key: _userKey);
      if (raw == null) return null;
      return UserModel.fromJsonString(raw);
    } catch (e) {
      debugPrint('⚠️ Gagal load user dari storage: $e');
      return null;
    }
  }

  // ✅ Dipanggil dari user_provider saat Google existing user login
  Future<void> saveSessionFromGoogle(String token, UserModel user) async {
    _token = token;
    await _secureStorage.write(key: _tokenKey, value: token);
    await _saveUser(user);
    _setAuthHeader(token);
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        _addPrefix('/login'),
        data: {'email': email, 'password': password},
      );
      final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      await _saveUser(auth.user);
      _setAuthHeader(_token!);
      return auth.user;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Google Login (lama — tidak dipakai lagi, tapi tetap ada) ─────────────
  Future<UserModel> loginWithGoogle(String idToken) async {
    try {
      final response = await _dio.post(
        _addPrefix('/auth/google'),
        data: {'id_token': idToken},
      );
      final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      await _saveUser(auth.user);
      _setAuthHeader(_token!);
      return auth.user;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<UserModel> register({
    required String nama,
    required String email,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    try {
      final response = await _dio.post(
        _addPrefix('/users'),
        data: {
          'nama': nama,
          'email': email,
          'password': password,
          'jenis_kelamin': jenisKelamin,
          if (tglLahir != null) 'tgl_lahir': tglLahir,
          if (tglTerdiagnosis != null) 'tgl_terdiagnosis': tglTerdiagnosis,
        },
      );
      final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      await _saveUser(auth.user);
      _setAuthHeader(_token!);
      return auth.user;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Session & Logout ──────────────────────────────────────────────────────
  Future<UserModel?> restoreSession() async {
    await _loadToken();
    if (!isAuthenticated) return null;

    final cachedUser = await _loadUser();
    if (cachedUser == null) return null;

    try {
      await _dio.get(_addPrefix('/users/${cachedUser.idUser}'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        return null;
      }
      // Kalau errornya bukan 401 (misal koneksi/ngrok mati),
      // tetap pakai cached user supaya app tidak macet,
      // tapi kita log pesan ramahnya untuk keperluan debug.
      debugPrint('⚠️ restoreSession gagal validasi ke server: ${_extractError(e)}');
    }

    return cachedUser;
  }

  Future<void> logout() async {
    _token = null;
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _userKey);
    } catch (e) {
      debugPrint('⚠️ Gagal hapus token saat logout: $e');
    }
    _clearAuthHeader();
  }

  // ── OTP ───────────────────────────────────────────────────────────────────
  Future<void> sendOTP(String email, String type) async {
    try {
      await _dio.post(
        _addPrefix('/auth/send-otp'),
        data: {'email': email, 'type': type},
      );
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<void> verifyOTP(String email, String code, String type) async {
    try {
      await _dio.post(
        _addPrefix('/auth/verify-otp'),
        data: {'email': email, 'code': code, 'type': type},
      );
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Google Check (baru) ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> googleCheck(String idToken) async {
    try {
      final response = await _dio.post(
        _addPrefix('/auth/google/check'),
        data: {'id_token': idToken},
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<UserModel> googleComplete({
    required String idToken,
    required String password,
    required String jenisKelamin,
    String? tglLahir,
    String? tglTerdiagnosis,
  }) async {
    try {
      final response = await _dio.post(
        _addPrefix('/auth/google/complete'),
        data: {
          'id_token': idToken,
          'password': password,
          'jenis_kelamin': jenisKelamin,
          if (tglLahir != null) 'tgl_lahir': tglLahir,
          if (tglTerdiagnosis != null) 'tgl_terdiagnosis': tglTerdiagnosis,
        },
      );
      final auth = AuthResponse.fromJson(response.data as Map<String, dynamic>);
      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      await _saveUser(auth.user);
      _setAuthHeader(_token!);
      return auth.user;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Forgot / Reset Password ───────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        _addPrefix('/auth/forgot-password'),
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        _addPrefix('/auth/reset-password'),
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Generic Helpers ───────────────────────────────────────────────────────
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(_addPrefix(endpoint), data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw _extractError(e);
    }
  }

  Future<Response> get(String endpoint) async {
    try {
      return await _dio.get(_addPrefix(endpoint));
    } on DioException catch (e) {
      _handleAuthError(e);
      throw _extractError(e);
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(_addPrefix(endpoint), data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw _extractError(e);
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(_addPrefix(endpoint));
    } on DioException catch (e) {
      _handleAuthError(e);
      throw _extractError(e);
    }
  }

  void _handleAuthError(DioException e) {
    if (e.response?.statusCode == 401) {
      logout();
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
            (route) => false,
      );
    }
  }

  dynamic _extractError(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg;
      }
    }

    return ErrorHandler.getFriendlyMessage(e);
  }
}

// ============================================================================
// ✅ ERROR HANDLER: Menerjemahkan Error Teknis Menjadi Bahasa Formal & Lugas
// ============================================================================
class ErrorHandler {
  static String getFriendlyMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return "Proses memuat data tertunda. Silakan coba lagi saat koneksi lebih stabil.";

        case DioExceptionType.connectionError:
          return "Koneksi ke server terputus. Silakan periksa jaringan Anda dan coba muat ulang halaman ini.";

        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;

          if (statusCode == 404) {
            return "Informasi yang Anda cari belum tersedia saat ini. Silakan kembali ke Beranda atau coba muat ulang halaman.";
          } else if (statusCode != null && statusCode >= 500) {
            return "Terjadi kendala pada sistem kami. Silakan coba beberapa saat lagi.";
          }
          return "Terjadi kendala dalam menampilkan data. Silakan coba lagi nanti.";

        case DioExceptionType.cancel:
          return "Permintaan memuat data dibatalkan.";

        default:
          return "Terjadi kesalahan yang tidak terduga. Silakan muat ulang halaman ini.";
      }
    }

    return "Terjadi kendala pada aplikasi. Silakan coba beberapa saat lagi.";
  }
}