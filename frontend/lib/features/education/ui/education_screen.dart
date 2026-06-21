import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';

// ✅ UBAH: StatelessWidget menjadi ConsumerWidget
class EducationScreen extends ConsumerWidget {
  const EducationScreen({super.key});

  // Fungsi pembantu untuk meluncurkan URL
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // ✅ Ambil data user
    final user = ref.watch(userProvider).user;

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
                // ✅ TAMBAHKAN: Logo & Foto Profil
                _buildTopHeader(user),
                const SizedBox(height: 30),

                const Text(
                  "Edukasi",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Jangan lewatkan materi edukasi yang\ntelah disediakan.",
                  style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 15,
                      height: 1.4),
                ),
                const SizedBox(height: 40),

                const Text(
                  "Direkomendasikan Untuk Anda",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 20),

                // CARD BESAR (Featured) - Pernapasan
                _buildFeaturedCard(
                  height: screenHeight,
                  imagePath: "assets/images/bernapas.png",
                  title: "Teknik Relaksasi Nafas Dalam",
                  subtitle: "Teknik relaksasi napas dalam membantu tubuh menjadi lebih rileks dengan mengatur napas secara perlahan dan terkontrol. Teknik ini dapat membantu meningkatkan asupan oksigen dan mendukung kenyamanan tubuh.",
                  url: "https://keslan.kemkes.go.id/view_artikel/1054/teknik-relaksasi-nafas-dalam",
                ),

                const SizedBox(height: 24),

                // CARD LIST 1 - Makanan Sehat
                _buildArticleListItem(
                  title: "Ketahui Makanan yang Harus Dimakan Saat Diet Graves",
                  subtitle: "Sayuran cruciferous, seperti arugula, brokoli, kembang kol.",
                  imagePath: "assets/images/makanan_sehat.png",
                  url: "https://www.halodoc.com/artikel/ketahui-makanan-yang-harus-dimakan-saat-diet-graves",
                ),

                // CARD LIST 2 - Olahraga
                _buildArticleListItem(
                  title: "5 Jenis Olahraga yang Aman untuk Pengidap Hipertiroidisme",
                  subtitle: "Hipertiroidisme dapat melemahkan kemampuan seseorang untuk berolahraga.",
                  imagePath: "assets/images/olahraga.png",
                  url: "https://www.halodoc.com/artikel/5-jenis-olahraga-yang-aman-untuk-pengidap-hipertiroidisme",
                ),

                // CARD LIST 3 - Istirahat
                _buildArticleListItem(
                  title: "Penting Tidur Berkualitas, Jaga Kesehatan Fisik dan Mental",
                  subtitle: "Ketika sibuk dengan tugas sehari-hari dan rutinitas yang padat, tidur sering kali menjadi...",
                  imagePath: "assets/images/istirahat.png",
                  url: "https://keslan.kemkes.go.id/read/2539/penting-tidur-berkualitas-jaga-kesehatan-fisik-dan-mental",
                ),

                const SizedBox(height: 100), // Spacing untuk bottom navigation bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ TAMBAHKAN: Widget Logo & Foto Profil
  Widget _buildTopHeader(dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo dan teks
        Row(
          children: [
            Image.asset(
              'assets/images/graves-logo.png',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.medical_services,
                  color: AppColors.primaryBlue,
                  size: 28,
                );
              },
            ),
            const SizedBox(width: 10),
            const Text(
              "Graves disease",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- FEATURED CARD (GAMBAR BESAR DI ATAS) ---
  Widget _buildFeaturedCard({
    required double height,
    required String imagePath,
    required String title,
    required String subtitle,
    required String url,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.asset(
                imagePath,
                height: height * 0.22,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text("Lihat Detail ",
                          style: TextStyle(
                              color: Color(0xFF007B99),
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Icon(Icons.chevron_right, size: 16, color: Color(0xFF007B99))
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- ARTIKEL LIST ITEM (KARTU KECIL DI BAWAH) ---
  Widget _buildArticleListItem({
    required String title,
    required String subtitle,
    required String imagePath,
    required String url,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                imagePath,
                width: 85,
                height: 85,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            // Konten Teks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textDark,
                        height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Text("Lihat Detail ",
                          style: TextStyle(
                              color: Color(0xFF007B99),
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                      Icon(Icons.chevron_right, size: 14, color: Color(0xFF007B99))
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}