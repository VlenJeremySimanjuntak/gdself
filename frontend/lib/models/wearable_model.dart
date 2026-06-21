import 'hasil_ai_harian_model.dart';

class WearableModel {
  final int idWearable;
  final int? idRiwayat;
  final int? idUser;
  final DateTime? tglData;
  final String? waktuData;
  final int heartRateRHR;
  final int sleepDuration;
  final int sistolik;
  final int diastolik;
  final List<HasilAIHarianModel> hasilAI;

  WearableModel({
    required this.idWearable,
    this.idRiwayat,
    this.idUser,
    this.tglData,
    this.waktuData,
    required this.heartRateRHR,
    required this.sleepDuration,
    required this.sistolik,
    required this.diastolik,
    required this.hasilAI,
  });

  factory WearableModel.fromJson(Map<String, dynamic> json) {
    final rawHasilAI = json['hasil_ai_harian'] ?? json['hasil_ai'];
    final List<HasilAIHarianModel> hasilAI = _parseHasilAIList(rawHasilAI);

    return WearableModel(
      idWearable: _toInt(json['id_wearable']) ?? 0,
      idRiwayat: _toInt(json['id_riwayat']),
      idUser: _toInt(json['id_user']),
      tglData: _parseDateTime(json['tgl_data']),
      waktuData: json['waktu_data']?.toString(),
      heartRateRHR: _toInt(json['heart_rate_hr']) ?? 0,
      sleepDuration: _toInt(json['sleep_duration']) ?? 0,
      sistolik: _toInt(json['sistolik']) ?? 0,
      diastolik: _toInt(json['diastolik']) ?? 0,
      hasilAI: hasilAI,
    );
  }

  // ✅ CopyWith tetap ada (berguna untuk update state)
  WearableModel copyWith({
    int? idWearable,
    int? idRiwayat,
    int? idUser,
    DateTime? tglData,
    String? waktuData,
    int? heartRateRHR,
    int? sleepDuration,
    int? sistolik,
    int? diastolik,
    List<HasilAIHarianModel>? hasilAI,
  }) {
    return WearableModel(
      idWearable: idWearable ?? this.idWearable,
      idRiwayat: idRiwayat ?? this.idRiwayat,
      idUser: idUser ?? this.idUser,
      tglData: tglData ?? this.tglData,
      waktuData: waktuData ?? this.waktuData,
      heartRateRHR: heartRateRHR ?? this.heartRateRHR,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      sistolik: sistolik ?? this.sistolik,
      diastolik: diastolik ?? this.diastolik,
      hasilAI: hasilAI ?? this.hasilAI,
    );
  }

  // ❌ HAPUS method toJson() - tidak diperlukan
  // Karena backend tidak butuh data wearable + hasilAI sekaligus
  // Untuk POST, backend terima terpisah:
  // - POST /wearable → kirim data wearable saja
  // - POST /hasil-ai → kirim data hasilAI saja

  // ✅ Ganti dengan toString() untuk debugging
  @override
  String toString() {
    return 'WearableModel(idWearable: $idWearable, heartRate: $heartRateRHR, sleep: $sleepDuration, sistolik: $sistolik, diastolik: $diastolik, hasilAI: ${hasilAI.length} items)';
  }
}

// Helper parsing (tetap sama)
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