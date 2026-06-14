import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import 'edit_lab_screen.dart';

class LabDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const LabDetailScreen({super.key, required this.reportData});

  // Ambil data spesifik hormon dari raw_data JSON
  Map<String, dynamic>? _getParamData(String paramName) {
    List<dynamic> hasil = reportData['raw_data']['hasil_lab'] ?? [];
    for (var h in hasil) {
      if (h['parameter']?['nama_parameter']?.toString().toUpperCase() == paramName) {
        return h;
      }
    }
    return null;
  }

  // Format data untuk dikirim ke Layar Edit
  Map<String, dynamic>? _formatForEdit(Map<String, dynamic>? param) {
    if (param == null) return null;
    return {
      'val': double.tryParse(param['nilai_hasil']?.toString() ?? "0"),
      'min': double.tryParse(param['rujukan_min']?.toString() ?? "0"),
      'max': double.tryParse(param['rujukan_max']?.toString() ?? "0"),
      'satuan': param['parameter']?['satuan'] ?? "",
    };
  }

  @override
  Widget build(BuildContext context) {
    String namaLab = reportData['nama_lab'] ?? "Laboratorium Klinik";
    DateTime dateObj = DateTime.tryParse(reportData['raw_date'] ?? "") ?? DateTime.now();
    String tgl = DateFormat('dd/MM/yyyy').format(dateObj); // Format sesuai gambar

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: const Text("Detail Data Hormon", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // 👇 Menggunakan Stack agar Positioned bisa bekerja
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Data Hormon", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                const SizedBox(height: 8),
                const Text(
                  "Silakan ubah atau lengkapi data hasil laboratorium Anda agar pemantauan kondisi tiroid tetap sesuai.",
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
                ),
                const SizedBox(height: 24),

                _buildGeneralInfoCard(namaLab, tgl),
                const SizedBox(height: 16),

                _buildHormoneCard("TSH", "Thyroid Stimulating Hormone", _getParamData("TSH")),
                const SizedBox(height: 16),
                _buildHormoneCard("FT4", "Free Thyroxine", _getParamData("FT4")),
                const SizedBox(height: 16),
                _buildHormoneCard("FT3", "Free Triiodothyronine", _getParamData("FT3"), isLast: true),

                const SizedBox(height: 120), // Spasi ekstra di bawah agar tidak tertutup tombol
              ],
            ),
          ),

          // 👇 Tombol Mengambang (Positioned) Sesuai Request Mas Vlen
          Positioned(
            bottom: 30,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () {
                // Langsung meluncur ke Layar Edit dengan data lengkap!
                Navigator.push(context, MaterialPageRoute(builder: (context) => EditLabScreen(
                  idLaporanLab: reportData['id_laporan_lab'],
                  tanggal: reportData['raw_date'] ?? "",
                  namaLab: namaLab,
                  tshData: _formatForEdit(_getParamData("TSH")),
                  ft4Data: _formatForEdit(_getParamData("FT4")),
                  ft3Data: _formatForEdit(_getParamData("FT3")),
                )));
              },
              foregroundColor: Colors.white,
              backgroundColor: AppColors.primaryBlue,
              elevation: 8, // Elevation sesuai request
              icon: const Icon(Icons.edit_rounded, color: Colors.white), // Icon edit ditambahkan
              label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralInfoCard(String lab, String date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Nama Lab", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          _buildFakeInput(lab),
          const SizedBox(height: 16),
          const Text("Tanggal Pemeriksaan", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 8),
          _buildFakeInput(date),
        ],
      ),
    );
  }

  Widget _buildHormoneCard(String title, String sub, Map<String, dynamic>? data, {bool isLast = false}) {
    double val = double.tryParse(data?['nilai_hasil']?.toString() ?? "0") ?? 0;
    double min = double.tryParse(data?['rujukan_min']?.toString() ?? "0") ?? 0;
    double max = double.tryParse(data?['rujukan_max']?.toString() ?? "0") ?? 0;
    String unit = data?['parameter']?['satuan'] ?? "";

    bool isNormal = (min == 0 && max == 0) ? true : (val >= min && val <= max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: isNormal ? const Color(0xFFCCF1E1) : const Color(0xFFF27E6D).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: isNormal ? const Color(0xFF00897B) : const Color(0xFFF27E6D)),
                    const SizedBox(width: 4),
                    Text(isNormal ? "STABIL" : "PERHATIAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isNormal ? const Color(0xFF00897B) : const Color(0xFFF27E6D))),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          const Text("HASIL PEMERIKSAAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFFEEF3F6), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black45)),
                Row(
                  children: [
                    Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BATAS TERENDAH", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    _buildFakeInput(min.toString()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BATAS TERTINGGI", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
                    const SizedBox(height: 6),
                    _buildFakeInput(max.toString()),
                  ],
                ),
              ),
            ],
          ),
          if (isLast) ...[
            const SizedBox(height: 16),
            const Text(
              "*Hasil di luar rentang akan ditandai secara otomatis setelah penyimpanan.",
              style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFakeInput(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFEEF3F6), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black45)),
    );
  }
}