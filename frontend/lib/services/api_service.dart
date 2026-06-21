import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _loadToken();
  }

  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'cached_user';
  static const _secureStorage = FlutterSecureStorage();

  String? _token;
  //192.168.50.45
  //gdself-production.up.railway.app

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://gdself-production.up.railway.app/api',
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  Dio get sendRequest => _dio;

  String _addPrefix(String endpoint) {
    return endpoint.startsWith('/') ? endpoint : '/$endpoint';
  }

  // ── Token helpers ─────────────────────────────────────────────────────────
  Future<void> _loadToken() async {
    _token = await _secureStorage.read(key: _tokenKey);
    if (_token != null) _setAuthHeader(_token!);
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
    final raw = await _secureStorage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJsonString(raw);
    } catch (_) {
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal login';
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal Google Login';
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal register';
    }
  }

  // ── Session & Logout ──────────────────────────────────────────────────────
  Future<UserModel?> restoreSession() async {
    await _loadToken();
    if (!isAuthenticated) return null;
    return await _loadUser();
  }

  Future<void> logout() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal kirim OTP';
    }
  }

  Future<void> verifyOTP(String email, String code, String type) async {
    try {
      await _dio.post(
        _addPrefix('/auth/verify-otp'),
        data: {'email': email, 'code': code, 'type': type},
      );
    } on DioException catch (e) {
      throw e.response?.data?['error'] ?? e.message ?? 'OTP tidak valid';
    }
  }

  // ── Google Check (baru) ───────────────────────────────────────────────────
  /// Return Map: {is_new_user, token?, user?, google_email?, google_name?, google_photo?}
  Future<Map<String, dynamic>> googleCheck(String idToken) async {
    try {
      final response = await _dio.post(
        _addPrefix('/auth/google/check'),
        data: {'id_token': idToken},
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal cek akun Google';
    }
  }

  /// Selesaikan registrasi user Google baru
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal menyelesaikan registrasi';
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal kirim email reset';
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
      throw e.response?.data?['error'] ?? e.message ?? 'Gagal reset password';
    }
  }

  // ── Generic Helpers ───────────────────────────────────────────────────────
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(_addPrefix(endpoint), data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal POST';
    }
  }

  Future<Response> get(String endpoint) async {
    try {
      return await _dio.get(_addPrefix(endpoint));
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal GET';
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(_addPrefix(endpoint), data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal PUT';
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(_addPrefix(endpoint));
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal DELETE';
    }
  }

  void _handleAuthError(DioException e) {
    if (e.response?.statusCode == 401) logout();
  }
}