class HasilAIHarianModel {
  final int idHasilAiHarian;
  final int idWearable;
  final DateTime? tglHasilAi;

  // ✅ FIELD BARU SESUAI RULE-BASED DI GOLANG
  final String? statusHr;
  final String? reminderHr;
  final String? statusTidur;
  final String? reminderTidur;
  final String? statusTd;
  final String? reminderTd;

  HasilAIHarianModel({
    required this.idHasilAiHarian,
    required this.idWearable,
    this.tglHasilAi,
    this.statusHr,
    this.reminderHr,
    this.statusTidur,
    this.reminderTidur,
    this.statusTd,
    this.reminderTd,
  });

  factory HasilAIHarianModel.fromJson(Map<String, dynamic> json) {
    return HasilAIHarianModel(
      idHasilAiHarian: _toInt(json['id_hasil_ai_harian']) ?? 0,
      idWearable: _toInt(json['id_wearable']) ?? 0,
      tglHasilAi: _parseDateTime(json['tgl_hasil_ai'] ?? json['created_at']),

      // ✅ PARSING JSON DARI GOLANG
      statusHr: json['status_hr'] as String?,
      reminderHr: json['reminder_hr'] as String?,
      statusTidur: json['status_tidur'] as String?,
      reminderTidur: json['reminder_tidur'] as String?,
      statusTd: json['status_td'] as String?,
      reminderTd: json['reminder_td'] as String?,
    );
  }
}

// ==========================================
// FUNGSI HELPER PARSERS
// ==========================================
int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
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