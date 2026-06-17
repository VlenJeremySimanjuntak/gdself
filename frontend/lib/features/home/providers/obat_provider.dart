import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/obat_model.dart';
import '../../../services/api_service.dart';

// ==========================================
// STATE
// ==========================================
class ObatState {
  final bool isLoading;
  final String? errorMessage;
  final List<ObatModel> obatList;
  final List<JadwalObatModel> jadwalList;
  final List<LogKonsumsiObatModel> logKonsumsiList; // ✅ Tambahan

  const ObatState({
    this.isLoading = false,
    this.errorMessage,
    this.obatList = const [],
    this.jadwalList = const [],
    this.logKonsumsiList = const [], // ✅ Default kosong
  });

  ObatState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ObatModel>? obatList,
    List<JadwalObatModel>? jadwalList,
    List<LogKonsumsiObatModel>? logKonsumsiList, // ✅ Tambahan
    bool clearError = false,
  }) {
    return ObatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      obatList: obatList ?? this.obatList,
      jadwalList: jadwalList ?? this.jadwalList,
      logKonsumsiList: logKonsumsiList ?? this.logKonsumsiList, // ✅ Tambahan
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

  // ==========================================
  // OBAT
  // ==========================================

  Future<void> fetchObat(int userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/obat/user/$userId');
      final List<dynamic> dataList = _extractList(response.data);

      final obatList = dataList
          .whereType<Map>()
          .map((item) => ObatModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        obatList: obatList,
        clearError: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> tambahObat({
    required int userId,
    required String namaObat,
    required String dosis,
    required String frekuensi,
    String? tglMulai,
    String? tglSelesai,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.post(
        '/obat',
        data: {
          'id_user': userId,
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': frekuensi,
          'tgl_mulai': tglMulai,
          'tgl_selesai': tglSelesai,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchObat(userId);
        state = state.copyWith(isLoading: false, clearError: true);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractMessage(response.data) ?? 'Gagal menambah obat',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> editObat({
    required int id,
    required String namaObat,
    required String dosis,
    required String frekuensi,
    String? tglMulai,
    String? tglSelesai,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.put(
        '/obat/$id',
        data: {
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': frekuensi,
          'tgl_mulai': tglMulai,
          'tgl_selesai': tglSelesai,
        },
      );

      if (response.statusCode == 200) {
        await fetchObat(
            state.obatList.firstWhere((o) => o.idObat == id).idUser);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractMessage(response.data) ?? 'Gagal mengedit obat',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> hapusObat(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.delete('/obat/$id');

      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          obatList:
          state.obatList.where((obat) => obat.idObat != id).toList(),
          jadwalList:
          state.jadwalList.where((jadwal) => jadwal.idObat != id).toList(),
          clearError: true,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage:
        _extractMessage(response.data) ?? 'Gagal menghapus obat',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // ==========================================
  // JADWAL OBAT
  // ==========================================

  Future<void> fetchJadwal(int obatId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/jadwal-obat/obat/$obatId');
      final List<dynamic> dataList = _extractList(response.data);

      final jadwalList = dataList
          .whereType<Map>()
          .map((item) =>
          JadwalObatModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        jadwalList: jadwalList,
        clearError: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> tambahJadwal({
    required int obatId,
    required String hari,
    required String waktuMinum,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.post(
        '/jadwal-obat',
        data: {
          'id_obat': obatId,
          'hari': hari,
          'waktu_minum_obat': waktuMinum,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchJadwal(obatId);
        state = state.copyWith(isLoading: false, clearError: true);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage:
        _extractMessage(response.data) ?? 'Gagal menambah jadwal',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Simpan obat + jadwal sekaligus (dipakai saat tambah obat baru)
  Future<bool> tambahObatDenganJadwal({
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    required List<String> hariKonsumsi,
    String? tanggalSelesai,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Simpan master obat
      final responseObat = await _apiService.post(
        '/obat',
        data: {
          'id_user': userId,
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': '${waktuKonsumsi.length}x Sehari',
          'tgl_mulai': tanggalMulai,
          'tgl_selesai': tanggalSelesai,
        },
      );

      if (responseObat.statusCode != 200 && responseObat.statusCode != 201) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
          _extractMessage(responseObat.data) ?? 'Gagal menambah obat',
        );
        return false;
      }

      final idObat =
          _extractInt(responseObat.data, ['data', 'id_obat']) ??
              _extractInt(responseObat.data, ['id_obat']);

      if (idObat == null || idObat == 0) {
        throw Exception('id_obat tidak ditemukan dari server');
      }

      // 2. Simpan jadwal (per hari × per jam)
      for (final hari in hariKonsumsi) {
        for (final waktu in waktuKonsumsi) {
          await _apiService.post(
            '/jadwal-obat',
            data: {
              'id_obat': idObat,
              'hari': hari,
              'waktu_minum_obat': waktu,
            },
          );
        }
      }

      await fetchObat(userId);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Edit obat + replace semua jadwal lama dengan jadwal baru
  Future<bool> editObatDenganJadwal({
    required int idObat,
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    String? tanggalSelesai,
    required List<String> hariKonsumsi,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Update master obat
      final responseObat = await _apiService.put(
        '/obat/$idObat',
        data: {
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': '${waktuKonsumsi.length}x Sehari',
          'tgl_mulai': tanggalMulai,
          'tgl_selesai': tanggalSelesai,
        },
      );

      if (responseObat.statusCode != 200) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
          _extractMessage(responseObat.data) ?? 'Gagal mengedit obat',
        );
        return false;
      }

      // 2. Hapus semua jadwal lama
      final jadwalLamaResponse =
      await _apiService.get('/jadwal-obat/obat/$idObat');
      final List<dynamic> jadwalLama = _extractList(jadwalLamaResponse.data);
      for (final item in jadwalLama) {
        final idJadwal = _extractInt(item, ['id_jadwal_obat']) ??
            _extractInt(item, ['id_jadwal']);
        if (idJadwal != null) {
          await _apiService.delete('/jadwal-obat/$idJadwal');
        }
      }

      // 3. Masukkan jadwal baru
      for (final hari in hariKonsumsi) {
        for (final waktu in waktuKonsumsi) {
          await _apiService.post(
            '/jadwal-obat',
            data: {
              'id_obat': idObat,
              'hari': hari,
              'waktu_minum_obat': waktu,
            },
          );
        }
      }

      await fetchObat(userId);
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  // ==========================================
  // LOG KONSUMSI OBAT
  // ==========================================

  /// Ambil riwayat konsumsi untuk satu jadwal tertentu
  Future<void> fetchLogKonsumsi(int jadwalId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
      await _apiService.get('/log-konsumsi/jadwal/$jadwalId');
      final List<dynamic> dataList = _extractList(response.data);

      final logList = dataList
          .whereType<Map>()
          .map((item) => LogKonsumsiObatModel.fromJson(
          Map<String, dynamic>.from(item)))
          .toList();

      state = state.copyWith(
        isLoading: false,
        logKonsumsiList: logList,
        clearError: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal memuat log konsumsi',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Catat konsumsi obat — dipanggil saat user tap "Sudah Diminum"
  /// atau sistem otomatis catat "Terlewat" setelah user tap "Batal" dua kali
  Future<bool> catatKonsumsi({
    required int jadwalId,
    required String status, // "Diminum" atau "Terlewat"
    String? tglKonsumsi,   // format "yyyy-MM-dd", kalau null pakai hari ini
  }) async {
    try {
      final response = await _apiService.post(
        '/log-konsumsi',
        data: {
          'id_jadwal_obat': jadwalId,
          'status': status,
          if (tglKonsumsi != null) 'tgl_konsumsi': tglKonsumsi,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh log setelah catat agar UI terupdate
        await fetchLogKonsumsi(jadwalId);
        return true;
      }
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        errorMessage: e.message ?? 'Gagal mencatat konsumsi',
      );
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  /// Reset log konsumsi di state (saat pindah ke jadwal lain)
  void clearLogKonsumsi() {
    state = state.copyWith(logKonsumsiList: []);
  }

  // ==========================================
  // HELPER
  // ==========================================

  List<dynamic> _extractList(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
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

final obatProvider =
NotifierProvider<ObatNotifier, ObatState>(ObatNotifier.new);