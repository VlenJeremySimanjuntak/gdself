import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/lab_data_model.dart';
import '../../../models/obat_model.dart';
import '../../../models/wearable_model.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../../services/api_service.dart';

class HomeState {
  final bool isLoading;
  final String? errorMessage;
  final LaporanLabModel? laporanTerbaru;
  final List<JadwalObatModel> jadwalObat;
  final WearableModel? wearableTerbaru;

  const HomeState({
    this.isLoading = false,
    this.errorMessage,
    this.laporanTerbaru,
    this.jadwalObat = const [],
    this.wearableTerbaru,
  });

  HomeState copyWith({
    bool? isLoading,
    String? errorMessage,
    LaporanLabModel? laporanTerbaru,
    List<JadwalObatModel>? jadwalObat,
    WearableModel? wearableTerbaru,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      laporanTerbaru: laporanTerbaru ?? this.laporanTerbaru,
      jadwalObat: jadwalObat ?? this.jadwalObat,
      wearableTerbaru: wearableTerbaru ?? this.wearableTerbaru,
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return const HomeState();
  }

  Future<void> fetchAll(int userId) async {
    debugPrint('🔄 [HomeProvider] fetchAll called for userId=$userId');
    state = state.copyWith(isLoading: true, errorMessage: null);
    final api = ApiService();

    try {
      // ── 1. Fetch Laporan Lab ──────────────────────────────────
      final laporanResponse = await api.get('/laporan-lab/user/$userId');
      final laporanData = _parseResponseToList(laporanResponse.data);
      LaporanLabModel? laporanTerbaru;

      if (laporanData.isNotEmpty) {
        // 👇 TAMBAHAN: Sorting data lab berdasarkan tanggal terbaru (Descending)
        laporanData.sort((a, b) {
          final dateA = DateTime.tryParse(a['tgl_periksa']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['tgl_periksa']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        debugPrint("======== 🔍 RAW JSON LAPORAN LAB TERBARU ========");
        debugPrint(laporanData.first.toString());
        debugPrint("=========================================");

        // Mengambil data index ke-0 yang SUDAH PASTI terbaru berkat sorting di atas
        laporanTerbaru = LaporanLabModel.fromJson(
          laporanData.first as Map<String, dynamic>,
        );
        debugPrint('📋 [HomeProvider] Laporan lab ditemukan: id=${laporanTerbaru.idLaporanLab}, id_riwayat=${laporanTerbaru.idRiwayat}');

        // Inject kesimpulanLab (Mengambil HasilAIGabunganModel)
        laporanTerbaru = await _fetchKesimpulanLab(api, laporanTerbaru);
      } else {
        debugPrint('📋 [HomeProvider] Tidak ada laporan lab');
      }

      // ── 2. Fetch Obat ─────────────────────────────────────────
      debugPrint('🔄 [HomeProvider] Fetching obat...');
      final obatResponse = await api.get('/obat/user/$userId');
      final obatData = _parseResponseToList(obatResponse.data);
      debugPrint('📥 [HomeProvider] obatData length=${obatData.length}');

      final List<JadwalObatModel> jadwalObatList = [];
      for (final obatJson in obatData) {
        final obatMap = Map<String, dynamic>.from(obatJson as Map);

        final nestedSchedule = obatMap['jadwal_obat'];

        if (nestedSchedule is List && nestedSchedule.isNotEmpty) {
          final waktuList = <String>[];
          Map<String, dynamic>? firstSchedule;

          for (final item in nestedSchedule) {
            if (item is Map) {
              final scheduleMap = Map<String, dynamic>.from(item);
              firstSchedule ??= scheduleMap;
              final rawTime = scheduleMap['waktu_minum_obat']?.toString();
              if (rawTime != null && rawTime.isNotEmpty) {
                waktuList.add(_normalizeTime(rawTime));
              }
            }
          }

          final merged = Map<String, dynamic>.from(obatMap)
            ..['id_jadwal'] = _toInt(firstSchedule?['id_jadwal_obat']) ?? 0
            ..['waktu_minum_obat'] = waktuList.join(', ')
            ..['obat'] = obatMap;

          jadwalObatList.add(JadwalObatModel.fromJson(merged));
          continue;
        }

        jadwalObatList.add(JadwalObatModel.fromJson(obatMap));
      }
      debugPrint('✅ [HomeProvider] Total jadwalObat: ${jadwalObatList.length}');

      // ── 3. Fetch Wearable (Jam Tangan & AI Harian) ────────────
      final wearableResponse = await api.get('/wearable/user/$userId');
      debugPrint('📡 [HomeProvider] Raw wearable response: ${wearableResponse.data}');

      final wearableData = _parseResponseToList(wearableResponse.data);
      WearableModel? wearableTerbaru;

      if (wearableData.isNotEmpty) {
        // 👇 TAMBAHAN: Sorting data wearable berdasarkan tanggal & waktu terbaru (Descending)
        wearableData.sort((a, b) {
          final dateA = DateTime.tryParse(a['tgl_data']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['tgl_data']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        // 👇 Menggunakan .first (karena yang terbaru sudah di posisi atas berkat sorting)
        final latestRaw = Map<String, dynamic>.from(wearableData.first as Map);
        debugPrint('📡 [HomeProvider] wearable terbaru raw: $latestRaw');

        // Antisipasi key baru dari Backend untuk AI Harian
        final hasilAiRaw = latestRaw['hasil_ai_harian'] ?? latestRaw['hasil_ai'];
        final bool hasilAiKosong =
            hasilAiRaw == null || (hasilAiRaw is List && hasilAiRaw.isEmpty);

        if (hasilAiKosong) {
          final wearableId = latestRaw['id_wearable'];
          debugPrint('📡 [HomeProvider] AI Harian kosong, fetch manual id_wearable=$wearableId');

          try {
            // Jika Backend mengubah endpoint, sesuaikan URL ini
            final aiResponse = await api.get('/hasil-ai/wearable/$wearableId');

            final aiList = _parseResponseToList(aiResponse.data);
            if (aiList.isNotEmpty) {
              latestRaw['hasil_ai'] = aiList; // Inject ke key 'hasil_ai'
              debugPrint('📡 [HomeProvider] Injected ${aiList.length} AI Harian ke wearable');
            }
          } catch (e) {
            debugPrint('⚠️ [HomeProvider] Gagal fetch AI Harian manual: $e');
          }
        }

        wearableTerbaru = WearableModel.fromJson(latestRaw);
        debugPrint('📡 [HomeProvider] AI Harian count: ${wearableTerbaru.hasilAI.length}');
        if (wearableTerbaru.hasilAI.isNotEmpty) {
          debugPrint('📡 [HomeProvider] Pesan Harian: ${wearableTerbaru.hasilAI.last.pesanHarian}');
        }
      }

      // ── 4. Update state ───────────────────────────────────────
      state = state.copyWith(
        isLoading: false,
        laporanTerbaru: laporanTerbaru,
        jadwalObat: jadwalObatList,
        wearableTerbaru: wearableTerbaru,
      );
      debugPrint('✅ [HomeProvider] State updated');

    } catch (e) {
      debugPrint('❌ [HomeProvider] Error: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // ── Helper: Ambil AI Gabungan (Lab & Tren) ───────────────
  Future<LaporanLabModel> _fetchKesimpulanLab(
      ApiService api,
      LaporanLabModel laporan,
      ) async {

    if (laporan.idRiwayat == null) {
      debugPrint("❌ [HomeProvider] Gagal fetch AI Lab: idRiwayat bernilai null!");
      return laporan;
    }

    try {
      debugPrint('🔄 [HomeProvider] Fetching AI Gabungan (Lab) untuk id_riwayat=${laporan.idRiwayat}');

      final response = await api.get('/hasil-ai/riwayat/${laporan.idRiwayat}');

      final list = _parseResponseToList(response.data);
      if (list.isEmpty) {
        debugPrint('⚠️ [HomeProvider] Tidak ada AI Gabungan untuk riwayat ini');
        return laporan;
      }

      HasilAIGabunganModel? aiLab;
      for (final item in list) {
        final map = Map<String, dynamic>.from(item as Map);
        if (map['kesimpulan_lab'] != null || map['trend_report'] != null) {
          aiLab = HasilAIGabunganModel.fromJson(map);
          break;
        }
      }

      if (aiLab == null) {
        debugPrint('⚠️ [HomeProvider] Data ada, tapi kolom kesimpulan_lab kosong');
        return laporan;
      }

      debugPrint('✅ [HomeProvider] AI Gabungan Injected! Kesimpulan: ${aiLab.kesimpulanLab}');
      return laporan.copyWith(kesimpulanLab: aiLab);

    } catch (e) {
      debugPrint('⚠️ [HomeProvider] Gagal fetch AI Gabungan: $e');
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