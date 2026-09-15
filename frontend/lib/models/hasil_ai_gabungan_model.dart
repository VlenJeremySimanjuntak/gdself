class HasilAIGabunganModel {
  final int? idHasilAiLab;
  final int? idLaporanLab;

  final String statusTsh;
  final String reminderTsh;
  final String statusFt3;
  final String reminderFt3;
  final String statusFt4;
  final String reminderFt4;
  final String statusTrab;
  final String reminderTrab;

  final String interpretasi;

  final DateTime? tglHasilAi;

  // Tren fields
  final int? idHasilAiTren;
  final String? trenTsh;
  final String? reminderTrenTsh;
  final String? trenFt3;
  final String? reminderTrenFt3;
  final String? trenFt4;
  final String? reminderTrenFt4;
  final String? trenTrab;
  final String? reminderTrenTrab;

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

  // ✅ ALAT PENCARI SUPER KEBAL ERROR
  // Fungsi ini otomatis mengecek semua bentuk tulisan dan mencari sampai ke dalam objek "data"
  static dynamic _find(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;

    // 1. Cek langsung di root map
    for (var key in keys) {
      if (map[key] != null) return map[key];
    }

    // 2. Cek apakah respon dibungkus dalam {"data": { ... }} (Standar Response API)
    if (map['data'] != null && map['data'] is Map) {
      final dataMap = map['data'] as Map;
      for (var key in keys) {
        if (dataMap[key] != null) return dataMap[key];
      }
    }

    return null;
  }

  factory HasilAIGabunganModel.fromLabJson(Map<String, dynamic> json) {
    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(_find(json, ['id_hasil_ai_lab', 'IdHasilAiLab'])),
      idLaporanLab: _toInt(_find(json, ['id_laporan_lab', 'IdLaporanLab'])),

      statusTsh: _find(json, ['status_tsh', 'StatusTSH', 'StatusTsh'])?.toString() ?? 'Tidak Diketahui',
      reminderTsh: _find(json, ['reminder_tsh', 'ReminderTSH', 'ReminderTsh'])?.toString() ?? '',

      statusFt3: _find(json, ['status_ft3', 'StatusFT3', 'StatusFt3'])?.toString() ?? 'Tidak Diketahui',
      reminderFt3: _find(json, ['reminder_ft3', 'ReminderFT3', 'ReminderFt3'])?.toString() ?? '',

      statusFt4: _find(json, ['status_ft4', 'StatusFT4', 'StatusFt4'])?.toString() ?? 'Tidak Diketahui',
      reminderFt4: _find(json, ['reminder_ft4', 'ReminderFT4', 'ReminderFt4'])?.toString() ?? '',

      statusTrab: _find(json, ['status_trab', 'StatusTRAb', 'StatusTrab'])?.toString() ?? 'Tidak Diketahui',
      reminderTrab: _find(json, ['reminder_trab', 'ReminderTRAb', 'ReminderTrab'])?.toString() ?? '',

      interpretasi: _find(json, ['interpretasi', 'Interpretasi'])?.toString() ?? 'Tidak Diketahui',
      tglHasilAi: _parseDateTime(_find(json, ['tgl_hasil_ai', 'TglHasilAi'])),
    );
  }

  factory HasilAIGabunganModel.fromMergedParams(Map<String, Map<String, dynamic>> validPerParam) {
    Map<String, dynamic>? tsh = validPerParam['TSH'];
    Map<String, dynamic>? ft3 = validPerParam['FT3'];
    Map<String, dynamic>? ft4 = validPerParam['FT4'];
    Map<String, dynamic>? trab = validPerParam['TRAB'];

    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(_find(tsh, ['id_hasil_ai_lab']) ?? _find(ft3, ['id_hasil_ai_lab'])),
      idLaporanLab: _toInt(_find(tsh, ['id_laporan_lab']) ?? _find(ft3, ['id_laporan_lab'])),

      statusTsh: _find(tsh, ['status_tsh', 'StatusTSH', 'StatusTsh'])?.toString() ?? 'Tidak Diketahui',
      reminderTsh: _find(tsh, ['reminder_tsh', 'ReminderTSH', 'ReminderTsh'])?.toString() ?? '',

      statusFt3: _find(ft3, ['status_ft3', 'StatusFT3', 'StatusFt3'])?.toString() ?? 'Tidak Diketahui',
      reminderFt3: _find(ft3, ['reminder_ft3', 'ReminderFT3', 'ReminderFt3'])?.toString() ?? '',

      statusFt4: _find(ft4, ['status_ft4', 'StatusFT4', 'StatusFt4'])?.toString() ?? 'Tidak Diketahui',
      reminderFt4: _find(ft4, ['reminder_ft4', 'ReminderFT4', 'ReminderFt4'])?.toString() ?? '',

      statusTrab: _find(trab, ['status_trab', 'StatusTRAb', 'StatusTrab'])?.toString() ?? 'Tidak Diketahui',
      reminderTrab: _find(trab, ['reminder_trab', 'ReminderTRAb', 'ReminderTrab'])?.toString() ?? '',

      interpretasi: _find(tsh, ['interpretasi', 'Interpretasi'])?.toString() ?? 'Tidak Diketahui',
      tglHasilAi: _parseDateTime(_find(tsh, ['tgl_hasil_ai', 'TglHasilAi'])),
    );
  }

  factory HasilAIGabunganModel.fromTrenOnly(Map<String, dynamic> trenJson) {
    return HasilAIGabunganModel(
      idHasilAiLab: null,
      idLaporanLab: _toInt(_find(trenJson, ['id_laporan_lab', 'IdLaporanLab'])),
      statusTsh: 'Tidak Diketahui',
      reminderTsh: '-',
      statusFt3: 'Tidak Diketahui',
      reminderFt3: '-',
      statusFt4: 'Tidak Diketahui',
      reminderFt4: '-',
      statusTrab: 'Tidak Diketahui',
      reminderTrab: '-',
      interpretasi: 'Tidak Diketahui',
      tglHasilAi: null,

      idHasilAiTren: _toInt(_find(trenJson, ['id_hasil_ai_tren', 'IdHasilAiTren'])),
      trenTsh: _find(trenJson, ['tren_tsh', 'TrenTSH', 'trenTsh'])?.toString(),
      reminderTrenTsh: _find(trenJson, ['reminder_tren_tsh', 'ReminderTrenTSH', 'reminderTrenTsh'])?.toString(),
      trenFt3: _find(trenJson, ['tren_ft3', 'TrenFT3', 'trenFt3'])?.toString(),
      reminderTrenFt3: _find(trenJson, ['reminder_tren_ft3', 'ReminderTrenFT3', 'reminderTrenFt3'])?.toString(),
      trenFt4: _find(trenJson, ['tren_ft4', 'TrenFT4', 'trenFt4'])?.toString(),
      reminderTrenFt4: _find(trenJson, ['reminder_tren_ft4', 'ReminderTrenFT4', 'reminderTrenFt4'])?.toString(),
      trenTrab: _find(trenJson, ['tren_trab', 'TrenTRAb', 'TrenTrab', 'trenTrab'])?.toString(),
      reminderTrenTrab: _find(trenJson, ['reminder_tren_trab', 'ReminderTrenTRAb', 'ReminderTrenTrab', 'reminderTrenTrab'])?.toString(),
    );
  }

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

      idHasilAiTren: _toInt(_find(trenJson, ['id_hasil_ai_tren', 'IdHasilAiTren'])),
      trenTsh: _find(trenJson, ['tren_tsh', 'TrenTSH', 'trenTsh'])?.toString(),
      reminderTrenTsh: _find(trenJson, ['reminder_tren_tsh', 'ReminderTrenTSH', 'reminderTrenTsh'])?.toString(),
      trenFt3: _find(trenJson, ['tren_ft3', 'TrenFT3', 'trenFt3'])?.toString(),
      reminderTrenFt3: _find(trenJson, ['reminder_tren_ft3', 'ReminderTrenFT3', 'reminderTrenFt3'])?.toString(),
      trenFt4: _find(trenJson, ['tren_ft4', 'TrenFT4', 'trenFt4'])?.toString(),
      reminderTrenFt4: _find(trenJson, ['reminder_tren_ft4', 'ReminderTrenFT4', 'reminderTrenFt4'])?.toString(),
      trenTrab: _find(trenJson, ['tren_trab', 'TrenTRAb', 'TrenTrab', 'trenTrab'])?.toString(),
      reminderTrenTrab: _find(trenJson, ['reminder_tren_trab', 'ReminderTrenTRAb', 'ReminderTrenTrab', 'reminderTrenTrab'])?.toString(),
    );
  }

  HasilAIGabunganModel withTrenDefault() {
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
      idHasilAiTren: null,
      trenTsh: "-",
      reminderTrenTsh: "-",
      trenFt3: "-",
      reminderTrenFt3: "-",
      trenFt4: "-",
      reminderTrenFt4: "-",
      trenTrab: "-",
      reminderTrenTrab: "-",
    );
  }

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