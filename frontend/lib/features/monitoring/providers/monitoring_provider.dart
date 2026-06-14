import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/hasil_ai_gabungan_model.dart'; // Import model baru

class MonitoringState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, List<Map<String, dynamic>>> history;
  final HasilAIGabunganModel? latestAiResult; // 👇 UBAH: Menggunakan model AI Gabungan (Lab)

  MonitoringState({
    this.isLoading = false,
    this.errorMessage,
    this.history = const {"TSH": [], "FT4": [], "FT3": []},
    this.latestAiResult,
  });

  MonitoringState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, List<Map<String, dynamic>>>? history,
    HasilAIGabunganModel? latestAiResult, // 👇 UBAH: Parameter tipe disesuaikan
  }) {
    return MonitoringState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      history: history ?? this.history,
      latestAiResult: latestAiResult ?? this.latestAiResult,
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
          dataList = responseData;
        } else if (responseData != null) {
          dataList = [responseData];
        }

        final listTerurut = dataList.reversed.toList();

        Map<String, List<Map<String, dynamic>>> mappedHistory = {
          "TSH": [],
          "FT4": [],
          "FT3": [],
        };

        for (var laporan in listTerurut) {
          if (laporan is Map<String, dynamic>) {
            final hasilLabList = laporan['hasil_lab'];

            if (hasilLabList != null && hasilLabList is List) {
              String? rawDate = laporan['tgl_periksa'] ?? laporan['created_at'];
              DateTime dateObject = rawDate != null ? (DateTime.tryParse(rawDate) ?? DateTime.now()) : DateTime.now();

              for (var hasil in hasilLabList) {
                if (hasil is Map<String, dynamic>) {
                  final parameterObj = hasil['parameter'];

                  if (parameterObj != null && parameterObj is Map<String, dynamic>) {
                    final namaParam = parameterObj['nama_parameter']?.toString().toUpperCase() ?? "";

                    if (mappedHistory.containsKey(namaParam)) {
                      double val = double.tryParse(hasil['nilai_hasil']?.toString() ?? "0.0") ?? 0.0;
                      double minVal = double.tryParse(hasil['rujukan_min']?.toString() ?? "0") ?? 0.0;
                      double maxVal = double.tryParse(hasil['rujukan_max']?.toString() ?? "0") ?? 0.0;

                      double ratio = 0.5;
                      if (namaParam == "TSH") ratio = (val / 10.0).clamp(0.1, 0.9);
                      if (namaParam == "FT4") ratio = (val / 25.0).clamp(0.1, 0.9);
                      if (namaParam == "FT3") ratio = (val / 10.0).clamp(0.1, 0.9);

                      String formattedMonth = DateFormat('MMM', 'id_ID').format(dateObject).toUpperCase();
                      String formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(dateObject);

                      bool isDuplicate = mappedHistory[namaParam]!.any((element) => element["date"] == formattedDate);

                      if (!isDuplicate) {
                        mappedHistory[namaParam]!.add({
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

        // 👇 INTEGRASI RE-MAPPING RESPONS AI BARU
        try {
          if (listTerurut.isNotEmpty) {
            final latestLaporan = listTerurut.first;

            // Catatan: Jika Backend mengubah endpoint menjadi berbasis id_riwayat,
            // pastikan variabel ini diubah menjadi latestLaporan['id_riwayat'] dan endpoint-nya disesuaikan.
            final latestLabId = latestLaporan['id_laporan_lab'];

            if (latestLabId != null) {
              final aiResponse = await _apiService.get('/hasil-ai/hasil-lab/$latestLabId');

              if (aiResponse.statusCode == 200) {
                final aiData = aiResponse.data['data'];
                if (aiData != null) {
                  if (aiData is List && aiData.isNotEmpty) {
                    // 👇 UBAH: Parsing menggunakan HasilAIGabunganModel
                    state = state.copyWith(latestAiResult: HasilAIGabunganModel.fromJson(aiData[0]));
                  } else if (aiData is Map<String, dynamic>) {
                    // 👇 UBAH: Parsing menggunakan HasilAIGabunganModel
                    state = state.copyWith(latestAiResult: HasilAIGabunganModel.fromJson(aiData));
                  }
                }
              }
            }
          }
        } catch (aiError) {
          debugPrint("Gagal memproses data Hasil AI Gabungan: $aiError");
        }

      } else {
        state = state.copyWith(isLoading: false, errorMessage: "Gagal mengambil data");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> simpanHasilLab(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiService.post('/hasil-lab', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchMonitoringData(payload['id_user']);
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: response.data['message'] ?? "Gagal menyimpan data");
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan: $e");
      return false;
    }
  }

  Future<bool> editHasilLab(int idHasilLab, Map<String, dynamic> payload, int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiService.put('/hasil-lab/$idHasilLab', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchMonitoringData(userId);
        return true;
      } else {
        state = state.copyWith(isLoading: false, errorMessage: response.data['message'] ?? "Gagal memperbarui data");
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Terjadi kesalahan jaringan: $e");
      return false;
    }
  }
}

final monitoringProvider = NotifierProvider<MonitoringNotifier, MonitoringState>(() {
  return MonitoringNotifier();
});