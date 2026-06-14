import 'package:flutter/material.dart';

class TermsPrivacyScreen extends StatelessWidget {
  const TermsPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF005F82);
    const Color textDark = Color(0xFF2D4052);
    const Color textGrey = Color(0xFF7D848D);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Syarat & Kebijakan Privasi",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.gavel_rounded, color: primaryBlue, size: 48),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                "Ketentuan Penggunaan & Perlindungan Data",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                "Terakhir diperbarui: 04 Mei 2026",
                style: TextStyle(color: textGrey, fontSize: 12),
              ),
            ),
            const Divider(height: 40, thickness: 1),

            _buildSectionTitle("1. Pendahuluan"),
            _buildParagraph(
                "GD Self adalah aplikasi untuk membantu Anda memantau kesehatan sehari-hari jika memiliki Graves Disease. Dengan mendaftar, berarti Anda telah membaca dan setuju dengan semua ketentuan di sini tentang bagaimana kami mengumpulkan dan menggunakan data kesehatan Anda."),

            _buildSectionTitle("2. Data Apa yang Kami Kumpulkan"),
            _buildParagraph(
                "Untuk memberikan layanan terbaik, kami mengumpulkan informasi kesehatan Anda, termasuk:"),
            _buildBulletPoint("Hasil lab hormon (FT3, FT4, TSH)."),
            _buildBulletPoint("Detak jantung dan pola tidur dari jam tangan pintar Anda."),
            _buildBulletPoint("Catatan obat dan jadwal minum obat harian."),
            _buildBulletPoint("Nama, email, dan tanggal lahir Anda."),

            _buildSectionTitle("3. Kami Gunakan Data Anda Untuk Apa"),
            _buildParagraph(
                "Data yang Anda berikan digunakan untuk membuat grafik dan laporan tren kesehatan Anda. Ini membantu Anda melihat pola perubahan kondisi tubuh dengan lebih jelas dan mudah dipahami."),

            _buildSectionTitle("4. Keamanan Data Anda"),
            _buildParagraph(
                "Data kesehatan Anda adalah informasi pribadi yang sangat penting. Kami melindungi data dengan enkripsi aman dan tidak akan membagikan informasi medis Anda kepada orang lain tanpa izin dari Anda."),

            _buildSectionTitle("5. Penting Diketahui"),
            _buildParagraph(
                "Aplikasi ini hanya membantu Anda memantau kesehatan sehari-hari. GD Self BUKAN pengganti pemeriksaan dokter. Jangan mengabaikan saran dokter atau menunda ke dokter hanya karena melihat data di aplikasi ini. Selalu konsultasikan dengan dokter profesional untuk diagnosis dan pengobatan."),

            _buildSectionTitle("6. Hak-Hak Anda"),
            _buildParagraph(
                "Anda punya hak penuh untuk melihat, mengubah, atau menghapus semua data kesehatan Anda kapan saja. Cukup buka menu pengaturan profil di aplikasi."),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withOpacity(0.1)),
              ),
              child: const Text(
                "Dengan melanjutkan, Anda sudah membaca dan setuju dengan semua Syarat Layanan dan Kebijakan Privasi di atas.",
                style: TextStyle(fontSize: 12, color: primaryBlue, fontWeight: FontWeight.w500, height: 1.5),
                textAlign: TextAlign.justify,
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D4052)),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: const TextStyle(fontSize: 14, color: Color(0xFF7D848D), height: 1.6),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF005F82)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF7D848D), height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}