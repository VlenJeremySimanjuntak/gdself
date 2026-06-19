class UsgTiroidModel {
  final int? idUsg;
  final int idRiwayat;
  final String namaRs;
  final DateTime? tglPemeriksaan;
  final String? fotoPath;
  final String? catatanDokter;
  final DateTime? createdAt; // 👇 Ditambahkan agar sesuai dengan 'created_at' dari BE

  UsgTiroidModel({
    this.idUsg,
    required this.idRiwayat,
    required this.namaRs,
    this.tglPemeriksaan,
    this.fotoPath,
    this.catatanDokter,
    this.createdAt,
  });

  factory UsgTiroidModel.fromJson(Map<String, dynamic> json) {
    return UsgTiroidModel(
      idUsg: json['id_usg'],
      idRiwayat: json['id_riwayat'] ?? 0,
      namaRs: json['nama_rs'] ?? '',
      tglPemeriksaan: json['tgl_pemeriksaan'] != null
          ? DateTime.parse(json['tgl_pemeriksaan'])
          : null,
      fotoPath: json['foto_path'],
      catatanDokter: json['catatan_dokter'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null, // 👇 Melakukan parsing data waktu 'created_at' dari BE
    );
  }

  // 👇 Menyediakan method toJson() jika suatu saat FE membutuhkannya
  Map<String, dynamic> toJson() {
    return {
      'id_usg': idUsg,
      'id_riwayat': idRiwayat,
      'nama_rs': namaRs,
      'tgl_pemeriksaan': tglPemeriksaan?.toIso8601String(),
      'foto_path': fotoPath,
      'catatan_dokter': catatanDokter,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}