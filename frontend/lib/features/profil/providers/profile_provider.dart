import 'package:dio/dio.dart'; // 👇 Wajib untuk FormData dan MultipartFile
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';

// --- 1. STATE UNTUK PROFIL ---
class ProfileState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? profileData;

  ProfileState({
    this.isLoading = false,
    this.errorMessage,
    this.profileData,
  });

  ProfileState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? profileData,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      profileData: profileData ?? this.profileData,
    );
  }
}

// --- 2. NOTIFIER (LOGIKA UTAMA) ---
class ProfileNotifier extends Notifier<ProfileState> {
  final ApiService _apiService = ApiService();

  @override
  ProfileState build() {
    return ProfileState();
  }

  // 👇 FUNGSI GET: Mengambil data profil dari Backend
  Future<void> fetchProfile(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.get('/users/$userId');

      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          profileData: response.data['data'],
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: "Gagal memuat data profil");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // 👇 FUNGSI PUT/POST: Menyimpan perubahan data teks profil ke Backend
  Future<bool> updateProfile(int userId, Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.put('/users/$userId', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Tarik ulang data TERBARU setelah berhasil update
        await fetchProfile(userId);
        return true;
      } else {
        state = state.copyWith(
            isLoading: false,
            errorMessage: response.data['message'] ?? "Gagal memperbarui profil"
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan jaringan: $e");
      return false;
    }
  }

  // 👇 FUNGSI BARU UNTUK UPLOAD FOTO PROFIL
  Future<bool> uploadAvatar(int userId, String imagePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Bungkus file gambar ke dalam format FormData (Multipart)
      FormData formData = FormData.fromMap({
        // "avatar" disesuaikan dengan key form-data di API Golang Anda
        "avatar": await MultipartFile.fromFile(imagePath, filename: "profile_image.jpg"),
      });

      // 2. Panggil API upload (Sesuaikan rute endpoint-nya)
      final response = await _apiService.post('/users/$userId/avatar', data: formData);

      // 3. Cek apakah berhasil
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Tarik ulang data profil agar URL foto terbaru langsung masuk ke state
        await fetchProfile(userId);
        return true;
      } else {
        state = state.copyWith(
            isLoading: false,
            errorMessage: response.data['message'] ?? "Gagal mengunggah foto profil"
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan saat upload foto: $e");
      return false;
    }
  }

  // ==========================================================================
  // ✅ BARU: HAPUS AKUN (Account Deletion)
  // ==========================================================================

  // 👇 Langkah 1: Minta kode OTP konfirmasi hapus akun (dikirim ke email user)
  Future<bool> requestDeleteOtp(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.post('/users/$userId/account/request-otp');

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isLoading: false);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: (response.data is Map)
            ? (response.data['message'] ?? "Gagal mengirim kode konfirmasi")
            : "Gagal mengirim kode konfirmasi",
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _extractError(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan jaringan: $e");
      return false;
    }
  }

  // 👇 Langkah 2: Eksekusi hapus akun permanen.
  // Butuh body { code, confirmation }, jadi pakai sendRequest (Dio) langsung
  // karena helper delete() bawaan ApiService tidak mengirim body.
  Future<bool> deleteAccount(
      int userId, {
        required String code,
        required String confirmation,
      }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.sendRequest.delete(
        '/users/$userId/account',
        data: {
          'code': code,
          'confirmation': confirmation,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        state = state.copyWith(isLoading: false);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: (response.data is Map)
            ? (response.data['message'] ?? "Gagal menghapus akun")
            : "Gagal menghapus akun",
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _extractError(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan jaringan: $e");
      return false;
    }
  }

  // Helper kecil: ambil pesan error ramah dari DioException
  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString();
      }
    }
    return "Terjadi kesalahan. Silakan coba lagi.";
  }
}

// --- 3. PROVIDER INSTANCE ---
final profileProvider = NotifierProvider<ProfileNotifier, ProfileState>(() {
  return ProfileNotifier();
});