import 'hasil_ai_gabungan_model.dart';

class ParameterLabModel {
  final int idParameter;
  final int idHasilLab;
  final String namaParameter;
  final String? satuan;
  final String? kategori;
  final double nilaiHasil; // ✅ sudah diubah dari 'nilai' menjadi 'nilaiHasil'

  ParameterLabModel({
    required this.idParameter,
    required this.idHasilLab,
    required this.namaParameter,
    this.satuan,
    this.kategori,
    required this.nilaiHasil,
  });

  factory ParameterLabModel.fromJson(Map<String, dynamic> json) {
    return ParameterLabModel(
      idParameter: _toInt(json['id_parameter']) ?? 0,
      idHasilLab: _toInt(json['id_hasil_lab']) ?? 0,
      namaParameter: json['nama_parameter'] as String? ?? '-',
      satuan: json['satuan'] as String?,
      kategori: json['kategori'] as String?,
      nilaiHasil: _toDouble(json['nilai_hasil']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_parameter': namaParameter,
      'nilai_hasil': nilaiHasil,
      'satuan': satuan,
      'kategori': kategori,
    };
  }
}

class HasilLabModel {
  final int idHasilLab;
  final double nilaiHasil;
  final double rujukanMin;   // ← tetap pakai nama ini di model FE
  final double rujukanMax;   // ← tapi akan diisi dari nilai_batas_bawah/atas
  final List<ParameterLabModel> parameters;

  HasilLabModel({
    required this.idHasilLab,
    required this.nilaiHasil,
    required this.rujukanMin,
    required this.rujukanMax,
    required this.parameters,
  });

  factory HasilLabModel.fromJson(Map<String, dynamic> json) {
    final dynamic paramObj = json['parameter'];
    List<ParameterLabModel> params = [];

    if (paramObj != null && paramObj is Map<String, dynamic>) {
      // Gabungkan data dari parent ke parameter
      final merged = Map<String, dynamic>.from(paramObj);
      merged['nilai_hasil'] = json['nilai_hasil'] ?? 0.0;
      merged['id_hasil_lab'] = json['id_hasil_lab'] ?? 0;
      params.add(ParameterLabModel.fromJson(merged));
    }

    return HasilLabModel(
      idHasilLab: _toInt(json['id_hasil_lab']) ?? 0,
      nilaiHasil: _toDouble(json['nilai_hasil']) ?? 0.0,
      // ✅ Perbaikan: baca dari nilai_batas_bawah dan nilai_batas_atas
      rujukanMin: _toDouble(json['nilai_batas_bawah']) ?? 0.0,
      rujukanMax: _toDouble(json['nilai_batas_atas']) ?? 0.0,
      parameters: params,
    );
  }
}

class LaporanLabModel {
  final int idLaporanLab;
  final int idUser;
  final int? idRiwayat;
  final DateTime? tglPeriksa;
  final String? namaLab;
  final List<HasilLabModel> hasilLab;
  final HasilAIGabunganModel? kesimpulanLab;

  LaporanLabModel({
    required this.idLaporanLab,
    required this.idUser,
    this.idRiwayat,
    this.tglPeriksa,
    this.namaLab,
    required this.hasilLab,
    this.kesimpulanLab,
  });

  LaporanLabModel copyWith({HasilAIGabunganModel? kesimpulanLab}) {
    return LaporanLabModel(
      idLaporanLab: idLaporanLab,
      idUser: idUser,
      idRiwayat: idRiwayat,
      tglPeriksa: tglPeriksa,
      namaLab: namaLab,
      hasilLab: hasilLab,
      kesimpulanLab: kesimpulanLab ?? this.kesimpulanLab,
    );
  }

  factory LaporanLabModel.fromJson(Map<String, dynamic> json) {
    final dynamic hasilLabRaw = json['hasil_lab'] ?? json['hasil_labs'];
    List<HasilLabModel> hasilList = [];
    int? extractedIdRiwayat;

    if (hasilLabRaw != null) {
      if (hasilLabRaw is List) {
        hasilList = hasilLabRaw
            .whereType<Map>()
            .map((e) {
          if (extractedIdRiwayat == null && e['id_riwayat'] != null) {
            extractedIdRiwayat = _toInt(e['id_riwayat']);
          }
          return HasilLabModel.fromJson(Map<String, dynamic>.from(e));
        })
            .toList();
      }
    }

    return LaporanLabModel(
      idLaporanLab: _toInt(json['id_laporan_lab']) ?? 0,
      idUser: _toInt(json['id_user']) ?? 0,
      idRiwayat: _toInt(json['id_riwayat']) ?? extractedIdRiwayat,
      tglPeriksa: _parseDateTime(json['tgl_periksa']),
      namaLab: json['nama_lab'] as String?,
      hasilLab: hasilList,
      kesimpulanLab: null,
    );
  }
}

// --- Helper functions ---
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    return DateTime.parse(value.toString());
  } catch (e) {
    return null;
  }
}