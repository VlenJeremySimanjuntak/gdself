import 'package:flutter/material.dart';
import '../../../utils/design_system.dart';


class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3],
            colors: [AppColors.bgGradientTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 35),
                const Text("Edukasi",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text(
                  "Temukan panduan terpercaya untuk perjalanan kesehatan Graves Anda.",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 35),
                const Text("Direkomendasikan Untuk Anda",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 20),
                _buildFeaturedCard(screenHeight, screenWidth),

                const SizedBox(height: 35),

                // --- SECTION TERBARU (DIUBAH SESUAI GAMBAR) ---
                const Text("Terbaru Untuk Anda",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 20),

                _buildArticleListItem(
                  category: "NUTRISI",
                  title: "Diet Rendah Iodium: Apa Saja Pilihannya?",
                  subtitle: "Panduan praktis memilih makanan sehari-hari yang aman untuk...",
                  imagePath: "assets/images/Healthy Food.png",
                  readTime: "5 mnt",
                ),
                _buildArticleListItem(
                  category: "KESEHATAN MENTAL",
                  title: "Mengatasi Gangguan Tidur Akibat Tremor",
                  subtitle: "Tips menciptakan lingkungan tidur yang mendukung pemulihan dan...",
                  imagePath: "assets/images/Mental Balance.png",
                  readTime: "7 mnt",
                ),
                _buildArticleListItem(
                  category: "MANAJEMEN GEJALA",
                  title: "Mengenal Gejala Tiroid Eye Disease (TED)",
                  subtitle: "Cara mendeteksi perubahan dini pada mata dan langkah medis...",
                  imagePath: "assets/images/eyes.png",
                  readTime: "6 mnt",
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
              child: const Icon(Icons.eco, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text("Graves disease", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 18)),
          ],
        ),
        const CircleAvatar(
          radius: 22,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=vlen'),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(double h, double w) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Image.asset(
              "assets/images/Yoga Session.png",
              height: h * 0.25,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Menjaga Ketenangan: Teknik Pernapasan untuk Pasien Graves",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark, height: 1.3),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Kecemasan adalah gejala umum pada hipertiroidisme. Pelajari cara mengelola...",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                const Text("Baca >", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- ARTIKEL LIST ITEM (VERSI FINAL SESUAI GAMBAR) ---
  Widget _buildArticleListItem({
    required String category,
    required String title,
    required String subtitle,
    required String imagePath,
    required String readTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F5), // Warna background kartu sesuai gambar
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              imagePath,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          // Konten Teks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category, style: const TextStyle(color: Color(0xFF00897B), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(readTime, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text("Baca >", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }
}