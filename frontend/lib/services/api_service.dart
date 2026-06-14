import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart'; // sesuaikan path jika perlu

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _loadToken();
  }

  static const String _tokenKey = 'jwt_token';
  static const _secureStorage   = FlutterSecureStorage();

  String? _token;

  final Dio _dio = Dio(
    BaseOptions(
      // Emulator Android  : http://10.0.2.2:3000/api
      // Perangkat fisik   : http://<IP-komputer>:3000/api
      // Production        : https://api.domain.com/api
      // Flatter           : 10.237.131.129
      // HW Mahasiswa      : 172.27.65.129
      baseUrl: 'http://172.29.192.1:3000/api',
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
      headers: {
        'Content-Type': 'application/json',
        'Accept':       'application/json',
      },
    ),
  );

  // Expose Dio instance jika dibutuhkan
  Dio get sendRequest => _dio;

  // ----------------------------------------------------------------
  // Token helpers
  // ----------------------------------------------------------------
  Future<void> _loadToken() async {
    _token = await _secureStorage.read(key: _tokenKey);
    if (_token != null) _setAuthHeader(_token!);
  }

  void _setAuthHeader(String token) =>
      _dio.options.headers['Authorization'] = 'Bearer $token';

  void _clearAuthHeader() =>
      _dio.options.headers.remove('Authorization');

  String get token          => _token ?? '';
  bool   get isAuthenticated => _token != null && _token!.isNotEmpty;

  // ----------------------------------------------------------------
  // LOGIN  →  POST /login
  // ----------------------------------------------------------------
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      final auth = AuthResponse.fromJson(
          response.data as Map<String, dynamic>);

      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      _setAuthHeader(_token!);

      return auth.user;
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['error'];
      throw serverMsg ?? e.message ?? 'Gagal terhubung ke server';
    }
  }

  // 👇 -------------------------------------------------------------
  // GOOGLE LOGIN  →  POST /auth/google (Sesuaikan dengan backend Anda)
  // ----------------------------------------------------------------
  Future<UserModel> loginWithGoogle(String idToken) async {
    try {
      // Pastikan endpoint ini cocok dengan route di Golang Anda
      // Jika di Golang Anda route-nya `/api/google`, ganti menjadi `/google`
      final response = await _dio.post(
        '/auth/google',
        data: {'id_token': idToken},
      );

      final auth = AuthResponse.fromJson(
          response.data as Map<String, dynamic>);

      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      _setAuthHeader(_token!);

      return auth.user;
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['error'];
      throw serverMsg ?? e.message ?? 'Gagal verifikasi Google ke server';
    }
  }
  // 👆 -------------------------------------------------------------

  // ----------------------------------------------------------------
  // REGISTER  →  POST /users
  // ----------------------------------------------------------------
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
        '/users',
        data: {
          'nama':           nama,
          'email':          email,
          'password':       password,
          'jenis_kelamin':  jenisKelamin,
          if (tglLahir        != null) 'tgl_lahir':        tglLahir,
          if (tglTerdiagnosis != null) 'tgl_terdiagnosis': tglTerdiagnosis,
        },
      );

      final auth = AuthResponse.fromJson(
          response.data as Map<String, dynamic>);

      _token = auth.token;
      await _secureStorage.write(key: _tokenKey, value: _token!);
      _setAuthHeader(_token!);

      return auth.user;
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['error'];
      throw serverMsg ?? e.message ?? 'Gagal terhubung ke server';
    }
  }

  // ----------------------------------------------------------------
  // LOGOUT
  // ----------------------------------------------------------------
  Future<void> logout() async {
    _token = null;
    await _secureStorage.delete(key: _tokenKey);
    _clearAuthHeader();
  }

  // ----------------------------------------------------------------
  // Restore session saat app start (panggil di main.dart)
  // ----------------------------------------------------------------
  Future<bool> restoreSession() async {
    await _loadToken();
    return isAuthenticated;
  }

  // ----------------------------------------------------------------
  // Generic helpers (dengan auto Bearer token)
  // ----------------------------------------------------------------
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal terhubung ke server';
    }
  }

  Future<Response> get(String endpoint) async {
    try {
      return await _dio.get(endpoint);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal terhubung ke server';
    }
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    try {
      return await _dio.put(endpoint, data: data);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal terhubung ke server';
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      return await _dio.delete(endpoint);
    } on DioException catch (e) {
      _handleAuthError(e);
      throw e.message ?? 'Gagal terhubung ke server';
    }
  }

  // Auto logout jika token expired (401)
  void _handleAuthError(DioException e) {
    if (e.response?.statusCode == 401) logout();
  }
}