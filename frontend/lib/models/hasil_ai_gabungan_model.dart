class HasilAIGabunganModel {
  final int idHasilAiLab;
  final int? idHasilLab;
  final int idRiwayat;
  final int? idWearable;
  final String kesimpulanLab;
  final String trendReport;
  final String arahPerubahan;
  final DateTime? tglHasilAi;
  final double score;
  final bool isRead;

  HasilAIGabunganModel({
    required this.idHasilAiLab,
    this.idHasilLab,
    required this.idRiwayat,
    this.idWearable,
    required this.kesimpulanLab,
    required this.trendReport,
    required this.arahPerubahan,
    this.tglHasilAi,
    required this.score,
    required this.isRead,
  });

  factory HasilAIGabunganModel.fromJson(Map<String, dynamic> json) {
    return HasilAIGabunganModel(
      idHasilAiLab: _toInt(json['id_hasil_ai_lab']) ?? 0,
      idHasilLab: _toInt(json['id_hasil_lab']),
      idRiwayat: _toInt(json['id_riwayat']) ?? 0,
      idWearable: _toInt(json['id_wearable']),
      kesimpulanLab: json['kesimpulan_lab'] as String? ?? '',
      trendReport: json['trend_report'] as String? ?? 'Belum ada analisis tren.',
      arahPerubahan: json['arah_perubahan'] as String? ?? 'STABIL',
      tglHasilAi: _parseDateTime(json['tgl_hasil_ai']),
      score: _toDouble(json['score']) ?? 0.0,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
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