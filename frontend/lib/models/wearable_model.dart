import 'hasil_ai_harian_model.dart'; // 👇 Mengambil model AI Harian yang baru

class WearableModel {
  final int idWearable;
  final int? idRiwayat;
  final int? idUser;
  final DateTime? tglData;
  final String? waktuData;
  final int heartRateRHR;
  final int sleepDuration;
  final List<HasilAIHarianModel> hasilAI; // 👇 SUDAH DIUBAH KE MODEL HARIAN

  WearableModel({
    required this.idWearable,
    this.idRiwayat,
    this.idUser,
    this.tglData,
    this.waktuData,
    required this.heartRateRHR,
    required this.sleepDuration,
    required this.hasilAI,
  });

  factory WearableModel.fromJson(Map<String, dynamic> json) {
    // Backend mungkin mengirim 'hasil_ai' atau 'hasil_ai_harian', kita antisipasi keduanya
    final rawHasilAI = json['hasil_ai_harian'] ?? json['hasil_ai'];
    final List<HasilAIHarianModel> hasilAI = _parseHasilAIList(rawHasilAI);

    return WearableModel(
      idWearable: _toInt(json['id_wearable']) ?? 0,
      idRiwayat: _toInt(json['id_riwayat']),
      idUser: _toInt(json['id_user']),
      tglData: _parseDateTime(json['tgl_data']),
      waktuData: json['waktu_data']?.toString(),
      heartRateRHR: _toInt(json['heart_rate_hr']) ?? 0,  // key baru
      sleepDuration: _toInt(json['sleep_duration']) ?? 0,
      hasilAI: hasilAI,
    );
  }
}

// Helper parsing khusus file wearable
List<HasilAIHarianModel> _parseHasilAIList(dynamic raw) {
  if (raw == null) return <HasilAIHarianModel>[];
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => HasilAIHarianModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
  if (raw is Map<String, dynamic>) {
    return <HasilAIHarianModel>[HasilAIHarianModel.fromJson(raw)];
  }
  if (raw is Map) {
    return <HasilAIHarianModel>[
      HasilAIHarianModel.fromJson(Map<String, dynamic>.from(raw))
    ];
  }
  return <HasilAIHarianModel>[];
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}