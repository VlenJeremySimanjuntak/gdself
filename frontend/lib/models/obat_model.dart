class ObatModel {
  final int idObat;
  final int idUser;
  final String namaObat;
  final String? tipeObat;
  final String? dosis;
  final String? frekuensi;
  final DateTime? tglMulai;
  final DateTime? tglSelesai;
  final List<String>? hariKonsumsi; // ✅ 1. Tambahkan variabel hariKonsumsi

  ObatModel({
    required this.idObat,
    required this.idUser,
    required this.namaObat,
    this.tipeObat,
    this.dosis,
    this.frekuensi,
    this.tglMulai,
    this.tglSelesai,
    this.hariKonsumsi, // ✅ 2. Masukkan ke constructor
  });

  factory ObatModel.fromJson(Map<String, dynamic> json) {
    // ✅ 3. Logika aman untuk membaca data hari konsumsi dari backend
    List<String>? parsedHari;
    if (json['hari_konsumsi'] != null) {
      if (json['hari_konsumsi'] is List) {
        // Jika dari backend bentuknya Array: ["SEN", "SEL"]
        parsedHari = List<String>.from(json['hari_konsumsi']);
      } else if (json['hari_konsumsi'] is String) {
        // Jika dari backend bentuknya String koma: "SEN, SEL"
        parsedHari = (json['hari_konsumsi'] as String)
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }

    return ObatModel(
      idObat: _toInt(json['id_obat']) ?? 0,
      idUser: _toInt(json['id_user']) ?? 0,
      namaObat: json['nama_obat'] as String? ?? '-',
      tipeObat: json['tipe_obat'] as String?,
      dosis: json['dosis'] as String?,
      frekuensi: json['frekuensi'] as String?,
      tglMulai: _parseDateTime(json['tgl_mulai']),
      tglSelesai: _parseDateTime(json['tgl_selesai']),
      hariKonsumsi: parsedHari, // ✅ 4. Masukkan hasil parsing
    );
  }
}

class JadwalObatModel {
  final int idJadwalObat;
  final int idObat;
  final String? hari;
  final String? waktuMinumObat;
  final ObatModel obat;

  JadwalObatModel({
    required this.idJadwalObat,
    required this.idObat,
    this.hari,
    this.waktuMinumObat,
    required this.obat,
  });

  factory JadwalObatModel.fromJson(Map<String, dynamic> json) {
    ObatModel obatData;
    final dynamic obatRaw = json['obat'];
    if (obatRaw is Map<String, dynamic>) {
      obatData = ObatModel.fromJson(obatRaw);
    } else {
      obatData = ObatModel(idObat: _toInt(json['id_obat']) ?? 0, idUser: 0, namaObat: '-');
    }

    return JadwalObatModel(
      idJadwalObat: _toInt(json['id_jadwal_obat']) ?? 0,
      idObat: _toInt(json['id_obat']) ?? 0,
      hari: json['hari'] as String?,
      waktuMinumObat: json['waktu_minum_obat'] as String?,
      obat: obatData,
    );
  }
}

// Helper functions (Tetap Biarkan di bawah file)
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (e) {
    return null;
  }
}

class LogKonsumsiObatModel {
  final int idLog;
  final int idJadwalObat;
  final DateTime? tglKonsumsi;
  final String status; // "Diminum" atau "Terlewat"

  LogKonsumsiObatModel({
    required this.idLog,
    required this.idJadwalObat,
    this.tglKonsumsi,
    required this.status,
  });

  factory LogKonsumsiObatModel.fromJson(Map<String, dynamic> json) {
    return LogKonsumsiObatModel(
      idLog: json['id_log'] ?? 0,
      idJadwalObat: json['id_jadwal_obat'] ?? 0,
      tglKonsumsi: json['tgl_konsumsi'] != null
          ? DateTime.tryParse(json['tgl_konsumsi'])
          : null,
      status: json['status'] ?? '',
    );
  }
}