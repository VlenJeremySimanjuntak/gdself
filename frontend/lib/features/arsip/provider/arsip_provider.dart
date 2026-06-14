import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';

class ArsipState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> laporanList;

  ArsipState({
    this.isLoading = false,
    this.errorMessage,
    this.laporanList = const [],
  });

  ArsipState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? laporanList,
  }) {
    return ArsipState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      laporanList: laporanList ?? this.laporanList,
    );
  }
}

class ArsipNotifier extends Notifier<ArsipState> {
  final ApiService _apiService = ApiService();

  @override
  ArsipState build() {
    return ArsipState();
  }

  Future<void> fetchArsipData(int userId) async {
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

        List<Map<String, dynamic>> parsedList = [];

        for (var item in dataList) {
          parsedList.add(_parseLaporan(item));
        }

        // Urutkan data dari yang paling baru (Descending)
        parsedList.sort((a, b) {
          DateTime dateA = DateTime.tryParse(a['raw_date']) ?? DateTime.now();
          DateTime dateB = DateTime.tryParse(b['raw_date']) ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        state = state.copyWith(isLoading: false, laporanList: parsedList);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: "Gagal memuat data arsip.");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Fungsi untuk mem-parsing JSON dari Backend dan membuat Ringkasan Otomatis
  Map<String, dynamic> _parseLaporan(Map<String, dynamic> item) {
    String rawDate = item['tgl_periksa'] ?? item['created_at'] ?? "";
    DateTime dateObj = DateTime.tryParse(rawDate) ?? DateTime.now();

    String formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(dateObj).toUpperCase();
    String time = DateFormat('HH:mm').format(dateObj);

    String namaLab = item['nama_lab'] ?? "Laboratorium Klinik";

    List<dynamic> hasilLab = item['hasil_lab'] ?? [];
    List<String> abnormalParams = [];

    // Cek satu-satu parameternya normal atau tidak
    for (var h in hasilLab) {
      double val = double.tryParse(h['nilai_hasil']?.toString() ?? "0") ?? 0;
      double min = double.tryParse(h['rujukan_min']?.toString() ?? "0") ?? 0;
      double max = double.tryParse(h['rujukan_max']?.toString() ?? "0") ?? 0;
      String paramName = h['parameter']?['nama_parameter'] ?? "";

      if (min != 0.0 || max != 0.0) {
        if (val < min) {
          abnormalParams.add("$paramName rendah");
        } else if (val > max) {
          abnormalParams.add("$paramName tinggi");
        }
      }
    }

    // Buat kalimat ringkasan
    String ringkasan = "";
    if (abnormalParams.isEmpty) {
      ringkasan = "Hasil stabil, semua parameter dalam batas normal.";
    } else {
      ringkasan = "Perhatian: ${abnormalParams.join(', ')}.";
    }

    return {
      "id_laporan_lab": item['id_laporan_lab'],
      "raw_date": rawDate,
      "formatted_date": formattedDate,
      "time": time,
      "nama_lab": namaLab,
      "ringkasan": ringkasan,
      "raw_data": item, // Simpan data asli untuk dilempar ke halaman detail nanti
    };
  }
}

final arsipProvider = NotifierProvider<ArsipNotifier, ArsipState>(() {
  return ArsipNotifier();
});