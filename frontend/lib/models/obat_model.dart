class ObatModel {
  final int idObat;
  final int idUser;
  final String namaObat;
  final String? dosis;
  final String? frekuensi;
  final String? hariKonsumsi; // Tambahan baru
  final bool statusAktif;
  final String? deskripsi;
  final DateTime? tanggalMulai;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ObatModel({
    required this.idObat,
    required this.idUser,
    required this.namaObat,
    this.dosis,
    this.frekuensi,
    this.hariKonsumsi,
    required this.statusAktif,
    this.deskripsi,
    this.tanggalMulai,
    this.createdAt,
    this.updatedAt,
  });

  factory ObatModel.fromJson(Map<String, dynamic> json) {
    return ObatModel(
      idObat: _toInt(json['id_obat']) ?? 0,
      idUser: _toInt(json['id_user']) ?? 0,
      namaObat: json['nama_obat'] as String? ?? '-',
      dosis: json['dosis'] as String?,
      frekuensi: json['frekuensi'] as String?,
      hariKonsumsi: json['hari_konsumsi'] as String?, // Parse dari DB
      statusAktif: json['status_aktif'] == true || json['status_aktif'] == 1,
      deskripsi: json['deskripsi'] as String?,
      tanggalMulai: _parseDateTime(json['tanggal_mulai']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

class JadwalObatModel {
  final int idJadwal;
  final int idUser;
  final int idObat;
  final String? waktuMinumObat;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;
  final bool statusAktif;
  final ObatModel obat;

  JadwalObatModel({
    required this.idJadwal,
    required this.idUser,
    required this.idObat,
    this.waktuMinumObat,
    this.tanggalMulai,
    this.tanggalSelesai,
    required this.statusAktif,
    required this.obat,
  });

  factory JadwalObatModel.fromJson(Map<String, dynamic> json) {
    // Parse nested obat object
    ObatModel obat;
    final dynamic obatRaw = json['obat'];
    if (obatRaw is Map<String, dynamic>) {
      obat = ObatModel.fromJson(obatRaw);
    } else if (obatRaw is Map) {
      obat = ObatModel.fromJson(Map<String, dynamic>.from(obatRaw));
    } else {
      // Default obat jika tidak ada data
      obat = ObatModel(
        idObat: _toInt(json['id_obat']) ?? 0,
        idUser: _toInt(json['id_user']) ?? 0,
        namaObat: '-',
        statusAktif: false,
      );
    }

    return JadwalObatModel(
      idJadwal: _toInt(json['id_jadwal']) ?? _toInt(json['id_jadwal_obat']) ?? 0,
      idUser: _toInt(json['id_user']) ?? 0,
      idObat: _toInt(json['id_obat']) ?? 0,
      waktuMinumObat: json['waktu_minum_obat'] as String?,
      tanggalMulai: _parseDateTime(json['tanggal_mulai']),
      tanggalSelesai: _parseDateTime(json['tanggal_selesai']),
      statusAktif: json['status_aktif'] == true || json['status_aktif'] == 1,
      obat: obat,
    );
  }
}

// Helper functions
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
  if (value is DateTime) return value.toLocal(); // 👈 Tambahkan .toLocal()
  try {
    // 👇 Tambahkan .toLocal() di bagian ujungnya
    return DateTime.parse(value.toString()).toLocal();
  } catch (e) {
    return null;
  }
}