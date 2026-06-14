import 'package:flutter/material.dart';

class NotifikasiObatDialog extends StatelessWidget {
  final String namaObat;

  const NotifikasiObatDialog({super.key, required this.namaObat});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Agar tinggi pop-up menyesuaikan isi
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ikon Jam dengan background biru pudar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.alarm, color: Color(0xFF006699), size: 32),
                ),
                const SizedBox(width: 16),

                // Judul dan Deskripsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Waktunya Minum Obat!',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F3B42)
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Saatnya konsumsi $namaObat. Jangan lupa minum air putih yang cukup.',
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF6B7280)
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Tombol "SUDAH DIMINUM" dan "TUNDA"
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      // Tutup pop-up
                      Navigator.pop(context);
                      // Tampilkan pesan sukses di bawah layar
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hebat! Anda sudah minum obat.'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006699),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                        'SUDAH DIMINUM',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      // Tutup pop-up
                      Navigator.pop(context);
                      // Tampilkan pesan tunda
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Diingatkan kembali nanti.'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                        'TUNDA',
                        style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, letterSpacing: 0.5)
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}