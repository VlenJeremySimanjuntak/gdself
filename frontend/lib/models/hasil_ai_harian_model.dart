class HasilAIHarianModel {
  final int idHasilAiHarian;
  final int idWearable;
  final int idRiwayat;
  final DateTime? tglHasilAi;
  final double score;
  final String statusHarian;
  final String pesanHarian;

  HasilAIHarianModel({
    required this.idHasilAiHarian,
    required this.idWearable,
    required this.idRiwayat,
    this.tglHasilAi,
    required this.score,
    required this.statusHarian,
    required this.pesanHarian,
  });

  factory HasilAIHarianModel.fromJson(Map<String, dynamic> json) {
    return HasilAIHarianModel(
      idHasilAiHarian: _toInt(json['id_hasil_ai_harian']) ?? 0,
      idWearable: _toInt(json['id_wearable']) ?? 0,
      idRiwayat: _toInt(json['id_riwayat']) ?? 0,
      tglHasilAi: _parseDateTime(json['tgl_hasil_ai']),
      score: _toDouble(json['score']) ?? 0.0,
      statusHarian: json['status_harian'] as String? ?? 'Belum ada status',
      pesanHarian: json['pesan_harian'] as String? ?? 'Belum ada pesan',
    );
  }
}

// Fungsi helper parsers
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