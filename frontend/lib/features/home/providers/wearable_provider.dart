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

      int totalHR = 0, countHR = 0, totalSleepMinutes = 0;
      int totalSistolik = 0, countSistolik = 0;
      int totalDiastolik = 0, countDiastolik = 0;

      // ✅ Ambil timestamp dari Health Connect untuk jadi acuan waktu_data
      DateTime? waktuDataHC; // Timestamp data terbaru dari Health Connect

      for (var point in healthData) {
        if (point.type == HealthDataType.HEART_RATE && point.value is NumericHealthValue) {
          totalHR += (point.value as NumericHealthValue).numericValue.toInt();
          countHR++;

          // ✅ Ambil dateFrom dari data HR sebagai waktu_data
          // (HR adalah data paling representatif untuk timestamp)
          if (waktuDataHC == null || point.dateFrom.isAfter(waktuDataHC)) {
            waktuDataHC = point.dateFrom;
          }

        } else if (point.type == HealthDataType.SLEEP_SESSION) {
          totalSleepMinutes += point.dateTo.difference(point.dateFrom).inMinutes;

        } else if (point.type == HealthDataType.BLOOD_PRESSURE_SYSTOLIC && point.value is NumericHealthValue) {
          totalSistolik += (point.value as NumericHealthValue).numericValue.toInt();
          countSistolik++;

        } else if (point.type == HealthDataType.BLOOD_PRESSURE_DIASTOLIC && point.value is NumericHealthValue) {
          totalDiastolik += (point.value as NumericHealthValue).numericValue.toInt();
          countDiastolik++;
        }
      }

      final int finalHR = countHR > 0 ? (totalHR ~/ countHR) : 0;
      final int finalSleepSeconds = totalSleepMinutes * 60;
      final int finalSistolik = countSistolik > 0 ? (totalSistolik ~/ countSistolik) : 0;
      final int finalDiastolik = countDiastolik > 0 ? (totalDiastolik ~/ countDiastolik) : 0;

      // ✅ Fallback ke waktu sekarang jika tidak ada data HR sama sekali
      waktuDataHC ??= now;

      return await _sendDataToBackend(
        userId, finalHR, finalSleepSeconds, finalSistolik, finalDiastolik,
        waktuDataHC, // ✅ Kirim timestamp dari Health Connect
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

      debugPrint("📡 Kirim wearable: tgl=$tglData waktu=$waktuData hr=$hr sleep=${sleepSeconds ~/ 60}mnt");

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