import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/obat_model.dart';
import 'edit_obat_screen.dart';

class DetailObatScreen extends StatelessWidget {
  final JadwalObatModel jadwal;
  final List<String> times;
  final List<String> days;

  const DetailObatScreen({
    super.key,
    required this.jadwal,
    required this.times,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final obat = jadwal.obat;
    final tglMulai = obat.tglMulai != null ? DateFormat('dd/MM/yyyy').format(obat.tglMulai!) : '-';
    final tglSelesai = obat.tglSelesai != null ? DateFormat('dd/MM/yyyy').format(obat.tglSelesai!) : '-';

    // 1. Mapping hari untuk translate singkatan ke nama penuh
    final Map<String, String> dayMapper = {
      'SEN': 'Senin', 'SEL': 'Selasa', 'RAB': 'Rabu',
      'KAM': 'Kamis', 'JUM': 'Jumat', 'SAB': 'Sabtu', 'MIN': 'Minggu',
      'SENIN': 'Senin', 'SELASA': 'Selasa', 'RABU': 'Rabu',
      'KAMIS': 'Kamis', 'JUMAT': 'Jumat', 'SABTU': 'Sabtu', 'MINGGU': 'Minggu',
    };

    // 2. Aturan urutan hari
    final Map<String, int> dayOrder = {
      'Senin': 1, 'Selasa': 2, 'Rabu': 3, 'Kamis': 4,
      'Jumat': 5, 'Sabtu': 6, 'Minggu': 7
    };

    // 3. Konversi dan urutkan hari
    final sortedDays = days.map((d) => dayMapper[d.toUpperCase().trim()] ?? d).toList()
      ..sort((a, b) => (dayOrder[a] ?? 8).compareTo(dayOrder[b] ?? 8));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006699)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Detail Obat",
          style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Obat', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.5)),
              const SizedBox(height: 28),

              // Informasi Obat
              const Text('Informasi Obat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              _buildRow('Nama Obat', obat.namaObat),
              _buildRow('Tanggal Mulai', tglMulai),
              _buildRow('Tanggal Selesai', tglSelesai),

              const SizedBox(height: 16),

              // Informasi Dosis
              const Text('Informasi Dosis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              _buildRow('Tipe Obat', obat.tipeObat ?? 'Tablet'),
              _buildRowDosis('Dosis', obat.dosis ?? '-'),
              _buildRow('Frekuensi', obat.frekuensi ?? '-'),

              const SizedBox(height: 16),

              // Jadwal Pengobatan
              const Text('Jadwal Pengobatan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 36,
                runSpacing: 12,
                children: sortedDays.map((d) => Text(d, style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 12))).toList(),
              ),

              const SizedBox(height: 24),

              // Waktu Konsumsi
              const Text('Waktu Konsumsi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1F2937))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 36,
                runSpacing: 12,
                children: times.map((t) {
                  final formattedTime = t.replaceAll(':', '.');
                  return Text('$formattedTime WIB', style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 12));
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: SizedBox(
          width: 110,
          height: 46,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditObatScreen(jadwal: jadwal)));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005680),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 4,
            ),
            child: const Text("Edit", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _buildRowDosis(String label, String value) {
    String angka = value;
    String satuan = '';
    if (value.toLowerCase().contains('mg')) {
      angka = value.replaceAll(RegExp(r'(?i)mg'), '').trim();
      satuan = ' mg';
    } else if (value.toLowerCase().contains('gr')) {
      angka = value.replaceAll(RegExp(r'(?i)gr'), '').trim();
      satuan = ' gr';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: angka,
                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 12, fontWeight: FontWeight.w500),
                children: [TextSpan(text: satuan, style: const TextStyle(fontWeight: FontWeight.w900))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}