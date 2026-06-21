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
          // 👇 KELOMPOKKAN WAKTU BERDASARKAN HARI
          final Map<String, List<String>> timesByDay = {};
          final Map<String, int> idJadwalByDay = {};

          for (final item in nestedSchedule) {
            if (item is Map) {
              final scheduleMap = Map<String, dynamic>.from(item);
              final hari = scheduleMap['hari']?.toString().trim() ?? '';
              final rawTime = scheduleMap['waktu_minum_obat']?.toString();
              final idJadwal = _toInt(scheduleMap['id_jadwal_obat']) ?? _toInt(scheduleMap['id_jadwal']) ?? 0;

              if (hari.isNotEmpty && rawTime != null && rawTime.isNotEmpty) {
                // Masukkan jam ke kelompok harinya masing-masing
                timesByDay.putIfAbsent(hari, () => []).add(_normalizeTime(rawTime));
                idJadwalByDay.putIfAbsent(hari, () => idJadwal);
              }
            }
          }

          if (timesByDay.isNotEmpty) {
            // 👇 BUAT MODEL JADWAL PER HARI
            for (final entry in timesByDay.entries) {
              final hari = entry.key;
              final times = entry.value..sort(); // Urutkan jam dari pagi ke malam

              final merged = Map<String, dynamic>.from(obatMap)
                ..['id_jadwal_obat'] = idJadwalByDay[hari]
                ..['id_jadwal'] = idJadwalByDay[hari]
                ..['hari'] = hari
                ..['waktu_minum_obat'] = times.join(', ') // Gabungkan jam dengan koma (Contoh: "08:00, 12:00")
                ..['obat'] = obatMap;

              jadwalObatList.add(JadwalObatModel.fromJson(merged));
            }
            continue; // Lanjut ke obat berikutnya
          }
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
        // Sorting data wearable berdasarkan tanggal & waktu terbaru (Descending)
        wearableData.sort((a, b) {
          final dateA = DateTime.tryParse(a['tgl_data']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['tgl_data']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        // Menggunakan .first (karena yang terbaru sudah di posisi atas berkat sorting)
        final latestRaw = Map<String, dynamic>.from(wearableData.first as Map);
        debugPrint('📡 [HomeProvider] wearable terbaru raw: $latestRaw');

        // Antisipasi key dari Backend Golang (bisa 'hasil_ai_harian' atau 'hasil_ai')
        final hasilAiRaw = latestRaw['hasil_ai_harian'] ?? latestRaw['hasil_ai'];

        // Memastikan key yang benar dipakai oleh WearableModel.fromJson
        if (hasilAiRaw != null) {
          latestRaw['hasil_ai'] = hasilAiRaw;
        }

        wearableTerbaru = WearableModel.fromJson(latestRaw);

        // 👇 PERBAIKAN ERROR: Menggunakan field yang baru (reminderHr) untuk debugPrint
        debugPrint('📡 [HomeProvider] AI Harian count: ${wearableTerbaru.hasilAI.length}');
        if (wearableTerbaru.hasilAI.isNotEmpty) {
          debugPrint('📡 [HomeProvider] Reminder HR: ${wearableTerbaru.hasilAI.last.reminderHr}');
          debugPrint('📡 [HomeProvider] Reminder Tidur: ${wearableTerbaru.hasilAI.last.reminderTidur}');
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

    if (laporan.idLaporanLab == 0) {
      debugPrint("❌ [HomeProvider] Gagal fetch AI Lab: idLaporanLab = 0");
      return laporan;
    }

    try {
      debugPrint('🔄 [HomeProvider] Fetching AI Lab untuk id_laporan_lab=${laporan.idLaporanLab}');

      // Sesuai route: /hasil-ai/lab/laporan/:laporan_lab_id
      final response = await api.get('/hasil-ai/lab/laporan/${laporan.idLaporanLab}');

      if (response.statusCode != 200) {
        debugPrint('⚠️ [HomeProvider] AI Lab belum tersedia (belum di-assess)');
        return laporan;
      }

      final data = response.data['data'];
      if (data == null || data is! Map<String, dynamic>) {
        debugPrint('⚠️ [HomeProvider] Data AI Lab kosong');
        return laporan;
      }

      // Parse AI Lab
      HasilAIGabunganModel aiModel = HasilAIGabunganModel.fromLabJson(data);

      // Coba fetch tren (opsional)
      try {
        final trenResponse = await api.get('/hasil-ai/tren/laporan/${laporan.idLaporanLab}');
        if (trenResponse.statusCode == 200) {
          final dataTren = trenResponse.data['data'];
          if (dataTren != null && dataTren is Map<String, dynamic>) {
            aiModel = aiModel.withTren(dataTren);
          }
        }
      } catch (e) {
        debugPrint('⚠️ [HomeProvider] Tren belum tersedia (wajar untuk laporan pertama): $e');
      }

      debugPrint('✅ [HomeProvider] AI Lab injected! Interpretasi: ${aiModel.interpretasi}');
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