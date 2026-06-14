import 'package:flutter/material.dart';

class AiUiMapper {
  // Mapping Warna dan Label untuk Status Harian (Mesin 2)
  static Map<String, dynamic> mapStatusHarian(String? status) {
    switch (status) {
      case 'NORMAL_HARIAN':
        return {'label': 'Normal hari ini', 'color': const Color(0xFF00897B), 'bgColor': const Color(0xFFCCF1E1)};
      case 'SATU_INDIKATOR_BELUM_NORMAL':
        return {'label': 'Satu indikator belum normal', 'color': Colors.amber.shade700, 'bgColor': Colors.amber.shade100};
      case 'DUA_INDIKATOR_BELUM_NORMAL':
        return {'label': 'Perhatikan pola beberapa hari', 'color': Colors.orange.shade800, 'bgColor': Colors.orange.shade100};
      case 'TIGA_INDIKATOR_BELUM_NORMAL':
        return {'label': 'Semua indikator belum normal — kontak tenaga kesehatan jika berlanjut', 'color': const Color(0xFFF27E6D), 'bgColor': const Color(0xFFF27E6D).withOpacity(0.2)};
      default:
        return {'label': 'Menunggu data', 'color': Colors.grey, 'bgColor': Colors.grey.shade200};
    }
  }

  // Mapping Teks untuk Flag Urgensi (Mesin 3)
  static String mapUrgensi(String? flag) {
    switch (flag) {
      case 'Dalam Batas':
        return "Tidak perlu tindakan segera.";
      case 'Perlu Perhatian':
        return "Perhatikan selama beberapa hari.";
      case 'Perlu Evaluasi Dokter':
        return "Sebaiknya diskusi dengan tenaga kesehatan.";
      default:
        return "Pertahankan pola hidup sehat Anda.";
    }
  }

  // Helper untuk menampilkan Skor + Label singkat
  static String formatScoreLabel(double? score) {
    if (score == null) return "Menunggu Analisis";
    if (score >= 2.0) return "Skor $score — Perlu perhatian";
    return "Skor $score — Terkendali";
  }
}