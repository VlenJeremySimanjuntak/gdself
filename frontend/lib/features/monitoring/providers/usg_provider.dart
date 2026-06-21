import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../models/usg_tiroid_model.dart';
import '../../../services/api_service.dart';

// ==========================================
// STATE
// ==========================================
class UsgState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final UsgTiroidModel? usgData;

  const UsgState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.usgData,
  });

  UsgState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    UsgTiroidModel? usgData,
    bool clearError = false,
  }) {
    return UsgState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      usgData: usgData ?? this.usgData,
    );
  }
}

// ==========================================
// NOTIFIER
// ==========================================
class UsgNotifier extends Notifier<UsgState> {
  @override
  UsgState build() => const UsgState();

  Future<bool> createUsgData({
    required int idRiwayat,
    required String namaRs,
    required DateTime tglPemeriksaan,
    required String catatanDokter,
    required File imageFile,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final apiService = ApiService();
      String fileName = imageFile.path.split('/').last;

      // ✅ DISESUAIKAN: Menggunakan snake_case agar seragam dengan fungsi Update/Edit
      // dan standar binding form pada Golang
      // Di usg_provider.dart
      FormData formData = FormData.fromMap({
        "id_riwayat": idRiwayat,
        "nama_rs": namaRs,
        "tgl_pemeriksaan": DateFormat('yyyy-MM-dd').format(tglPemeriksaan),
        "catatan_dokter": catatanDokter,
        "foto": await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await apiService.sendRequest.post(
        '/usg-tiroid', // Pastikan endpoint ini sesuai!
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parsing data response ke dalam UsgTiroidModel FE
        final resData = response.data['data'];
        final usgModel = UsgTiroidModel.fromJson(resData);

        state = state.copyWith(
          isLoading: false,
          isSuccess: true,
          usgData: usgModel,
        );
        return true;
      }

      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan data USG');
      return false;

    } on DioException catch (e) {
      String errorMsg = e.response?.data?['error'] ?? e.message ?? 'Terjadi kesalahan jaringan';
      state = state.copyWith(isLoading: false, errorMessage: errorMsg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Error: $e');
      return false;
    }
  }
}

// ==========================================
// PROVIDER
// ==========================================
final usgProvider = NotifierProvider<UsgNotifier, UsgState>(UsgNotifier.new);