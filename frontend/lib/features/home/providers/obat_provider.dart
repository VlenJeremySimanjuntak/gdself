import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/obat_model.dart';
import '../../../services/api_service.dart';

class ObatState {
  final bool isLoading;
  final String? errorMessage;
  final List<ObatModel> obatList;
  final List<JadwalObatModel> jadwalList;

  const ObatState({
    this.isLoading = false,
    this.errorMessage,
    this.obatList = const [],
    this.jadwalList = const [],
  });

  ObatState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<ObatModel>? obatList,
    List<JadwalObatModel>? jadwalList,
    bool clearError = false,
  }) {
    return ObatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      obatList: obatList ?? this.obatList,
      jadwalList: jadwalList ?? this.jadwalList,
    );
  }
}

class ObatNotifier extends Notifier<ObatState> {
  late final ApiService _apiService;

  @override
  ObatState build() {
    _apiService = ApiService();
    return const ObatState();
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
    String? hariKonsumsi,
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
          'hari_konsumsi': hariKonsumsi ?? '',
          'status_aktif': true,
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> editObat({
    required int id,
    required String namaObat,
    required String dosis,
    required String frekuensi,
    required bool statusAktif,
    String? hariKonsumsi,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.put(
        '/obat/$id',
        data: {
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': frekuensi,
          'hari_konsumsi': hariKonsumsi ?? '',
          'status_aktif': statusAktif,
        },
      );

      if (response.statusCode == 200) {
        final updatedObatList = state.obatList
            .map(
              (obat) => obat.idObat == id
              ? ObatModel(
            idObat: obat.idObat,
            idUser: obat.idUser,
            namaObat: namaObat,
            dosis: dosis,
            frekuensi: frekuensi,
            hariKonsumsi: hariKonsumsi,
            statusAktif: statusAktif,
            deskripsi: obat.deskripsi,
            createdAt: obat.createdAt,
            updatedAt: DateTime.now(),
          )
              : obat,
        )
            .toList();

        state = state.copyWith(
          isLoading: false,
          obatList: updatedObatList,
          clearError: true,
        );
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
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
          obatList: state.obatList.where((obat) => obat.idObat != id).toList(),
          jadwalList: state.jadwalList.where((jadwal) => jadwal.idObat != id).toList(),
          clearError: true,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractMessage(response.data) ?? 'Gagal menghapus obat',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> fetchJadwal(int obatId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.get('/jadwal-obat/obat/$obatId');
      final List<dynamic> dataList = _extractList(response.data);

      final jadwalList = dataList
          .whereType<Map>()
          .map((item) => JadwalObatModel.fromJson(Map<String, dynamic>.from(item)))
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> tambahJadwal({
    required int obatId,
    required String waktuMinum,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.post(
        '/jadwal-obat',
        data: {
          'id_obat': obatId,
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
        errorMessage: _extractMessage(response.data) ?? 'Gagal menambah jadwal',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> editJadwal({
    required int id,
    required String waktuMinum,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.put(
        '/jadwal-obat/$id',
        data: {
          'waktu_minum_obat': waktuMinum,
        },
      );

      if (response.statusCode == 200) {
        final updatedJadwalList = state.jadwalList
            .map(
              (jadwal) => jadwal.idJadwal == id
              ? JadwalObatModel(
            idJadwal: jadwal.idJadwal,
            idUser: jadwal.idUser,
            idObat: jadwal.idObat,
            waktuMinumObat: waktuMinum,
            tanggalMulai: jadwal.tanggalMulai,
            tanggalSelesai: jadwal.tanggalSelesai,
            statusAktif: jadwal.statusAktif,
            obat: jadwal.obat,
          )
              : jadwal,
        )
            .toList();

        state = state.copyWith(
          isLoading: false,
          jadwalList: updatedJadwalList,
          clearError: true,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractMessage(response.data) ?? 'Gagal mengedit jadwal',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> hapusJadwal(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiService.delete('/jadwal-obat/$id');
      if (response.statusCode == 200) {
        state = state.copyWith(
          isLoading: false,
          jadwalList: state.jadwalList.where((jadwal) => jadwal.idJadwal != id).toList(),
          clearError: true,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _extractMessage(response.data) ?? 'Gagal menghapus jadwal',
      );
      return false;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message ?? 'Gagal terhubung ke server',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> tambahObatDenganJadwal({
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    required List<String> hariKonsumsi,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final responseObat = await _apiService.post(
        '/obat',
        data: {
          'id_user': userId,
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': '${waktuKonsumsi.length}x Sehari',
          'tanggal_mulai': tanggalMulai,
          'hari_konsumsi': hariKonsumsi.join(','),
          'status_aktif': true,
        },
      );

      if (responseObat.statusCode != 200 && responseObat.statusCode != 201) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _extractMessage(responseObat.data) ?? 'Gagal menambah obat',
        );
        return false;
      }

      final idObat = _extractInt(responseObat.data, ['data', 'id_obat']) ??
          _extractInt(responseObat.data, ['id_obat']);

      if (idObat == null || idObat == 0) {
        throw Exception('id_obat tidak ditemukan dari server');
      }

      for (final waktu in waktuKonsumsi) {
        await _apiService.post(
          '/jadwal-obat',
          data: {
            'id_obat': idObat,
            'waktu_minum_obat': waktu,
          },
        );
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> editObatDenganJadwal({
    required int idObat,
    required int userId,
    required String namaObat,
    required String dosis,
    required List<String> waktuKonsumsi,
    required String tanggalMulai,
    required bool statusAktif,
    required List<String> hariKonsumsi,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final responseObat = await _apiService.put(
        '/obat/$idObat',
        data: {
          'nama_obat': namaObat,
          'dosis': dosis,
          'frekuensi': '${waktuKonsumsi.length}x Sehari',
          'tanggal_mulai': tanggalMulai,
          'hari_konsumsi': hariKonsumsi.join(','),
          'status_aktif': statusAktif,
        },
      );

      if (responseObat.statusCode != 200) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: _extractMessage(responseObat.data) ?? 'Gagal mengedit obat',
        );
        return false;
      }

      final jadwalLamaResponse = await _apiService.get('/jadwal-obat/obat/$idObat');
      final List<dynamic> jadwalLama = _extractList(jadwalLamaResponse.data);
      for (final item in jadwalLama) {
        final idJadwal = _extractInt(item, ['id_jadwal_obat']) ??
            _extractInt(item, ['id_jadwal']);
        if (idJadwal != null) {
          await _apiService.delete('/jadwal-obat/$idJadwal');
        }
      }

      for (final waktu in waktuKonsumsi) {
        await _apiService.post(
          '/jadwal-obat',
          data: {
            'id_obat': idObat,
            'waktu_minum_obat': waktu,
          },
        );
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List<dynamic>;
    }
    if (data is List) {
      return data;
    }
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