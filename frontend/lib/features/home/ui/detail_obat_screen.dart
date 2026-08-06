import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/obat_model.dart';
import 'edit_obat_screen.dart';
import 'rekap_obat_screen.dart';

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

    // Format Tanggal untuk Header
    final tglMulai = obat.tglMulai != null ? DateFormat('d MMMM yyyy', 'id').format(obat.tglMulai!) : '-';
    final tglSelesaiUI = obat.tglSelesai != null ? DateFormat('d MMMM yyyy', 'id').format(obat.tglSelesai!) : 'Sekarang';

    // Logika Status Selesai
    bool isSelesai = false;
    if (obat.tglSelesai != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final endDate = DateTime(obat.tglSelesai!.year, obat.tglSelesai!.month, obat.tglSelesai!.day);
      isSelesai = endDate.isBefore(today);
    }

    final Map<String, String> dayMapper = {
      'SEN': 'Senin', 'SEL': 'Selasa', 'RAB': 'Rabu',
      'KAM': 'Kamis', 'JUM': 'Jumat', 'SAB': 'Sabtu', 'MIN': 'Minggu',
      'SENIN': 'Senin', 'SELASA': 'Selasa', 'RABU': 'Rabu',
      'KAMIS': 'Kamis', 'JUMAT': 'Jumat', 'SABTU': 'Sabtu', 'MINGGU': 'Minggu',
    };

    final Map<String, int> dayOrder = {
      'Senin': 1, 'Selasa': 2, 'Rabu': 3, 'Kamis': 4,
      'Jumat': 5, 'Sabtu': 6, 'Minggu': 7
    };

    final sortedDays = days.map((d) => dayMapper[d.toUpperCase().trim()] ?? d).toList()
      ..sort((a, b) => (dayOrder[a] ?? 8).compareTo(dayOrder[b] ?? 8));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF), // Background disamakan dengan Home Screen
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00695C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Detail Obat",
          style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ================= HEADER SECTION =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F0FE),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.pill(PhosphorIconsStyle.regular), color: const Color(0xFF00695C), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              obat.namaObat,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF003366)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '$tglMulai - $tglSelesaiUI',
                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            // =========================================================
            // PERBAIKAN: Hanya dirender jika status obat SEDANG BERJALAN
            // Jika sudah selesai, widget ini sama sekali tidak dibuat
            // =========================================================
            if (!isSelesai) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Sedang Berjalan',
                  style: TextStyle(
                    color: Color(0xFF00695C),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ================= CARD INFORMASI OBAT =================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF00695C), size: 22),
                      const SizedBox(width: 10),
                      const Text(
                        'Informasi Obat',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003366)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildRow('Nama Obat', obat.namaObat),
                  _buildRow('Tipe Obat', obat.tipeObat ?? 'Tablet'),
                  _buildRow('Dosis', obat.dosis ?? '-', valueColor: const Color(0xFF00695C)),
                  _buildRow('Frekuensi', obat.frekuensi ?? '-'),

                  const SizedBox(height: 12),

                  // Jadwal Konsumsi (Hari) Section
                  Text(
                      'Jadwal Konsumsi',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                  const SizedBox(height: 12),

                  // Wrap untuk Hari (Blok Terpisah, Warna Abu-abu, Teks Hitam)
                  if (sortedDays.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortedDays.map((hari) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5), // Warna latar abu-abu
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hari,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12), // Teks hitam
                        ),
                      )).toList(),
                    ),

                  const SizedBox(height: 20),

                  // Waktu Konsumsi (Jam) Section
                  Text(
                      'Waktu Konsumsi',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)
                  ),
                  const SizedBox(height: 12),

                  // Wrap untuk Waktu (Teks & Ikon Hitam)
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: times.map((t) {
                      final formattedTime = t.length >= 5 ? t.substring(0, 5).replaceAll(':', '.') : t;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.black), // Ikon diubah ke hitam
                          const SizedBox(width: 6),
                          Text(
                            '$formattedTime WIB',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 13), // Teks diubah ke hitam
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= CARD REKAP OBAT =================
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RekapObatScreen(
                      jadwal: jadwal,
                      times: times,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Rekap Obat",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF003366)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Lihat riwayat dan kalender kepatuhan bulan ini.",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.chevron_right_rounded, // Tanda panah agar pengguna tahu ini bisa diklik
                      color: Colors.grey.shade400,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // ================= FLOATING ACTION BUTTON (Tombol Edit Mengambang) =================
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: ElevatedButton(
          onPressed: isSelesai ? null : () async {
            final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EditObatScreen(jadwal: jadwal))
            );

            if (result == true && context.mounted) {
              Navigator.pop(context, true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006699), // Warna biru sesuai gambar
            disabledBackgroundColor: Colors.grey.shade400,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Bentuk pil
            elevation: 8,
            shadowColor: const Color(0xFF006699).withOpacity(0.4),
          ),
          child: const Text("Edit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
          Text(
              value,
              style: TextStyle(
                  color: valueColor ?? const Color(0xFF003366),
                  fontSize: 13,
                  fontWeight: FontWeight.w600
              )
          ),
        ],
      ),
    );
  }
}