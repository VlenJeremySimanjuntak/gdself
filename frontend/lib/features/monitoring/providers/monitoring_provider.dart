import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../../models/usg_tiroid_model.dart';

class _Sentinel {
  const _Sentinel();
}
const _sentinel = _Sentinel();

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
    Object? errorMessage = _sentinel,
    Map<String, List<Map<String, dynamic>>>? history,
    Object? latestAiResult = _sentinel, // Pakai sentinel agar bisa di-set null
    List<UsgTiroidModel>? usgList,
  }) {
    return MonitoringState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      history: history ?? this.history,
      latestAiResult: latestAiResult == _sentinel
          ? this.latestAiResult
          : latestAiResult as HasilAIGabunganModel?, // Sekarang bisa menerima null murni
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

      if (response.statusCode == 200) {
        final dynamic responseData = response.data['data'];
        List<dynamic> dataList = [];

        if (responseData is List) {
          dataList = List.from(responseData);
        } else if (responseData != null) {
          dataList = [responseData];
        }

        // ✅ Urutkan berdasarkan tgl_periksa (tanggal lebih awal -> lebih baru di akhir list)
        dataList.sort((a, b) {
          DateTime dateA = DateTime.tryParse(
              a['tgl_periksa']?.toString() ?? a['created_at']?.toString() ?? ''
          ) ?? DateTime(1970);
          DateTime dateB = DateTime.tryParse(
              b['tgl_periksa']?.toString() ?? b['created_at']?.toString() ?? ''
          ) ?? DateTime(1970);
          return dateA.compareTo(dateB);
        });

        Map<String, List<Map<String, dynamic>>> mappedHistory = {
          "TSHs": [],
          "FT4": [],
          "FT3": [],
          "TRAb": [],
        };

        for (var laporan in dataList) {
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

                    if (mappedHistory.containsKey(targetKey)) {
                      double val = double.tryParse(hasil['nilai_hasil']?.toString() ?? "0.0") ?? 0.0;
                      double minVal = double.tryParse(hasil['nilai_batas_bawah']?.toString() ?? "0") ?? 0.0;
                      double maxVal = double.tryParse(hasil['nilai_batas_atas']?.toString() ?? "0") ?? 0.0;

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

        mappedHistory.forEach((key, value) {
          if (value.length > 2) {
            mappedHistory[key] = value.sublist(value.length - 2);
          }
        });

        state = state.copyWith(isLoading: false, history: mappedHistory);

        // ── ✅ PERBAIKAN FATAL: Fetch Hasil AI (Ambil dari laporan terbaru seperti di HomeScreen) ──
        try {
          if (dataList.isNotEmpty) {
            final latestLaporan = dataList.last;
            final latestLabId = latestLaporan['id_laporan_lab'] ?? latestLaporan['id_report'];

            if (latestLabId != null) {
              HasilAIGabunganModel? aiModel;

              // 1. Tarik Data AI Lab secara penuh
              Map<String, dynamic>? dataLab;
              try {
                final labRes = await _apiService.get('/hasil-ai/lab/laporan/$latestLabId');
                if (labRes.statusCode == 200 && labRes.data['data'] != null) {
                  dataLab = labRes.data['data'] is Map ? labRes.data['data'] : null;
                }
              } catch (e) {
                debugPrint('ℹ️ AI Lab info belum ada/error: $e');
              }

              // 2. Tarik Data AI Tren secara penuh
              Map<String, dynamic>? dataTren;
              try {
                final trenRes = await _apiService.get('/hasil-ai/tren/laporan/$latestLabId');
                if (trenRes.statusCode == 200 && trenRes.data['data'] != null) {
                  dataTren = trenRes.data['data'] is Map ? trenRes.data['data'] : null;
                }
              } catch (e) {
                debugPrint('ℹ️ AI Tren info belum ada/error: $e');
              }

              // 3. Gabungkan Data (Pasti terbaca karena kita pakai model kebal error yang tadi dibuat)
              if (dataLab != null) {
                aiModel = HasilAIGabunganModel.fromLabJson(dataLab);
                if (dataTren != null) {
                  aiModel = aiModel.withTren(dataTren);
                }
              } else if (dataTren != null) {
                aiModel = HasilAIGabunganModel.fromTrenOnly(dataTren);
              }

              state = state.copyWith(latestAiResult: aiModel);
            } else {
              state = state.copyWith(latestAiResult: null);
            }
          } else {
            // PAKSA KOSONG JIKA TIDAK ADA LAPORAN
            state = state.copyWith(latestAiResult: null);
          }
        } catch (aiError) {
          debugPrint("❌ Gagal fetch AI secara keseluruhan: $aiError");
          state = state.copyWith(latestAiResult: null);
        }

        // ── Fetch USG Tiroid ────────────────────────────────────────
        try {
          final usgResponse = await _apiService.get('/usg-tiroid/user/$userId');
          if (usgResponse.statusCode == 200) {
            final usgData = usgResponse.data['data'];
            if (usgData != null && usgData is List) {
              final usgList = usgData
                  .map((e) => UsgTiroidModel.fromJson(e as Map<String, dynamic>))
                  .toList();
              state = state.copyWith(usgList: usgList);
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
        if (payload['id_laporan_lab'] != null)
          'id_laporan_lab': payload['id_laporan_lab'],
      };

      final response = await _apiService.post('/hasil-lab', data: correctedPayload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = response.data['data'];
          int? newLabId;

          if (data is Map<String, dynamic>) {
            newLabId = data['id_laporan_lab'] ?? data['id_report'];
          } else if (data is List && data.isNotEmpty) {
            newLabId = data[0]['id_laporan_lab'] ?? data[0]['id_report'];
          }

          if (newLabId != null && newLabId != 0) {
            _apiService.post('/hasil-ai/assess', data: {
              "is_lab_day": true,
              "lab": {
                "id_laporan_lab": newLabId,
                "parameters": correctedPayload['parameters']
              }
            }).catchError((e) => debugPrint("⚠️ Gagal memicu AI otomatis: $e"));
          }
        } catch (aiError) {
          debugPrint("⚠️ Gagal memicu AI otomatis: $aiError");
        }

        fetchMonitoringData(payload['id_user']);

        state = state.copyWith(isLoading: false);
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

  Future<void> reassessLab({
    required int idLaporanLab,
    required List<Map<String, dynamic>> parameters,
  }) async {
    try {
      await _apiService.post(
        '/hasil-ai/assess',
        data: {
          'is_lab_day': true,
          'lab': {
            'id_laporan_lab': idLaporanLab,
            'parameters': parameters,
          },
        },
      );
      debugPrint('✅ Reassess berhasil untuk laporan $idLaporanLab');
    } catch (e) {
      debugPrint('⚠️ Reassess gagal: $e');
    }
  }
}

final monitoringProvider =
NotifierProvider<MonitoringNotifier, MonitoringState>(() {
  return MonitoringNotifier();
});