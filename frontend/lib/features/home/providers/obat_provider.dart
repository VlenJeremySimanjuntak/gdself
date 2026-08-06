import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/obat_model.dart';
import '../../../services/api_service.dart';
// TODO: Pastikan path import NotificationService di bawah ini sesuai ya Mas
import '../../../services/notification_service.dart';

// ==========================================
// STATE
// ==========================================
class ObatState {
  final bool isLoading;
  final String? errorMessage;
  final List<ObatModel> obatList;
  final List<JadwalObatModel> jadwalList;
  final List<JadwalObatModel> semuaJadwalList; // ✅ Khusus untuk alarm kolektif
  final List<LogKonsumsiObatModel> logKonsumsiList;
  final Map<int, dynamic> kepatuhanData;
  final Map<int, dynamic> rekapData;

  const ObatState({
    this.isLoading = false,
    this.errorMessage,
    this.obatList = const [],
    this.jadwalList = const [],
    this.semuaJadwalList = const [],
    this.logKonsumsiList = const [],
    this.kepatuhanData = const {},
    this.rekapData = const {},
  });

  ObatState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ObatModel>? obatList,
    List<JadwalObatModel>? jadwalList,
    List<JadwalObatModel>? semuaJadwalList,
    List<LogKonsumsiObatModel>? logKonsumsiList,
    Map<int, dynamic>? kepatuhanData,
    Map<int, dynamic>? rekapData,
    bool clearError = false,
  }) {
    return ObatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      obatList: obatList ?? this.obatList,
      jadwalList: jadwalList ?? this.jadwalList,
      semuaJadwalList: semuaJadwalList ?? this.semuaJadwalList,
      logKonsumsiList: logKonsumsiList ?? this.logKonsumsiList,
      kepatuhanData: kepatuhanData ?? this.kepatuhanData,
      rekapData: rekapData ?? this.rekapData,
    );
  }
}

// ==========================================
// NOTIFIER
// ==========================================
class ObatNotifier extends Notifier<ObatState> {
  late final ApiService _apiService;

  @override
  ObatState build() {
    _apiService = ApiService();
    return const ObatState();
  }

  // ✅ FUNGSI YANG DIPERBAIKI: Mengambil seluruh jadwal dan menyuntikkan ID & Data Induk Obat
  Future<void> syncSemuaJadwalUser(int userId) async {
    try {
      List<JadwalObatModel> allJadwal = [];
      List<Future<Response>> requests = [];

      for (var obat in state.obatList) {
        requests.add(_apiService.get('/jadwal-obat/obat/${obat.idObat}'));
      }

      final responses = await Future.wait(requests);

      for (int i = 0; i < responses.length; i++) {
        final obatParent = state.obatList[i]; // Ambil data induk obat
        final response = responses[i];

        final List<dynamic> dataList = _extractList(response.data);

        for (var item in dataList) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);

            // 1. Tangkap ID jadwal dengan aman
            final idJadwal = _extractInt(map, ['id_jadwal_obat']) ?? _extractInt(map, ['id_jadwal']) ?? 0;
            map['id_jadwal_obat'] = idJadwal;
            map['id_jadwal'] = idJadwal;

            // 2. Suntikkan data induk obat ke dalam JSON jadwal
            map['obat'] = {
              'id_obat': obatParent.idObat,
              'nama_obat': obatParent.namaObat,
              'dosis': obatParent.dosis,
              'tipe_obat': obatParent.tipeObat,
            };

            allJadwal.add(JadwalObatModel.fromJson(map));
          }
        }
      }

      state = state.copyWith(semuaJadwalList: allJadwal);
      await NotificationService().syncSemuaAlarm(allJadwal);
    } catch (e) {
      debugPrint("❌ Gagal sync alarm kolektif: $e");
    }
  }

  Future<void> fetchObat(int userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/obat/user/$userId');
      final List<dynamic> dataList = _extractList(response.data);

      final obatList = dataList
          .whereType<Map>()
          .map((item) => ObatModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(isLoading: false, obatList: obatList, clearError: true);

      // Panggil fungsi sync alarm setiap kali fetchObat sukses
      await syncSemuaJadwalUser(userId);

    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message ?? 'Gagal terhubung ke server');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> hapusObat(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.delete('/obat/$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          obatList: state.obatList.where((obat) => obat.idObat != id).toList(),
          jadwalList: state.jadwalList.where((jadwal) => jadwal.idObat != id).toList(),
          clearError: true,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: _extractMessage(response.data) ?? 'Gagal menghapus obat');
      return false;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message ?? 'Gagal terhubung ke server');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> fetchJadwal(int obatId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/jadwal-obat/obat/$obatId');
      final List<dynamic> dataList = _extractList(response.data);
      final jadwalList = dataList.whereType<Map>().map((item) => JadwalObatModel.fromJson(Map<String, dynamic>.from(item))).toList();
      state = state.copyWith(isLoading: false, jadwalList: jadwalList, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<int?> tambahObatDenganJadwal({
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    required String tanggalSelesai,
    required List<String> hariKonsumsi,
    required String tipeObat,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final responseObat = await _apiService.post('/obat', data: {
        'id_user': userId,
        'nama_obat': namaObat,
        'dosis': dosis,
        'tipe_obat': tipeObat,
        'frekuensi': '${waktuKonsumsi.length}x Sehari',
        'tgl_mulai': tanggalMulai,
        'tgl_selesai': tanggalSelesai,
      });

      if (responseObat.statusCode != 200 && responseObat.statusCode != 201) {
        state = state.copyWith(isLoading: false, errorMessage: _extractMessage(responseObat.data) ?? 'Gagal menambah obat');
        return null;
      }

      final idObat = _extractInt(responseObat.data, ['data', 'id_obat']) ?? _extractInt(responseObat.data, ['id_obat']);
      if (idObat == null || idObat == 0) {
        state = state.copyWith(isLoading: false, errorMessage: 'id_obat tidak ditemukan dari server');
        return null;
      }

      List<Future> jadwalRequests = [];
      for (final hari in hariKonsumsi) {
        for (final waktu in waktuKonsumsi) {
          jadwalRequests.add(_apiService.post('/jadwal-obat', data: {
            'id_obat': idObat,
            'hari': hari,
            'waktu_minum_obat': waktu,
          }));
        }
      }
      await Future.wait(jadwalRequests);

      // ✅ PERBAIKAN: Lepas 'await' agar tambah obat tidak ikut lag
      fetchObat(userId).catchError((e) => debugPrint("Background fetch error: $e"));

      state = state.copyWith(isLoading: false, clearError: true);
      return idObat;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<bool> editObatDenganJadwal({
    required int idObat,
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    required String tanggalSelesai,
    required List<String> hariKonsumsi,
    required String tipeObat,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final responseObat = await _apiService.put('/obat/$idObat', data: {
        'nama_obat': namaObat,
        'dosis': dosis,
        'tipe_obat': tipeObat,
        'frekuensi': '${waktuKonsumsi.length}x Sehari',
        'tgl_mulai': tanggalMulai,
        'tgl_selesai': tanggalSelesai,
      });

      if (responseObat.statusCode != 200) {
        state = state.copyWith(isLoading: false, errorMessage: _extractMessage(responseObat.data) ?? 'Gagal mengedit obat');
        return false;
      }

      final jadwalLamaResponse = await _apiService.get('/jadwal-obat/obat/$idObat');
      final List<dynamic> jadwalLamaRaw = _extractList(jadwalLamaResponse.data);

      final List<Map<String, dynamic>> jadwalLama = jadwalLamaRaw.whereType<Map>().map((item) {
        final idJadwal = _extractInt(item, ['id_jadwal_obat']) ?? _extractInt(item, ['id_jadwal']);
        final hari = (item['hari'] ?? '').toString().trim().toUpperCase();
        final waktuRaw = (item['waktu_minum_obat'] ?? '').toString().trim();
        final waktu = waktuRaw.length >= 5 ? waktuRaw.substring(0, 5) : waktuRaw;
        return {'id': idJadwal, 'hari': hari, 'waktu': waktu};
      }).where((e) => e['id'] != null).toList();

      final List<Map<String, String>> jadwalBaru = [];
      for (final hari in hariKonsumsi) {
        for (final waktu in waktuKonsumsi) {
          final waktuNorm = waktu.length >= 5 ? waktu.substring(0, 5) : waktu;
          jadwalBaru.add({'hari': hari.trim().toUpperCase(), 'waktu': waktuNorm});
        }
      }

      final List<Map<String, dynamic>> sisaLama = List.from(jadwalLama);
      final List<Map<String, String>> sisaBaru = [];

      for (final baru in jadwalBaru) {
        final idxMatch = sisaLama.indexWhere((l) => l['hari'] == baru['hari'] && l['waktu'] == baru['waktu']);
        if (idxMatch != -1) {
          sisaLama.removeAt(idxMatch);
        } else {
          sisaBaru.add(baru);
        }
      }

      final int jumlahPasangan = sisaLama.length < sisaBaru.length ? sisaLama.length : sisaBaru.length;
      List<Future> updateRequests = [];
      for (int i = 0; i < jumlahPasangan; i++) {
        final idJadwal = sisaLama[i]['id'];
        final targetBaru = sisaBaru[i];
        updateRequests.add(_apiService.put('/jadwal-obat/$idJadwal', data: {
          'hari': targetBaru['hari'],
          'waktu_minum_obat': '${targetBaru['waktu']}:00',
        }));
      }
      await Future.wait(updateRequests);

      List<Future> deleteRequests = [];
      for (int i = jumlahPasangan; i < sisaLama.length; i++) {
        deleteRequests.add(_apiService.delete('/jadwal-obat/${sisaLama[i]['id']}'));
      }
      await Future.wait(deleteRequests);

      List<Future> createRequests = [];
      for (int i = jumlahPasangan; i < sisaBaru.length; i++) {
        final targetBaru = sisaBaru[i];
        createRequests.add(_apiService.post('/jadwal-obat', data: {
          'id_obat': idObat,
          'hari': targetBaru['hari'],
          'waktu_minum_obat': '${targetBaru['waktu']}:00',
        }));
      }
      await Future.wait(createRequests);

      // ✅ PERBAIKAN: Jangan pakai 'await' di sini.
      // Biarkan proses pembaruan data dan sinkronisasi alarm berjalan di background.
      fetchObat(userId).catchError((e) => debugPrint("Background fetch error: $e"));

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> fetchLogKonsumsi(int jadwalId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/log-konsumsi/jadwal/$jadwalId');
      final List<dynamic> dataList = _extractList(response.data);
      final logList = dataList.whereType<Map>().map((item) => LogKonsumsiObatModel.fromJson(Map<String, dynamic>.from(item))).toList();
      state = state.copyWith(isLoading: false, logKonsumsiList: logList, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<String?> catatKonsumsi({required int jadwalId, required String status, String? tglKonsumsi}) async {
    try {
      final response = await _apiService.post('/log-konsumsi', data: {
        'id_jadwal_obat': jadwalId,
        'status': status,
        if (tglKonsumsi != null) 'tgl_konsumsi': tglKonsumsi,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchLogKonsumsi(jadwalId);
        return null; // Null berarti SUKSES
      }
      return 'Gagal (HTTP ${response.statusCode})';
    } on DioException catch (e) {
      // Tangkap pesan asli dari Go Backend!
      return _extractMessage(e.response?.data) ?? e.message ?? 'Error API';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> cekStatusKonsumsiHariIni({required int jadwalId}) async {
    try {
      final response = await _apiService.get('/log-konsumsi/jadwal/$jadwalId');
      final List<dynamic> dataList = _extractList(response.data);
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      for (final item in dataList) {
        if (item is Map) {
          final tgl = item['tgl_konsumsi']?.toString() ?? '';
          final status = item['status']?.toString() ?? '';
          final tglOnly = tgl.length >= 10 ? tgl.substring(0, 10) : tgl;
          if (tglOnly == todayStr && (status == 'Terlewat' || status == 'Diminum')) return status;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> cekNotifikasiKepatuhan(int idObat) async {
    try {
      final response = await _apiService.get('/obat/$idObat/notifikasi-kepatuhan');
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          return responseData['data'];
        }
        return responseData;
      }
    } catch (e) {
      debugPrint("❌ Gagal mengambil data AI Notifikasi: $e");
    }
    return null;
  }

  Future<dynamic> cekNotifikasiKepatuhanUser(int userId) async {
    try {
      final response = await _apiService.get('/obat/user/$userId/notifikasi-kepatuhan');
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          return responseData['data'];
        }
        return responseData;
      }
    } catch (e) {
      debugPrint("❌ Gagal cek kepatuhan user: $e");
    }
    return null;
  }

  Future<void> fetchKepatuhanObat(int obatId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/kepatuhan-obat/$obatId');
      final currentMap = Map<int, dynamic>.from(state.kepatuhanData);
      currentMap[obatId] = response.data['data'];
      state = state.copyWith(isLoading: false, kepatuhanData: currentMap, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchRekapObat(int obatId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/obat/$obatId/rekap');
      final currentMap = Map<int, dynamic>.from(state.rekapData);
      currentMap[obatId] = response.data['data'];
      state = state.copyWith(isLoading: false, rekapData: currentMap, clearError: true);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message ?? 'Gagal memuat rekap obat');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchSemuaLogUntukObat(List<int> listJadwalId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      List<LogKonsumsiObatModel> allLogs = [];
      const int chunkSize = 3;
      for (var i = 0; i < listJadwalId.length; i += chunkSize) {
        int end = (i + chunkSize < listJadwalId.length) ? i + chunkSize : listJadwalId.length;
        List<int> chunk = listJadwalId.sublist(i, end);
        List<Future<Response>> chunkRequests = [];
        for (int jId in chunk) {
          chunkRequests.add(_apiService.get('/log-konsumsi/jadwal/$jId'));
        }
        final responses = await Future.wait(chunkRequests);
        for (final response in responses) {
          final List<dynamic> dataList = _extractList(response.data);
          final logList = dataList.whereType<Map>().map((item) => LogKonsumsiObatModel.fromJson(Map<String, dynamic>.from(item))).toList();
          allLogs.addAll(logList);
        }
      }
      state = state.copyWith(isLoading: false, logKonsumsiList: allLogs, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearLogKonsumsi() {
    state = state.copyWith(logKonsumsiList: []);
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is List) return data['data'] as List<dynamic>;
    if (data is List) return data;
    return <dynamic>[];
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String) return message;
      final error = data['error'];
      if (error is String) return error;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'];
      if (message is String) return message;
      final error = map['error'];
      if (error is String) return error;
    }
    return null;
  }

  int? _extractInt(dynamic source, List<String> path) {
    dynamic current = source;
    for (final key in path) {
      if (current is Map) {
        current = current[key];
      } else {
        return null;
      }
    }
    if (current is int) return current;
    if (current is num) return current.toInt();
    if (current == null) return null;
    return int.tryParse(current.toString());
  }
}

final obatProvider = NotifierProvider<ObatNotifier, ObatState>(ObatNotifier.new);