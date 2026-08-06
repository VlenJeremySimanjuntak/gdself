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
          "Kebijakan Privasi",
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
              child: Icon(Icons.shield_outlined, color: primaryBlue, size: 48),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                "Kebijakan Privasi Aplikasi GDSelf",
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

            // Pendahuluan
            _buildParagraph(
                "Pengembang Aplikasi GDSelf berkomitmen penuh untuk melindungi privasi dan keamanan data pribadi serta data kesehatan pengguna Kami. Kebijakan Privasi ini menjelaskan bagaimana informasi Anda dikumpulkan, digunakan, disimpan, dan dilindungi saat Anda menggunakan aplikasi pemantauan penyakit Graves Disease."),
            const SizedBox(height: 12),
            _buildParagraph(
                "Dengan menggunakan aplikasi GDSelf, Anda menyetujui praktik pengumpulan dan penggunaan data yang dijelaskan dalam dokumen ini."),

            // 1. Informasi yang Kami Kumpulkan
            _buildSectionTitle("1. Informasi yang Kami Kumpulkan"),
            _buildParagraph(
                "Untuk menyediakan fitur pemantauan kesehatan mandiri penyakit tiroid (Graves' Disease) yang akurat, Kami mengumpulkan beberapa kategori data berikut:"),
            const SizedBox(height: 8),
            _buildBulletPoint(
              "Data Akun & Profil",
              "Nama lengkap, alamat email, tanggal lahir, dan tanggal diagnosis tiroid yang Anda masukkan saat pendaftaran atau pembaruan profil.",
            ),
            _buildBulletPoint(
              "Data Rekam Medis & Laboratorium",
              "Catatan kadar hormon tiroid (seperti FT3, FT4, TSHs, dan TRAb), riwayat pemeriksaan medis, catatan dokter, serta berkas/foto hasil USG Tiroid.",
            ),
            _buildBulletPoint(
              "Data Kesehatan Terintegrasi (Google Health Connect)",
              "Jika Anda memberikan izin eksplisit, aplikasi membaca data dari perangkat wearable atau sensor HP Anda meliputi:\n• Detak Jantung (READ_HEART_RATE)\n• Pola Tidur (READ_SLEEP)\n• Tekanan Darah (READ_BLOOD_PRESSURE)",
            ),
            _buildBulletPoint(
              "Data Otentikasi",
              "Token otentikasi aman (JSON Web Token / JWT) untuk memastikan akses akun hanya dapat dilakukan oleh pengguna yang sah.",
            ),

            // 2. Penggunaan Informasi
            _buildSectionTitle("2. Penggunaan Informasi"),
            _buildParagraph(
                "Kami menggunakan data yang dikumpulkan semata-mata untuk fungsi inti aplikasi GdSelf, yaitu:"),
            const SizedBox(height: 8),
            _buildBulletPoint(
              "Visualisasi Kondisi Kesehatan",
              "Menampilkan grafik tren kadar hormon tiroid dan perubahan indikator fisik untuk membantu Anda memantau perkembangan penyakit Graves secara mandiri.",
            ),
            _buildBulletPoint(
              "Pengelolaan Rekam Gambar Medis",
              "Menyimpan dan menampilkan berkas USG Tiroid agar Anda dapat meninjau riwayat pemeriksaan struktur tiroid kapan saja.",
            ),
            _buildBulletPoint(
              "Pengingat Obat & Pemeriksaan Lab (SCHEDULE_EXACT_ALARM)",
              "Mengatur alarm presisi untuk mengingatkan jadwal minum obat tiroid harian dan jadwal kontrol laboratorium berulang.",
            ),
            _buildBulletPoint(
              "Analisis Terintegrasi",
              "Menggabungkan data detak jantung, tidur, dan tekanan darah dari Google Health Connect dengan indikator tiroid untuk memberikan gambaran kondisi fisik harian yang komprehensif.",
            ),

            // 3. Kebijakan Khusus Data Kesehatan & Google Health Connect
            _buildSectionTitle("3. Kebijakan Khusus Data Kesehatan & Google Health Connect"),
            _buildParagraph(
                "Sesuai dengan Google Health Connect User Data Policy dan perlindungan data kesehatan:"),
            const SizedBox(height: 8),
            _buildBulletPoint(
              "TIDAK DIJUAL",
              "Kami TIDAK AKAN PERNAH menjual, menyewakan, memperdagangkan, atau membagikan data kesehatan Anda (termasuk data Health Connect, hasil lab tiroid, dan gambar USG) kepada pihak ketiga, broker data, atau penyedia iklan.",
            ),
            _buildBulletPoint(
              "TANPA IKLAN",
              "Data kesehatan yang dikumpulkan TIDAK AKAN digunakan untuk keperluan periklanan, pemasaran berbasis profil (targeted ads), maupun komersialisasi pihak ketiga.",
            ),
            _buildBulletPoint(
              "Penggunaan Terbatas (Limited Use)",
              "Akses data Health Connect hanya digunakan terbatas untuk fitur pemantauan mandiri dalam aplikasi GdSelf sesuai izin yang Anda berikan secara langsung.",
            ),

            // 4. Keamanan dan Penyimpanan Data
            _buildSectionTitle("4. Keamanan dan Penyimpanan Data"),
            _buildParagraph("Keamanan data Anda adalah prioritas utama Kami:"),
            const SizedBox(height: 8),
            _buildBulletPoint(
              "Enkripsi Transit",
              "Seluruh komunikasi data antara aplikasi GdSelf dan server dienkripsi menggunakan protokol standar industri HTTPS / TLS.",
            ),
            _buildBulletPoint(
              "Akses Terproteksi",
              "Akses ke gambar medis (foto USG dan avatar) dilindungi oleh sistem otentikasi berbasis token (JWT), sehingga tidak dapat diakses secara bebas oleh publik.",
            ),
            _buildBulletPoint(
              "Infrastruktur Server",
              "File dan database disimpan dalam infrastruktur server yang aman dengan pembatasan akses ketat.",
            ),

            // 5. Hak Pengguna & Penghapusan Data
            _buildSectionTitle("5. Hak Pengguna & Penghapusan Data"),
            _buildParagraph("Anda memiliki kontrol penuh atas data Anda di GdSelf:"),
            const SizedBox(height: 8),
            _buildBulletPoint(
              "Pembaruan Data",
              "Anda dapat mengubah data profil atau rekam medis kapan saja langsung melalui menu pengaturan aplikasi.",
            ),
            _buildBulletPoint(
              "Pencabutan Izin",
              "Anda dapat mencabut izin akses Google Health Connect atau alarm kapan saja melalui menu Pengaturan HP (Settings) Anda.",
            ),
            _buildBulletPoint(
              "Penghapusan Akun & Data",
              "Anda berhak meminta penghapusan akun beserta seluruh data rekam medis dan foto USG Anda secara permanen dari server Kami dengan menghubungi Kami melalui email pengembang.",
            ),

            // 6. Hubungi Kami
            _buildSectionTitle("6. Hubungi Kami"),
            _buildParagraph(
                "Jika Anda memiliki pertanyaan, saran, atau permintaan terkait Kebijakan Privasi ini atau penghapusan data, silakan hubungi tim pengembang melalui:"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.badge_outlined, color: primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Pengembang: GdSelf Dev Team (Teknologi Rekayasa Perangkat Lunak, IT Del)",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: const [
                      Icon(Icons.email_outlined, color: primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Email Support: gravediseaseapp@gmail.com",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryBlue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withOpacity(0.1)),
              ),
              child: const Text(
                "Dengan menggunakan aplikasi GDSelf, Anda menyetujui praktik pengumpulan dan penggunaan data yang dijelaskan dalam Kebijakan Privasi ini.",
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
      padding: const EdgeInsets.only(top: 24, bottom: 8),
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

  Widget _buildBulletPoint(String boldTitle, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6, color: Color(0xFF005F82)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF7D848D), height: 1.6),
                children: [
                  TextSpan(
                    text: "$boldTitle: ",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D4052)),
                  ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}