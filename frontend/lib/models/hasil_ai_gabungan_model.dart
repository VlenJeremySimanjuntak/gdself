// Model ini menggabungkan data dari 2 endpoint:
// 1. GET /hasil-ai/lab/laporan/:id  → HasilAILab
// 2. GET /hasil-ai/tren/laporan/:id → HasilAITren (opsional, hanya ada jika sudah ada data sebelumnya)

class HasilAIGabunganModel {
  // ── Dari HasilAILab ─────────────────────────────────────────────────
  final int? idHasilAiLab;
  final int? idLaporanLab;

  // Status per parameter
  final String statusTsh;
  final String reminderTsh;
  final String statusFt3;
  final String reminderFt3;
  final String statusFt4;
  final String reminderFt4;
  final String statusTrab;
  final String reminderTrab;

  // Interpretasi keseluruhan: "Normal" / "Belum Normal" / "Tidak Diketahui"
  final String interpretasi;

  final DateTime? tglHasilAi;

  // ── Dari HasilAITren (opsional) ──────────────────────────────────────
  final int? idHasilAiTren;

  final String? trenTsh;
  final String? reminderTrenTsh;
  final String? trenFt3;
  final String? reminderTrenFt3;
  final String? trenFt4;
  final String? reminderTrenFt4;
  final String? trenTrab;
  final String? reminderTrenTrab;

  // Apakah data tren tersedia
  bool get hasTren => idHasilAiTren != null;

  HasilAIGabunganModel({
    this.idHasilAiLab,
    this.idLaporanLab,
    required this.statusTsh,
    required this.reminderTsh,
    required this.statusFt3,
    required this.reminderFt3,
    required this.statusFt4,
    required this.reminderFt4,
    required this.statusTrab,
    required this.reminderTrab,
    required this.interpretasi,
    this.tglHasilAi,
    this.idHasilAiTren,
    this.trenTsh,
    this.reminderTrenTsh,
    this.trenFt3,
    this.reminderTrenFt3,
    this.trenFt4,
    this.reminderTrenFt4,
    this.trenTrab,
    this.reminderTrenTrab,
  });

  // Parse dari response /hasil-ai/lab/laporan/:id
  factory HasilAIGabunganModel.fromLabJson(Map<String, dynamic> json) {
    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(json['id_hasil_ai_lab']),
      idLaporanLab: _toInt(json['id_laporan_lab']),
      statusTsh: json['status_tsh'] as String? ?? 'Tidak Diketahui',
      reminderTsh: json['reminder_tsh'] as String? ?? '',
      statusFt3: json['status_ft3'] as String? ?? 'Tidak Diketahui',
      reminderFt3: json['reminder_ft3'] as String? ?? '',
      statusFt4: json['status_ft4'] as String? ?? 'Tidak Diketahui',
      reminderFt4: json['reminder_ft4'] as String? ?? '',
      statusTrab: json['status_trab'] as String? ?? 'Tidak Diketahui',
      reminderTrab: json['reminder_trab'] as String? ?? '',
      interpretasi: json['interpretasi'] as String? ?? 'Tidak Diketahui',
      tglHasilAi: _parseDateTime(json['tgl_hasil_ai']),
    );
  }

  // Tambahkan data tren ke model yang sudah ada
  HasilAIGabunganModel withTren(Map<String, dynamic> trenJson) {
    return HasilAIGabunganModel(
      idHasilAiLab: idHasilAiLab,
      idLaporanLab: idLaporanLab,
      statusTsh: statusTsh,
      reminderTsh: reminderTsh,
      statusFt3: statusFt3,
      reminderFt3: reminderFt3,
      statusFt4: statusFt4,
      reminderFt4: reminderFt4,
      statusTrab: statusTrab,
      reminderTrab: reminderTrab,
      interpretasi: interpretasi,
      tglHasilAi: tglHasilAi,
      idHasilAiTren: _toInt(trenJson['id_hasil_ai_tren']),
      trenTsh: trenJson['tren_tsh'] as String?,
      reminderTrenTsh: trenJson['reminder_tren_tsh'] as String?,
      trenFt3: trenJson['tren_ft3'] as String?,
      reminderTrenFt3: trenJson['reminder_tren_ft3'] as String?,
      trenFt4: trenJson['tren_ft4'] as String?,
      reminderTrenFt4: trenJson['reminder_tren_ft4'] as String?,
      trenTrab: trenJson['tren_trab'] as String?,
      reminderTrenTrab: trenJson['reminder_tren_trab'] as String?,
    );
  }

  // Untuk backward compatibility — field lama yang masih dipakai di UI
  String get kesimpulanLab => interpretasi;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
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