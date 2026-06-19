import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:huawei_health/huawei_health.dart';
import 'package:dio/dio.dart';
import '../../../services/api_service.dart';

// =======================================================
// 1. STATE CLASS
// =======================================================
class WearableState {
  final bool isLoading;
  final String? errorMessage;

  const WearableState({
    this.isLoading = false,
    this.errorMessage,
  });

  WearableState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return WearableState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// =======================================================
// 2. NOTIFIER — Riverpod v2 (Notifier)
// =======================================================
class WearableNotifier extends Notifier<WearableState> {
  final _apiService = ApiService();

  @override
  WearableState build() => const WearableState();

  // =====================================================
  // MESIN 1: HEALTH CONNECT (Google / Default Android)
  // =====================================================
  Future<bool> syncRealWearableData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final Health health = Health();
    health.configure();

    final types = [HealthDataType.HEART_RATE, HealthDataType.SLEEP_SESSION];
    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

    try {
      // 1. CEK IZIN (Tahap ini harus dipisah)
      bool hasPermissions = await health.hasPermissions(types, permissions: permissions) ?? false;

      if (!hasPermissions) {
        debugPrint("⚠️ Izin belum diberikan, meminta izin sekarang...");
        bool requested = await health.requestAuthorization(types, permissions: permissions);
        if (!requested) {
          state = state.copyWith(
              isLoading: false,
              errorMessage: "Izin akses kesehatan ditolak. Mohon aktifkan izin di pengaturan agar kami bisa mengambil data."
          );
          return false;
        }
        // Cek ulang setelah request
        hasPermissions = await health.hasPermissions(types, permissions: permissions) ?? false;
        if (!hasPermissions) {
          state = state.copyWith(isLoading: false, errorMessage: "Izin akses tetap tidak tersedia.");
          return false;
        }
      }

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(hours: 24));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: types,
      );

      // 3. VALIDASI DATA KOSONG (Beda dengan izin ditolak)
      if (healthData.isEmpty) {
        debugPrint("ℹ️ Izin aktif, tapi tidak ada data dalam 24 jam terakhir.");
        state = state.copyWith(
            isLoading: false,
            errorMessage: "Izin aktif, namun tidak ditemukan data aktivitas baru di Health Connect dalam 24 jam terakhir. Silakan sinkronkan jam tangan Anda."
        );
        return false;
      }

      // 4. LOGIKA PERHITUNGAN DATA
      int totalHR = 0;
      int countHR = 0;
      int totalSleepMinutes = 0;

      for (var point in healthData) {
        if (point.type == HealthDataType.HEART_RATE) {
          if (point.value is NumericHealthValue) {
            final hrValue = point.value as NumericHealthValue;
            totalHR += hrValue.numericValue.toInt();
            countHR++;
          }
        } else if (point.type == HealthDataType.SLEEP_SESSION) {
          final duration = point.dateTo.difference(point.dateFrom).inMinutes;
          totalSleepMinutes += duration;
        }
      }

      final int finalHR = countHR > 0 ? (totalHR ~/ countHR) : 0;
      final int finalSleepSeconds = totalSleepMinutes * 60;
      const int finalStress = 0; // Fallback jika tidak didukung langsung oleh Health Connect

      // 5. KIRIM KE BACKEND
      return await _sendDataToBackend(userId, finalHR, finalStress, finalSleepSeconds);

    } catch (e) {
      debugPrint("❌ Error sistem: $e");
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan sistem saat menarik data Health Connect.");
      return false;
    }
  }

  // =====================================================
  // MESIN 2: SAMSUNG HEALTH
  // =====================================================
  Future<bool> syncSamsungHealthData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      debugPrint("📱 Samsung Health → menarik via Health Connect...");
      return await syncRealWearableData(userId);
    } catch (e) {
      debugPrint("❌ Error Samsung Health: $e");
      state = state.copyWith(
        isLoading: false,
        errorMessage:
        "Gagal membaca data Samsung Health. "
            "Pastikan Samsung Health sudah tersinkron ke Health Connect.",
      );
      return false;
    }
  }

  // =====================================================
  // MESIN 3: HUAWEI HEALTH
  // =====================================================
  Future<bool> syncHuaweiHealthData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      debugPrint("📱 Memulai koneksi ke Huawei Health...");

      // 1. Sign-in & request scopes
      final List<Scope> scopes = [
        Scope.HEALTHKIT_HEARTRATE_READ,
        Scope.HEALTHKIT_SLEEP_READ,
        Scope.HEALTHKIT_HISTORYDATA_OPEN_WEEK,
      ];

      AuthHuaweiId? authResult;
      try {
        authResult = await HealthAuth.signIn(scopes);
      } on PlatformException catch (e) {
        throw Exception("Login Huawei Health gagal: ${e.message}. Pastikan HMS Core terinstal.");
      }

      if (authResult == null) {
        throw Exception("Login Huawei Health gagal. Pastikan HMS Core terinstal.");
      }
      debugPrint("✅ Huawei sign-in berhasil: ${authResult.displayName}");

      // 2. Init DataController
      final DataController dataController = await DataController.init();

      final DateTime now = DateTime.now();
      final DateTime startTime = now.subtract(const Duration(hours: 24));

      // ─── 3a. Tarik Heart Rate ────────────────────────────────────────────
      final DataCollector hrCollector = DataCollector(
        dataType: DataType.DT_INSTANTANEOUS_HEART_RATE,
        dataGenerateType: DataGenerateType.DATA_TYPE_RAW,
        dataStreamName: 'heart_rate_stream',
      );

      final ReadOptions hrOptions = ReadOptions(
        startTime: startTime,
        endTime: now,
        dataCollectors: [hrCollector],
        timeUnit: TimeUnit.MILLISECONDS,
      );

      final ReadReply? hrReply = await dataController.read(hrOptions);

      int totalHR = 0;
      int countHR = 0;
      for (final SampleSet sampleSet in hrReply?.sampleSets ?? []) {
        for (final SamplePoint point in sampleSet.samplePoints ?? []) {
          final dynamic rawVal = point.fieldValues?[Field.FIELD_BPM.toString()];
          if (rawVal != null) {
            final int hrVal = (rawVal as num).toInt();
            if (hrVal > 0) {
              totalHR += hrVal;
              countHR++;
            }
          }
        }
      }

      // ─── 3b. Tarik Sleep ────────────────────────────────────────────────
      final DataCollector sleepCollector = DataCollector(
        dataType: DataType.DT_CONTINUOUS_SLEEP,
        dataGenerateType: DataGenerateType.DATA_TYPE_RAW,
        dataStreamName: 'sleep_stream',
      );

      final ReadOptions sleepOptions = ReadOptions(
        startTime: startTime,
        endTime: now,
        dataCollectors: [sleepCollector],
        timeUnit: TimeUnit.MILLISECONDS,
      );

      final ReadReply? sleepReply = await dataController.read(sleepOptions);

      int totalSleepSeconds = 0;
      for (final SampleSet sampleSet in sleepReply?.sampleSets ?? []) {
        for (final SamplePoint point in sampleSet.samplePoints ?? []) {
          final int? startMs = point.startTime?.millisecondsSinceEpoch;
          final int? endMs = point.endTime?.millisecondsSinceEpoch;
          if (startMs != null && endMs != null && endMs > startMs) {
            totalSleepSeconds += ((endMs - startMs) ~/ 1000);
          }
        }
      }

      final int finalHR = countHR > 0 ? (totalHR ~/ countHR) : 0;
      const int finalStress = 0;

      return await _sendDataToBackend(userId, finalHR, finalStress, totalSleepSeconds);
    } catch (e) {
      debugPrint("❌ Error Huawei Health: $e");
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Gagal menghubungkan layanan Huawei Health: ${e.toString()}",
      );
      return false;
    }
  }

  // =====================================================
  // FUNGSI PEMBANTU: Kirim data ke Backend Golang
  // =====================================================
  Future<bool> _sendDataToBackend(
      int userId, int hr, int stress, int sleepSeconds) async {

    // 1. VALIDASI: Jangan kirim ke backend jika data benar-benar kosong
    if (hr == 0 && sleepSeconds == 0 && stress == 0) {
      debugPrint("⚠️ Data wearable kosong, tidak dikirim ke backend.");
      state = state.copyWith(
          isLoading: false,
          errorMessage: "Data aktivitas tidak ditemukan. Pastikan jam tangan Anda sudah tersinkron dengan aplikasi kesehatan."
      );
      return false;
    }

    try {
      debugPrint("📡 Mengirim data ke Golang: HR=$hr, SleepSec=$sleepSeconds, Stress=$stress");
      final String tglDataGolang = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

      // 2. POST /wearable
      final wearableRes = await _apiService.post(
        '/wearable',
        data: {
          'id_user': userId,
          'heart_rate_hr': hr,
          'sleep_duration': sleepSeconds ~/ 60,
          'tgl_data': tglDataGolang, // ✅ PERBAIKAN DI SINI
        },
      );

      final dataRes = wearableRes.data;
      if (dataRes['data'] == null || dataRes['data']['id_wearable'] == null) {
        throw Exception("Respon server tidak valid (id_wearable tidak ditemukan)");
      }

      final int idWearable = dataRes['data']['id_wearable'];
      debugPrint("✅ Wearable tersimpan, id_wearable=$idWearable");

      // 3. POST /hasil-ai
      await _apiService.post(
        '/hasil-ai',
        data: {
          'id_user': userId,
          'id_wearable': idWearable,
          'input': {
            'is_lab_day': false,
            'wearable': {
              'hr': hr,
              'stress': stress,
              'sleep_minutes': sleepSeconds ~/ 60,
            }
          }
        },
      );

      debugPrint("✅ Hasil AI tersimpan");
      state = state.copyWith(isLoading: false);
      return true;

    } on DioException catch (e) {
      debugPrint("❌ Error Backend Sync (Dio): ${e.message}");
      debugPrint("❌ Detail Response Server: ${e.response?.data}");

      final serverMsg = e.response?.data is Map
          ? e.response?.data['error']
          : "Terjadi kesalahan server";

      state = state.copyWith(
        isLoading: false,
        errorMessage: serverMsg ?? "Kesalahan server: ${e.response?.statusCode}",
      );
      return false;
    } catch (e) {
      debugPrint("❌ Error Backend Sync: $e");
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Terjadi kesalahan saat menyimpan data: ${e.toString()}",
      );
      return false;
    }
  }
}

// =======================================================
// 3. PROVIDER — Riverpod v2: NotifierProvider
// =======================================================
final wearableProvider = NotifierProvider<WearableNotifier, WearableState>(
  WearableNotifier.new,
);