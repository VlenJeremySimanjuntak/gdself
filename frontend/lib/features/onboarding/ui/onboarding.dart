import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAFF);
  static const Color primaryBlue = Color(0xFF005F82);
  static const Color textDark = Color(0xFF2D4052);
  static const Color textGrey = Color(0xFF7D848D);
  static const Color bgGradientTop = Color(0xFFE3F4F4);
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.bgGradientTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // HEADER LOGO
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/graves-logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Graves disease",
                      style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ],
                ),
              ),

              // KONTEN UTAMA
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.08),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),

                              // GAMBAR
                              Center(
                                child: Container(
                                  height: constraints.maxHeight * 0.4,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(80),
                                    image: const DecorationImage(
                                      image: AssetImage(
                                          'assets/images/onboard.png'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),

                              // JUDUL
                              RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                      height: 1.1),
                                  children: [
                                    TextSpan(text: "Selamat Datang di\n"),
                                    TextSpan(
                                      text: "Graves disease",
                                      style: TextStyle(
                                          color: AppColors.primaryBlue),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // DESKRIPSI
                              const Text(
                                "Mari menjaga kesehatan anda dengan cara yang lebih tenang dan teratur setiap harinya.",
                                style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textGrey,
                                    height: 1.5),
                              ),
                              const SizedBox(height: 30),

                              // CHIP FITUR
                              Row(
                                children: [
                                  _buildFeatureChip(
                                      Icons.show_chart, "Pantau Hasil Lab"),
                                  const SizedBox(width: 12),
                                  _buildFeatureChip(
                                      Icons.medication, "Jadwal Obat"),
                                ],
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // FOOTER TOMBOL
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08, vertical: 20),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('has_seen_onboarding', true);

                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        elevation: 4,
                        shadowColor: AppColors.primaryBlue.withOpacity(0.3),
                      ),
                      child: const Text(
                        "Masuk",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Belum punya akun?",
                            style: TextStyle(
                                color: AppColors.textGrey, fontSize: 14)),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            " Daftar",
                            style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
        ],
      ),
    );
  }
}