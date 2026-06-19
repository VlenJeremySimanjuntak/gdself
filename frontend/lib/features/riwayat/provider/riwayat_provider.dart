import 'package:flutter/foundation.dart'; // ✅ Tambahkan ini untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_service.dart';
import '../../../models/usg_tiroid_model.dart';

class RiwayatState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> laporanList;
  final List<Map<String, dynamic>> items; // ← Tambahkan ini

  RiwayatState({
    this.isLoading = false,
    this.errorMessage,
    this.laporanList = const [],
    this.items = const [], // ← Tambahkan
  });

  RiwayatState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? laporanList,
    List<Map<String, dynamic>>? items, // ← Tambahkan
  }) {
    return RiwayatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      laporanList: laporanList ?? this.laporanList,
      items: items ?? this.items, // ← Tambahkan
    );
  }
}

class RiwayatNotifier extends Notifier<RiwayatState> {
  final ApiService _apiService = ApiService();

  @override
  RiwayatState build() {
    return RiwayatState();
  }

  Future<void> fetchRiwayatData(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // ── 1. Ambil data lab (tetap sama) ──
      final response = await _apiService.get('/laporan-lab/user/$userId');
      List<Map<String, dynamic>> labItems = [];

      if (response.statusCode == 200) {
        final dynamic responseData = response.data['data'];
        List<dynamic> dataList = [];
        if (responseData is List) {
          dataList = responseData;
        } else if (responseData != null) {
          dataList = [responseData];
        }
        for (var item in dataList) {
          labItems.add(_parseLaporan(item));
        }
      } else {
        debugPrint('⚠️ Gagal ambil data lab: ${response.statusCode}');
      }

      // ── 2. TAMBAHKAN: Ambil data USG ──
      List<Map<String, dynamic>> usgItems = [];
      try {
        final usgResponse = await _apiService.get('/usg-tiroid/user/$userId');
        if (usgResponse.statusCode == 200) {
          final data = usgResponse.data['data'];
          if (data is List) {
            for (var item in data) {
              try {
                final usg = UsgTiroidModel.fromJson(item);
                usgItems.add(_parseUsg(usg));
              } catch (e) {
                debugPrint('⚠️ Gagal parse USG: $e');
              }
            }
          }
        } else {
          debugPrint('⚠️ Gagal ambil data USG: ${usgResponse.statusCode}');
        }
      } catch (usgError) {
        debugPrint('⚠️ Error fetch USG: $usgError');
      }

      // ── 3. Gabungkan dan urutkan ──
      List<Map<String, dynamic>> combined = [...labItems, ...usgItems];
      combined.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['tanggal'] ?? '') ?? DateTime(1900);
        DateTime dateB = DateTime.tryParse(b['tanggal'] ?? '') ?? DateTime(1900);
        return dateB.compareTo(dateA);
      });

      // ── 4. Update state ──
      state = state.copyWith(
        isLoading: false,
        laporanList: labItems, // ← tetap diisi seperti semula
        items: combined,       // ← tambahkan ini
      );

    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Fungsi untuk mem-parsing JSON dari Backend (lab)
  Map<String, dynamic> _parseLaporan(Map<String, dynamic> item) {
    String rawDate = item['tgl_periksa'] ?? item['created_at'] ?? "";
    DateTime dateObj = DateTime.tryParse(rawDate) ?? DateTime.now();

    String formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(dateObj).toUpperCase();
    String time = DateFormat('HH:mm').format(dateObj);

    String namaLab = item['nama_lab'] ?? "Laboratorium Klinik";

    List<dynamic> hasilLab = item['hasil_lab'] ?? [];
    List<String> abnormalParams = [];

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

    String ringkasan = "";
    if (abnormalParams.isEmpty) {
      ringkasan = "Hasil stabil, semua parameter dalam batas normal.";
    } else {
      ringkasan = "Perhatian: ${abnormalParams.join(', ')}.";
    }

    return {
      "type": 'lab',
      "id_laporan_lab": item['id_laporan_lab'],
      "raw_date": rawDate,
      "formatted_date": formattedDate,
      "time": time,
      "nama_lab": namaLab,
      "ringkasan": ringkasan,
      "raw_data": item,
      "tanggal": rawDate,
    };
  }

  // Fungsi untuk mem-parsing USG
  Map<String, dynamic> _parseUsg(UsgTiroidModel usg) {
    String tanggal = usg.tglPemeriksaan != null
        ? DateFormat('yyyy-MM-dd').format(usg.tglPemeriksaan!)
        : '';
    String formatted = usg.tglPemeriksaan != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(usg.tglPemeriksaan!)
        : '-';
    String ringkasan = usg.catatanDokter ?? 'Tidak ada catatan';

    return {
      'type': 'usg',
      'id': usg.idUsg,
      'nama': usg.namaRs,
      'tanggal': tanggal,
      'formatted_date': formatted,
      'time': '',
      'ringkasan': ringkasan,
      'raw_data': usg,
    };
  }
}

final riwayatProvider = NotifierProvider<RiwayatNotifier, RiwayatState>(() {
  return RiwayatNotifier();
});