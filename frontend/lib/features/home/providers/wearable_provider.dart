import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';
import '../../../models/wearable_model.dart'; // ✅ WAJIB ADA

// =======================================================
// 1. STATE CLASS
// =======================================================
class WearableState {
  final bool isLoading;
  final String? errorMessage;
  final List<WearableModel> wearableData; // ✅ DIKEMBALIKAN

  const WearableState({
    this.isLoading = false,
    this.errorMessage,
    this.wearableData = const [],
  });

  WearableState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<WearableModel>? wearableData,
  }) {
    return WearableState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Jika null, error akan hilang saat sukses
      wearableData: wearableData ?? this.wearableData,
    );
  }
}

// =======================================================
// 2. NOTIFIER
// =======================================================
class WearableNotifier extends Notifier<WearableState> {
  final _apiService = ApiService();

  @override
  WearableState build() => const WearableState();

  // =====================================================
  // METHOD: FETCH WEARABLE DATA (DIKEMBALIKAN UTUH)
  // =====================================================
  Future<void> fetchWearableData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.get('/wearable/user/$userId');

      if (response.data['data'] != null && response.data['data'] is List) {
        final List<dynamic> data = response.data['data'];
        final List<WearableModel> wearableList = data
            .map((json) => WearableModel.fromJson(json as Map<String, dynamic>))
            .toList();

        state = state.copyWith(isLoading: false, wearableData: wearableList);
      } else {
        state = state.copyWith(isLoading: false, wearableData: [], errorMessage: 'Data wearable belum tersedia');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, wearableData: [], errorMessage: 'Belum ada data aktivitas');
    }
  }

  Future<void> fetchWearableDataByDateRange(int userId, DateTime startDate, DateTime endDate) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final formattedStart = startDate.toIso8601String().split('T').first;
      final formattedEnd = endDate.toIso8601String().split('T').first;

      final response = await _apiService.get(
        '/wearable/user/$userId?start_date=$formattedStart&end_date=$formattedEnd',
      );

      if (response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        final List<WearableModel> wearableList = data
            .map((json) => WearableModel.fromJson(json as Map<String, dynamic>))
            .toList();

        state = state.copyWith(isLoading: false, wearableData: wearableList);
      } else {
        state = state.copyWith(isLoading: false, wearableData: [], errorMessage: 'Data tidak ditemukan');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, wearableData: [], errorMessage: 'Gagal memuat data');
    }
  }

  Future<WearableModel?> getLatestWearableData(int userId) async {
    try {
      final response = await _apiService.get('/wearable/user/$userId/latest');
      if (response.data['data'] != null) {
        return WearableModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // =====================================================
  // ✅ METHOD: SYNC DATA (KHUSUS MENGAMBIL DATA SETELAH IZIN DI UI)
  // =====================================================
  Future<bool> syncRealWearableData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final Health health = Health();
    final types = [
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ];

    try {
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 24));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: types,
      );

      if (healthData.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: "Tidak ditemukan data aktivitas baru dalam 24 jam terakhir.",
        );
        return false;
      }

      int finalHR = 0;
      int finalSistolik = 0;
      int finalDiastolik = 0;
      int finalSleepSeconds = 0;
      DateTime? waktuDataHC;

      // 1. Filter data berdasarkan tipenya
      var hrList = healthData.where((p) => p.type == HealthDataType.HEART_RATE).toList();
      var sysList = healthData.where((p) => p.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC).toList();
      var diaList = healthData.where((p) => p.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC).toList();
      var sleepList = healthData.where((p) => p.type == HealthDataType.SLEEP_SESSION).toList();

      // 2. Urutkan data dari yang paling TERBARU ke terlama (berdasarkan dateTo)
      hrList.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      sysList.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      diaList.sort((a, b) => b.dateTo.compareTo(a.dateTo));

      // 3. Ambil data HANYA dari urutan pertama (paling terbaru)
      if (hrList.isNotEmpty) {
        finalHR = (hrList.first.value as NumericHealthValue).numericValue.toInt();
        waktuDataHC = hrList.first.dateTo; // Jadikan waktu detak jantung terbaru sebagai acuan
      }

      if (sysList.isNotEmpty) {
        finalSistolik = (sysList.first.value as NumericHealthValue).numericValue.toInt();
        waktuDataHC ??= sysList.first.dateTo; // Jika HR kosong, pakai waktu tensi
      }

      if (diaList.isNotEmpty) {
        finalDiastolik = (diaList.first.value as NumericHealthValue).numericValue.toInt();
      }

      // 4. Khusus durasi tidur, dijumlahkan (karena tidur bisa terbagi beberapa sesi dalam 24 jam)
      int totalSleepMinutes = 0;
      for (var sleep in sleepList) {
        totalSleepMinutes += sleep.dateTo.difference(sleep.dateFrom).inMinutes;
      }
      finalSleepSeconds = totalSleepMinutes * 60;

      // Fallback ke waktu sekarang jika tidak ada data waktu sama sekali
      waktuDataHC ??= now;

      // 5. Kirim data TERBARU tersebut ke Backend Golang
      return await _sendDataToBackend(
        userId, finalHR, finalSleepSeconds, finalSistolik, finalDiastolik,
        waktuDataHC,
      );

    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan sistem saat menarik data.");
      return false;
    }
  }

  // =====================================================
  // FUNGSI PEMBANTU: Kirim data ke Backend Golang
  // =====================================================
  Future<bool> _sendDataToBackend(
      int userId, int hr, int sleepSeconds, int sistolik, int diastolik,
      DateTime waktuDataHC, // ✅ Tambah parameter ini
      ) async {
    if (hr == 0 && sleepSeconds == 0) {
      state = state.copyWith(isLoading: false, errorMessage: "Data aktivitas kosong.");
      return false;
    }

    try {
      final now = DateTime.now();
      final String tglData =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // ✅ waktu_data dari Health Connect, bukan dari DateTime.now()
      final String waktuData =
          "${waktuDataHC.hour.toString().padLeft(2, '0')}:${waktuDataHC.minute.toString().padLeft(2, '0')}:${waktuDataHC.second.toString().padLeft(2, '0')}";

      final wearableRes = await _apiService.post(
        '/wearable',
        data: {
          'id_user': userId,
          'heart_rate_hr': hr,
          'sleep_duration': sleepSeconds ~/ 60,
          'sistolik': sistolik,
          'diastolik': diastolik,
          'tgl_data': tglData,
          'waktu_data': waktuData, // ✅ Waktu dari Health Connect (misal: "19:17:00")
        },
      );

      final dataRes = wearableRes.data;
      if (dataRes['data'] == null || dataRes['data']['id_wearable'] == null) {
        throw Exception("Respon server tidak valid");
      }

      await fetchWearableData(userId);
      state = state.copyWith(isLoading: false);
      return true;

    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Gagal menyimpan ke server.");
      return false;
    }
  }
}

// =======================================================
// 3. PROVIDER EXPORT
// =======================================================
final wearableProvider = NotifierProvider<WearableNotifier, WearableState>(WearableNotifier.new);

final wearableDataProvider = Provider<List<WearableModel>>((ref) {
  return ref.watch(wearableProvider).wearableData;
});

final wearableLoadingProvider = Provider<bool>((ref) {
  return ref.watch(wearableProvider).isLoading;
});

final wearableErrorProvider = Provider<String?>((ref) {
  return ref.watch(wearableProvider).errorMessage;
});

final latestWearableProvider = Provider<WearableModel?>((ref) {
  final data = ref.watch(wearableProvider).wearableData;
  if (data.isEmpty) return null;
  return data.first;
});