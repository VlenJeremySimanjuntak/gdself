import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/lab_data_model.dart';
import '../../../models/obat_model.dart';
import '../../../models/wearable_model.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../../services/api_service.dart';
import 'package:gdself/features/home/providers/user_provider.dart';

class HomeState {
  final bool isLoading;
  final String? errorMessage;
  final LaporanLabModel? laporanTerbaru;
  final List<JadwalObatModel> jadwalObat;
  final WearableModel? wearableTerbaru;
  final String? statusKepatuhan;
  final String? pesanEdukasi;

  const HomeState({
    this.isLoading = false,
    this.errorMessage,
    this.laporanTerbaru,
    this.jadwalObat = const [],
    this.wearableTerbaru,
    this.pesanEdukasi,
    this.statusKepatuhan,
  });

  HomeState copyWith({
    bool? isLoading,
    String? errorMessage,
    LaporanLabModel? laporanTerbaru,
    List<JadwalObatModel>? jadwalObat,
    WearableModel? wearableTerbaru,
    String? statusKepatuhan,
    String? pesanEdukasi,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      laporanTerbaru: laporanTerbaru ?? this.laporanTerbaru,
      jadwalObat: jadwalObat ?? this.jadwalObat,
      wearableTerbaru: wearableTerbaru ?? this.wearableTerbaru,
      statusKepatuhan: statusKepatuhan ?? this.statusKepatuhan,
      pesanEdukasi: pesanEdukasi ?? this.pesanEdukasi,
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return const HomeState();
  }

  Future<void> fetchAll(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final api = ApiService();

    try {
      // ── 1. Fetch Laporan Lab ──────────────────────────────────
      final laporanResponse = await api.get('/laporan-lab/user/$userId');
      final laporanData = _parseResponseToList(laporanResponse.data);
      LaporanLabModel? laporanTerbaru;

      if (laporanData.isNotEmpty) {
        laporanData.sort((a, b) {
          final dateA = DateTime.tryParse(a['tgl_periksa']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['tgl_periksa']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        laporanTerbaru = LaporanLabModel.fromJson(
          Map<String, dynamic>.from(laporanData.first as Map),
        );
        laporanTerbaru = await _fetchKesimpulanLab(api, laporanTerbaru);
      }

      // ── 2. Fetch Evaluasi Kepatuhan Obat ──
      String? statusKepatuhan;
      String? pesanEdukasi;
      try {
        debugPrint('🔄 [HomeProvider] Fetching Evaluasi Kepatuhan...');
        final kepatuhanResponse = await api.get('/kepatuhan/evaluasi?user_id=$userId');

        final dynamic rawData = kepatuhanResponse.data;
        debugPrint('🔍 [HomeProvider] Tipe data kepatuhan: ${rawData.runtimeType}'); // <--- Debugger ini penting!

        // Logic ekstra aman:
        if (rawData is Map<String, dynamic>) {
          // Jika backend membungkus di 'data'
          final Map<String, dynamic> dataMap = rawData.containsKey('data')
              ? (rawData['data'] is Map ? rawData['data'] : rawData)
              : rawData;

          statusKepatuhan = dataMap['status_kepatuhan']?.toString();
          pesanEdukasi = dataMap['pesan_edukasi']?.toString();
        } else if (rawData is List && rawData.isNotEmpty) {
          // Jika backend langsung kirim List
          final firstItem = rawData[0];
          if (firstItem is Map<String, dynamic>) {
            statusKepatuhan = firstItem['status_kepatuhan']?.toString();
            pesanEdukasi = firstItem['pesan_edukasi']?.toString();
          }
        }

        debugPrint('✅ [HomeProvider] Evaluasi berhasil diproses');
      } catch (e) {
        debugPrint('⚠️ [HomeProvider] Gagal proses data kepatuhan: $e');
      }

      // ── 3. Fetch Obat ─────────────────────────────────────────
      final obatResponse = await api.get('/obat/user/$userId');
      final obatData = _parseResponseToList(obatResponse.data);

      final List<JadwalObatModel> jadwalObatList = [];
      for (final obatJson in obatData) {
        if (obatJson is Map) {
          final obatMap = Map<String, dynamic>.from(obatJson);
          final nestedSchedule = obatMap['jadwal_obat'];

          if (nestedSchedule is List && nestedSchedule.isNotEmpty) {
            for (final item in nestedSchedule) {
              if (item is Map) {
                final scheduleMap = Map<String, dynamic>.from(item);

                // ✅ KUNCI PERBAIKAN: Tangkap ID secara eksplisit seperti sedia kala!
                // (Berjaga-jaga jika backend mengirim 'id_jadwal' alih-alih 'id_jadwal_obat')
                final int idJadwal = _toInt(scheduleMap['id_jadwal_obat']) ?? _toInt(scheduleMap['id_jadwal']) ?? 0;

                if (scheduleMap['waktu_minum_obat'] != null) {
                  scheduleMap['waktu_minum_obat'] = _normalizeTime(scheduleMap['waktu_minum_obat'].toString());
                }

                // Gabungkan data dan paksa suntikkan ID yang valid
                final merged = Map<String, dynamic>.from(obatMap)
                  ..addAll(scheduleMap)
                  ..['id_jadwal_obat'] = idJadwal
                  ..['id_jadwal'] = idJadwal
                  ..['obat'] = obatMap;

                jadwalObatList.add(JadwalObatModel.fromJson(merged));
              }
            }
          } else {
            // Fallback jika tidak ada jadwal terlampir
            jadwalObatList.add(JadwalObatModel.fromJson(obatMap));
          }
        }
      }

      // ── 4. Fetch Wearable ────────────
      final wearableResponse = await api.get('/wearable/user/$userId');
      final wearableData = _parseResponseToList(wearableResponse.data);
      WearableModel? wearableTerbaru;

      if (wearableData.isNotEmpty) {
        wearableData.sort((a, b) {
          final dateA = DateTime.tryParse(a['tgl_data']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['tgl_data']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        final latestRaw = Map<String, dynamic>.from(wearableData.first as Map);
        final hasilAiRaw = latestRaw['hasil_ai_harian'] ?? latestRaw['hasil_ai'];
        if (hasilAiRaw != null) latestRaw['hasil_ai'] = hasilAiRaw;
        wearableTerbaru = WearableModel.fromJson(latestRaw);
      }

      state = state.copyWith(
        isLoading: false,
        laporanTerbaru: laporanTerbaru,
        jadwalObat: jadwalObatList,
        wearableTerbaru: wearableTerbaru,
        statusKepatuhan: statusKepatuhan,
        pesanEdukasi: pesanEdukasi,
      );

    } catch (e) {
      debugPrint('❌ [HomeProvider] Error Fatal: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: _resolveDisplayMessage(e),
      );
    }
  }

  // ── Helper: Ambil AI Gabungan (Lab & Tren) ───────────────
  Future<LaporanLabModel> _fetchKesimpulanLab(
      ApiService api,
      LaporanLabModel laporan,
      ) async {

    if (laporan.idLaporanLab == 0) {
      debugPrint("❌ [HomeProvider] Gagal fetch AI Lab: idLaporanLab = 0");
      return laporan;
    }

    try {
      debugPrint('🔄 [HomeProvider] Fetching AI Lab untuk id_laporan_lab=${laporan.idLaporanLab}');

      final response = await api.get('/hasil-ai/lab/laporan/${laporan.idLaporanLab}');

      if (response.statusCode != 200) {
        debugPrint('⚠️ [HomeProvider] AI Lab belum tersedia (belum di-assess)');
        return laporan;
      }

      // 👇 PERBAIKAN: Keamanan tipe data juga diterapkan di sini
      final rawData = response.data;
      Map<String, dynamic>? data;

      if (rawData is Map) {
        data = rawData['data'] as Map<String, dynamic>? ?? Map<String, dynamic>.from(rawData);
      } else if (rawData is List && rawData.isNotEmpty) {
        data = rawData.first as Map<String, dynamic>?;
      }

      if (data == null || data is! Map<String, dynamic>) {
        debugPrint('⚠️ [HomeProvider] Data AI Lab kosong atau format salah');
        return laporan;
      }

      HasilAIGabunganModel aiModel = HasilAIGabunganModel.fromLabJson(data);

      try {
        final trenResponse = await api.get('/hasil-ai/tren/laporan/${laporan.idLaporanLab}');
        if (trenResponse.statusCode == 200) {
          final rawTren = trenResponse.data;
          Map<String, dynamic>? dataTren;

          if (rawTren is Map) {
            dataTren = rawTren['data'] as Map<String, dynamic>? ?? Map<String, dynamic>.from(rawTren);
          }

          if (dataTren != null) {
            aiModel = aiModel.withTren(dataTren);
          }
        }
      } catch (e) {
        debugPrint('⚠️ [HomeProvider] Tren belum tersedia (wajar untuk laporan pertama)');
      }

      debugPrint('✅ [HomeProvider] AI Lab injected! Interpretasi berhasil');
      return laporan.copyWith(kesimpulanLab: aiModel);

    } catch (e) {
      debugPrint('⚠️ [HomeProvider] Gagal fetch AI Lab: $e');
      return laporan;
    }
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);

// ── Helpers ───────────────────────────────────────────────────
List<dynamic> _parseResponseToList(dynamic data) {
  if (data == null) return [];
  if (data is Map) {
    if (data.containsKey('data') && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    if (data.containsKey('data') && data['data'] is Map) {
      return [data['data']];
    }
    return [data];
  }
  if (data is List) return data;
  return [];
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _normalizeTime(String value) {
  final cleaned = value.trim();
  if (cleaned.length >= 5) return cleaned.substring(0, 5);
  return cleaned;
}

String _resolveDisplayMessage(Object e) {
  if (e is String) {
    // Sudah pesan ramah dari ApiService/ErrorHandler.
    return e;
  }
  // Error parsing/logic lokal → tampilkan pesan generik yang aman.
  return 'Terjadi kendala saat memuat data. Silakan coba lagi.';
}