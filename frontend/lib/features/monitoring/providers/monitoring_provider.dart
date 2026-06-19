// providers/monitoring_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../../models/usg_tiroid_model.dart';

class MonitoringState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, List<Map<String, dynamic>>> history;
  final HasilAIGabunganModel? latestAiResult;
  final List<UsgTiroidModel> usgList;

  MonitoringState({
    this.isLoading = false,
    this.errorMessage,
    this.history = const {"TSHs": [], "FT4": [], "FT3": [], "TRAb": []},
    this.latestAiResult,
    this.usgList = const [],
  });

  MonitoringState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, List<Map<String, dynamic>>>? history,
    HasilAIGabunganModel? latestAiResult,
    List<UsgTiroidModel>? usgList,
  }) {
    return MonitoringState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      history: history ?? this.history,
      latestAiResult: latestAiResult ?? this.latestAiResult,
      usgList: usgList ?? this.usgList,
    );
  }
}

class MonitoringNotifier extends Notifier<MonitoringState> {
  final ApiService _apiService = ApiService();

  @override
  MonitoringState build() {
    return MonitoringState();
  }

  Future<void> fetchMonitoringData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _apiService.get('/laporan-lab/user/$userId');

      debugPrint('📥 Response /laporan-lab/user/$userId: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.data}');

      if (response.statusCode == 200) {
        final dynamic responseData = response.data['data'];
        List<dynamic> dataList = [];

        if (responseData is List) {
          dataList = responseData;
        } else if (responseData != null) {
          dataList = [responseData];
        }

        final listTerurut = dataList.reversed.toList();

        Map<String, List<Map<String, dynamic>>> mappedHistory = {
          "TSHs": [],
          "FT4": [],
          "FT3": [],
          "TRAb": [],
        };

        for (var laporan in listTerurut) {
          if (laporan is Map<String, dynamic>) {
            final hasilLabList = laporan['hasil_lab'];

            if (hasilLabList != null && hasilLabList is List) {
              String? rawDate = laporan['tgl_periksa'] ?? laporan['created_at'];
              DateTime dateObject = rawDate != null
                  ? (DateTime.tryParse(rawDate) ?? DateTime.now())
                  : DateTime.now();

              for (var hasil in hasilLabList) {
                if (hasil is Map<String, dynamic>) {
                  final parameterObj = hasil['parameter'];

                  if (parameterObj != null && parameterObj is Map<String, dynamic>) {
                    final namaParam =
                        parameterObj['nama_parameter']?.toString().toUpperCase() ?? "";

                    String targetKey = namaParam;
                    if (namaParam == "TSH" || namaParam == "TSHS") {
                      targetKey = "TSHs";
                    } else if (namaParam == "TRAB") {
                      targetKey = "TRAb";
                    }

                    debugPrint('🔍 Processing: $namaParam → targetKey: $targetKey');

                    if (mappedHistory.containsKey(targetKey)) {
                      double val = double.tryParse(hasil['nilai_hasil']?.toString() ?? "0.0") ?? 0.0;
                      double minVal = double.tryParse(hasil['nilai_batas_bawah']?.toString() ?? "0") ?? 0.0;
                      double maxVal = double.tryParse(hasil['nilai_batas_atas']?.toString() ?? "0") ?? 0.0;

                      debugPrint('📊 Data: $targetKey → val=$val, min=$minVal, max=$maxVal');

                      double ratio = 0.5;
                      if (targetKey == "TSHs") ratio = (val / 10.0).clamp(0.1, 0.9);
                      else if (targetKey == "FT4") ratio = (val / 25.0).clamp(0.1, 0.9);
                      else if (targetKey == "FT3") ratio = (val / 10.0).clamp(0.1, 0.9);
                      else if (targetKey == "TRAb") ratio = (val / 5.0).clamp(0.1, 0.9);

                      String formattedMonth =
                      DateFormat('MMM', 'id_ID').format(dateObject).toUpperCase();
                      String formattedDate =
                      DateFormat('dd MMM yyyy', 'id_ID').format(dateObject);

                      bool isDuplicate = mappedHistory[targetKey]!
                          .any((element) => element["date"] == formattedDate);

                      if (!isDuplicate) {
                        mappedHistory[targetKey]!.add({
                          "month": formattedMonth,
                          "date": formattedDate,
                          "val": val.toString(),
                          "unit": parameterObj['satuan']?.toString() ?? "",
                          "yRatio": 1.0 - ratio,
                          "min": minVal,
                          "max": maxVal,
                        });
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Ambil maksimal 2 data terakhir per parameter
        mappedHistory.forEach((key, value) {
          if (value.length > 2) {
            mappedHistory[key] = value.sublist(value.length - 2);
          }
        });

        debugPrint('📊 mappedHistory final: $mappedHistory');

        state = state.copyWith(isLoading: false, history: mappedHistory);

        // ── Fetch Hasil AI ──────────────────────────────────────────
        try {
          if (listTerurut.isNotEmpty) {
            final latestLaporan = listTerurut.last;
            final latestLabId = latestLaporan['id_laporan_lab'];

            if (latestLabId != null) {
              // 1. Fetch AI Lab
              final aiLabResponse = await _apiService.get('/hasil-ai/lab/laporan/$latestLabId');

              if (aiLabResponse.statusCode == 200) {
                final dataLab = aiLabResponse.data['data'];

                if (dataLab != null && dataLab is Map<String, dynamic>) {
                  HasilAIGabunganModel aiModel = HasilAIGabunganModel.fromLabJson(dataLab);

                  // 2. Fetch AI Tren (opsional — wajar 404 jika laporan pertama)
                  try {
                    final aiTrenResponse = await _apiService.get('/hasil-ai/tren/laporan/$latestLabId');

                    if (aiTrenResponse.statusCode == 200) {
                      final dataTren = aiTrenResponse.data['data'];
                      if (dataTren != null && dataTren is Map<String, dynamic>) {
                        // Gabungkan data tren ke model
                        aiModel = aiModel.withTren(dataTren);
                        debugPrint('✅ AI Tren berhasil digabungkan untuk laporan $latestLabId');
                      }
                    } else if (aiTrenResponse.statusCode == 404) {
                      // Wajar — laporan pertama, tren belum dibuat
                      debugPrint('⚠️ AI Tren belum tersedia (404) untuk laporan $latestLabId — wajar jika ini laporan pertama');
                      // Tidak perlu error, lanjutkan dengan data lab saja
                    } else {
                      // Status lain selain 200/404 — log tapi jangan gagalkan
                      debugPrint('⚠️ AI Tren response status ${aiTrenResponse.statusCode} untuk laporan $latestLabId');
                    }
                  } catch (trenError) {
                    // Tangkap error lainnya (network, parsing, dll.)
                    debugPrint('⚠️ Error saat fetch AI Tren (bisa jadi laporan pertama): $trenError');
                    // Lanjutkan tanpa tren, tidak perlu throw error
                  }

                  state = state.copyWith(latestAiResult: aiModel);
                  debugPrint('✅ Hasil AI Lab berhasil di-set untuk laporan $latestLabId');
                }
              } else {
                // AI Lab belum di-generate (status bukan 200)
                state = state.copyWith(latestAiResult: null);
                debugPrint("⚠️ AI Lab belum tersedia untuk laporan $latestLabId (status: ${aiLabResponse.statusCode})");
              }
            } else {
              debugPrint('⚠️ latestLabId null, skip AI fetch');
            }
          } else {
            debugPrint('⚠️ listTerurut kosong, skip AI fetch');
          }
        } catch (aiError) {
          debugPrint("❌ Gagal fetch AI secara keseluruhan: $aiError");
          state = state.copyWith(latestAiResult: null);
        }

        // ── Fetch USG Tiroid ────────────────────────────────────────
        try {
          final usgResponse = await _apiService.get('/usg-tiroid/user/$userId');
          debugPrint("USG response: ${usgResponse.data}");

          if (usgResponse.statusCode == 200) {
            final usgData = usgResponse.data['data'];
            if (usgData != null && usgData is List) {
              final usgList = usgData
                  .map((e) => UsgTiroidModel.fromJson(e as Map<String, dynamic>))
                  .toList();
              state = state.copyWith(usgList: usgList);
              debugPrint('✅ USG Tiroid berhasil di-fetch: ${usgList.length} data');
            }
          }
        } catch (usgError) {
          debugPrint("❌ Gagal fetch USG: $usgError");
        }

      } else {
        state = state.copyWith(isLoading: false, errorMessage: "Gagal mengambil data");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      debugPrint("❌ Error fetchMonitoringData: $e");
    }
  }

  Future<bool> simpanHasilLab(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final correctedPayload = {
        'id_user': payload['id_user'],
        'tgl_periksa': payload['tgl_periksa'],
        'nama_lab': payload['nama_lab'] ?? 'Laboratorium Klinik',
        'parameters': payload['parameters'] ?? [],
      };

      debugPrint('📤 Payload ke /hasil-lab: ${jsonEncode(correctedPayload)}');

      // 1. Simpan Data Lab ke Database
      final response = await _apiService.post('/hasil-lab', data: correctedPayload);

      if (response.statusCode == 200 || response.statusCode == 201) {

        // 2. 🤖 TRIGGER AI OTOMATIS
        try {
          final data = response.data['data'];
          int? newLabId;

          if (data is Map<String, dynamic>) {
            newLabId = data['id_laporan_lab'] ?? data['id_report'];
          } else if (data is List && data.isNotEmpty) {
            newLabId = data[0]['id_laporan_lab'] ?? data[0]['id_report'];
          }

          if (newLabId != null && newLabId != 0) {
            await _apiService.post('/hasil-ai/assess', data: {
              "lab": { "id_laporan_lab": newLabId },
              "is_lab_day": true
            });
            debugPrint("✅ AI otomatis berhasil berhitung untuk Laporan $newLabId");
          }
        } catch (aiError) {
          debugPrint("⚠️ Gagal memicu AI otomatis: $aiError");
        }

        // 3. Tarik ulang data untuk update UI HP
        await fetchMonitoringData(payload['id_user']);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.data['message'] ?? "Gagal menyimpan data",
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Terjadi kesalahan: $e",
      );
      return false;
    }
  }

  Future<bool> editHasilLab(
      int idHasilLab, Map<String, dynamic> payload, int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiService.put('/hasil-lab/$idHasilLab', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchMonitoringData(userId);
        return true;
      } else {
        state = state.copyWith(
            isLoading: false,
            errorMessage: response.data['message'] ?? "Gagal memperbarui data");
        return false;
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false, errorMessage: "Terjadi kesalahan jaringan: $e");
      return false;
    }
  }
}

final monitoringProvider =
NotifierProvider<MonitoringNotifier, MonitoringState>(() {
  return MonitoringNotifier();
});