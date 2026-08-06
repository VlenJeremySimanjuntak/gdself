import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../../riwayat/provider/riwayat_provider.dart';
import '../providers/monitoring_provider.dart';
import 'edit_lab_screen.dart';

class LabDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> reportData;

  const LabDetailScreen({super.key, required this.reportData});

  @override
  ConsumerState<LabDetailScreen> createState() => _LabDetailScreenState();
}

class _LabDetailScreenState extends ConsumerState<LabDetailScreen> {
  late Map<String, dynamic> _currentData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentData = Map.from(widget.reportData);
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      // Ambil data terbaru dari monitoringProvider
      await ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
      // Ambil data riwayat terbaru
      await ref.read(riwayatProvider.notifier).fetchRiwayatData(userId);

      final arsipList = ref.read(riwayatProvider).laporanList;

      // ✅ PERBAIKAN: Mengonversi keduanya ke String untuk menghindari type mismatch
      final targetId = _currentData['id_laporan_lab']?.toString();

      final updatedReport = arsipList.firstWhere(
            (item) => item['id_laporan_lab']?.toString() == targetId,
        orElse: () => _currentData,
      );

      setState(() {
        _currentData = updatedReport;
      });
    }
    setState(() => _isLoading = false);
  }

  Map<String, dynamic>? _getParamData(String paramName) {
    List<dynamic> hasil = _currentData['raw_data']['hasil_lab'] ?? [];
    for (var h in hasil) {
      if (h['parameter']?['nama_parameter']?.toString().toUpperCase() == paramName.toUpperCase()) {
        return h;
      }
    }
    return null;
  }

  Map<String, dynamic>? _formatForEdit(Map<String, dynamic>? hasil) {
    if (hasil == null) return null;
    return {
      'id': hasil['id_hasil_lab'] as int?,
      'value': hasil['nilai_hasil'] as num?,
      'min': hasil['nilai_batas_bawah'] as num?,
      'max': hasil['nilai_batas_atas'] as num?,
      'satuan': hasil['parameter']?['satuan'] as String? ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    String namaLab = _currentData['nama_lab'] ?? "Laboratorium Klinik";
    DateTime dateObj = DateTime.tryParse(_currentData['raw_date'] ?? "") ?? DateTime.now();
    String tgl = DateFormat('dd/MM/yyyy').format(dateObj);

    // ✅ LOGIKA 24 JAM: Mengambil waktu pembuatan laporan
    DateTime createdAt = DateTime.tryParse(
        _currentData['created_at']?.toString() ??
            _currentData['raw_date']?.toString() ??
            ""
    ) ?? DateTime.now();

    // Cek selisih waktu sekarang dengan waktu laporan dibuat
    bool isEditable = DateTime.now().difference(createdAt).inHours < 24;

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
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Data Hormon", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                const SizedBox(height: 8),
                const Text("Berikut adalah rincian hasil laboratorium Anda.", style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5)),
                const SizedBox(height: 24),

                _buildGeneralInfoCard(namaLab, tgl),
                const SizedBox(height: 16),

                // ✅ 1. FT3 dipindah ke urutan pertama
                _buildHormoneCard("FT3", "Free Triiodothyronine", _getParamData("FT3")),
                const SizedBox(height: 16),

                // ✅ 2. FT4 di urutan kedua
                _buildHormoneCard("FT4", "Free Thyroxine", _getParamData("FT4")),
                const SizedBox(height: 16),

                // ✅ 3. TSHs di urutan ketiga
                _buildHormoneCard("TSHs", "Thyroid Stimulating Hormone", _getParamData("TSH")),
                const SizedBox(height: 16),

                // ✅ 4. TRAb tetap di posisi terakhir
                _buildHormoneCard("TRAb", "Thyrotropin Receptor Antibodies", _getParamData("TRAb")),

                const SizedBox(height: 120),
              ],
            ),
          ),

          // ✅ TOMBOL EDIT YANG SUDAH DILENGKAPI FITUR KUNCI 24 JAM
          Positioned(
            bottom: 30,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: isEditable
                  ? () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditLabScreen(
                      idLaporanLab: _currentData['id_laporan_lab'] ?? 0,
                      tanggal: _currentData['raw_date'] ?? "",
                      namaLab: namaLab,
                      tshData: _formatForEdit(_getParamData("TSH")),
                      ft4Data: _formatForEdit(_getParamData("FT4")),
                      ft3Data: _formatForEdit(_getParamData("FT3")),
                      trabData: _formatForEdit(_getParamData("TRAb")),
                    ),
                  ),
                );
                if (result == true && mounted) {
                  // Refresh data setelah edit berhasil
                  await _refreshData();
                }
              }
                  : () {
                // Tampilkan notifikasi jika sudah lewat 24 jam
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Data tidak dapat diubah karena sudah lebih dari 24 jam sejak direkam."),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              backgroundColor: isEditable ? AppColors.primaryBlue : Colors.grey,
              icon: Icon(
                  isEditable ? Icons.edit_rounded : Icons.lock_outline,
                  color: Colors.white
              ),
              label: Text(
                  isEditable ? "Edit" : "Terkunci",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
              ),
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

  Widget _buildHormoneCard(String title, String sub, Map<String, dynamic>? data) {
    // 1. Tentukan presisi desimal: 3 untuk TSHs, 2 untuk yang lainnya
    final int decimalPlaces = (title.toUpperCase() == "TSHS") ? 3 : 2;

    // 2. Fungsi helper untuk memformat angka dengan aman
    String formatValue(dynamic value) {
      if (value == null) return "-";
      final double? parsed = double.tryParse(value.toString());
      return parsed != null ? parsed.toStringAsFixed(decimalPlaces) : "-";
    }

    // 3. Gunakan helper untuk memformat hasil, min, dan max
    String val = formatValue(data?['nilai_hasil']);
    String min = formatValue(data?['nilai_batas_bawah']);
    String max = formatValue(data?['nilai_batas_atas']);
    String unit = data?['parameter']?['satuan']?.toString() ?? "";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
          const SizedBox(height: 20),
          const Text("HASIL PEMERIKSAAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFFEEF3F6), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.textDark)),
                Text(unit, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("BATAS TERENDAH", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)), const SizedBox(height: 6), _buildFakeInput(min)])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("BATAS TERTINGGI", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)), const SizedBox(height: 6), _buildFakeInput(max)])),
            ],
          ),
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