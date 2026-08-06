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

  factory HasilAIGabunganModel.fromLabJson(Map<String, dynamic> json) {
    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(json['id_hasil_ai_lab'] ?? json['IdHasilAiLab']),
      idLaporanLab: _toInt(json['id_laporan_lab'] ?? json['IdLaporanLab']),
      statusTsh: (json['status_tsh'] ?? json['StatusTSH'])?.toString() ?? 'Tidak Diketahui',
      reminderTsh: (json['reminder_tsh'] ?? json['ReminderTSH'])?.toString() ?? '',
      statusFt3: (json['status_ft3'] ?? json['StatusFT3'])?.toString() ?? 'Tidak Diketahui',
      reminderFt3: (json['reminder_ft3'] ?? json['ReminderFT3'])?.toString() ?? '',
      statusFt4: (json['status_ft4'] ?? json['StatusFT4'])?.toString() ?? 'Tidak Diketahui',
      reminderFt4: (json['reminder_ft4'] ?? json['ReminderFT4'])?.toString() ?? '',
      statusTrab: (json['status_trab'] ?? json['StatusTRAb'] ?? json['StatusTrab'] ?? json['statusTrab'])?.toString() ?? 'Tidak Diketahui',
      reminderTrab: (json['reminder_trab'] ?? json['ReminderTRAb'] ?? json['ReminderTrab'] ?? json['reminderTrab'])?.toString() ?? '',
      interpretasi: (json['interpretasi'] ?? json['Interpretasi'])?.toString() ?? 'Tidak Diketahui',
      tglHasilAi: _parseDateTime(json['tgl_hasil_ai'] ?? json['TglHasilAi']),
    );
  }

  factory HasilAIGabunganModel.fromMergedParams(Map<String, Map<String, dynamic>> validPerParam) {
    Map<String, dynamic>? tsh = validPerParam['TSH'];
    Map<String, dynamic>? ft3 = validPerParam['FT3'];
    Map<String, dynamic>? ft4 = validPerParam['FT4'];
    Map<String, dynamic>? trab = validPerParam['TRAB'];

    String getStatus(Map<String, dynamic>? src, String key) =>
        (src?[key])?.toString() ?? 'Tidak Diketahui';
    String getReminder(Map<String, dynamic>? src, String key) =>
        (src?[key])?.toString() ?? '';

    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(tsh?['id_hasil_ai_lab'] ?? ft3?['id_hasil_ai_lab'] ?? ft4?['id_hasil_ai_lab'] ?? trab?['id_hasil_ai_lab']),
      idLaporanLab: _toInt(tsh?['id_laporan_lab'] ?? ft3?['id_laporan_lab'] ?? ft4?['id_laporan_lab'] ?? trab?['id_laporan_lab']),
      statusTsh: getStatus(tsh, 'status_tsh'),
      reminderTsh: getReminder(tsh, 'reminder_tsh'),
      statusFt3: getStatus(ft3, 'status_ft3'),
      reminderFt3: getReminder(ft3, 'reminder_ft3'),
      statusFt4: getStatus(ft4, 'status_ft4'),
      reminderFt4: getReminder(ft4, 'reminder_ft4'),
      statusTrab: getStatus(trab, 'status_trab'),
      reminderTrab: getReminder(trab, 'reminder_trab'),
      interpretasi: tsh?['interpretasi']?.toString() ?? 'Tidak Diketahui',
      tglHasilAi: _parseDateTime(tsh?['tgl_hasil_ai']),
    );
  }

  // ✅ BARU: Constructor hanya dari data Tren (Lab default)
  factory HasilAIGabunganModel.fromTrenOnly(Map<String, dynamic> trenJson) {
    String? getVal(List<String> keys) {
      for (var key in keys) {
        if (trenJson.containsKey(key)) return trenJson[key]?.toString();
      }
      return null;
    }

    return HasilAIGabunganModel(
      idHasilAiLab: null,
      idLaporanLab: _toInt(trenJson['id_laporan_lab'] ?? trenJson['IdLaporanLab']),
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

      idHasilAiTren: _toInt(trenJson['id_hasil_ai_tren'] ?? trenJson['IdHasilAiTren']),
      trenTsh: getVal(['tren_tsh', 'TrenTSH', 'trenTsh']),
      reminderTrenTsh: getVal(['reminder_tren_tsh', 'ReminderTrenTSH', 'reminderTrenTsh']),
      trenFt3: getVal(['tren_ft3', 'TrenFT3', 'trenFt3']),
      reminderTrenFt3: getVal(['reminder_tren_ft3', 'ReminderTrenFT3', 'reminderTrenFt3']),
      trenFt4: getVal(['tren_ft4', 'TrenFT4', 'trenFt4']),
      reminderTrenFt4: getVal(['reminder_tren_ft4', 'ReminderTrenFT4', 'reminderTrenFt4']),
      trenTrab: getVal(['tren_trab', 'TrenTRAb', 'TrenTrab', 'trenTrab']),
      reminderTrenTrab: getVal(['reminder_tren_trab', 'ReminderTrenTRAb', 'ReminderTrenTrab', 'reminderTrenTrab']),
    );
  }

  HasilAIGabunganModel withTren(Map<String, dynamic> trenJson) {
    String? getVal(List<String> keys) {
      for (var key in keys) {
        if (trenJson.containsKey(key)) return trenJson[key]?.toString();
      }
      return null;
    }

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

      idHasilAiTren: _toInt(trenJson['id_hasil_ai_tren'] ?? trenJson['IdHasilAiTren']),
      trenTsh: getVal(['tren_tsh', 'TrenTSH', 'trenTsh']),
      reminderTrenTsh: getVal(['reminder_tren_tsh', 'ReminderTrenTSH', 'reminderTrenTsh']),
      trenFt3: getVal(['tren_ft3', 'TrenFT3', 'trenFt3']),
      reminderTrenFt3: getVal(['reminder_tren_ft3', 'ReminderTrenFT3', 'reminderTrenFt3']),
      trenFt4: getVal(['tren_ft4', 'TrenFT4', 'trenFt4']),
      reminderTrenFt4: getVal(['reminder_tren_ft4', 'ReminderTrenFT4', 'reminderTrenFt4']),
      trenTrab: getVal(['tren_trab', 'TrenTRAb', 'TrenTrab', 'trenTrab']),
      reminderTrenTrab: getVal(['reminder_tren_trab', 'ReminderTrenTRAb', 'ReminderTrenTrab', 'reminderTrenTrab']),
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