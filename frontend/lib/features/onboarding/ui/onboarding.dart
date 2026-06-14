import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8FAFF);
  static const Color primaryBlue = Color(0xFF005F82);
  static const Color textDark = Color(0xFF2D4052);
  static const Color textGrey = Color(0xFF7D848D);
  static const Color bgGradientTop = Color(0xFFE3F4F4);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardData = [
    {
      "title": "Selamat Datang di",
      "subtitle": "Graves disease",
      "desc": "Mari menjaga kesehatan anda dengan cara yang lebih tenang dan teratur setiap harinya.",
      "btnText": "Masuk",
    },
    {
      "title": "Pantau Hormon",
      "subtitle": "Lebih Mudah",
      "desc": "Catat kadar FT3, FT4, dan TSH anda secara berkala untuk memantau perkembangan kesehatan.",
      "btnText": "Selanjutnya",
    },
    {
      "title": "Siap Memulai",
      "subtitle": "Perjalanan?",
      "desc": "Semua fitur sudah siap digunakan. Masuk ke aplikasi untuk melihat dashboard anda.",
      "btnText": "Mulai Sekarang",
    },
  ];

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
              // HEADER LOGO (SUDAH DIGANTI JADI GRAVES-LOGO)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    // MENGGANTI ICON ECO MENJADI IMAGE LOGO MAS VLEN
                    Image.asset(
                      'assets/images/graves-logo.png', // Sesuai file di assets
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
                          fontSize: 18
                      ),
                    ),
                  ],
                ),
              ),

              // PAGE VIEW CONTENT (DIBUNGKUS EXPANDED AGAR RESPONSIVE)
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (value) => setState(() => _currentPage = value),
                  itemCount: _onboardData.length,
                  itemBuilder: (context, index) {
                    return OnboardContent(
                      title: _onboardData[index]["title"]!,
                      subtitle: _onboardData[index]["subtitle"]!,
                      desc: _onboardData[index]["desc"]!,
                    );
                  },
                ),
              ),

              // FOOTER ACTIONS
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.08,
                    vertical: 20
                ),
                child: Column(
                  children: [
                    if (_currentPage != 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _onboardData.length,
                                (index) => _buildDot(index),
                          ),
                        ),
                      ),

                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage == 0) {
                          // Halaman pertama (Masuk): Langsung ke Login
                          Navigator.pushNamed(context, '/login');
                        } else if (_currentPage == _onboardData.length - 1) {
                          // Halaman terakhir: Langsung ke Dashboard/Home
                          Navigator.pushReplacementNamed(context, '/home');
                        } else {
                          // Halaman tengah (Selanjutnya): Tetap geser carousel
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)
                        ),
                        elevation: 4,
                        shadowColor: AppColors.primaryBlue.withOpacity(0.3),
                      ),
                      child: Text(
                        _onboardData[_currentPage]["btnText"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Belum punya akun?",
                            style: TextStyle(color: AppColors.textGrey, fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            " Daftar",
                            style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14
                            ),
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

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 6,
      width: _currentPage == index ? 20 : 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: _currentPage == index ? AppColors.primaryBlue : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class OnboardContent extends StatelessWidget {
  final String title, subtitle, desc;
  const OnboardContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.desc
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // MENGHILANGKAN OVERFLOW DENGAN SCROLL JIKA LAYAR PENDEK
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GAMBAR UTAMA TETAP ONBOARD.PNG
                  Center(
                    child: Container(
                      height: constraints.maxHeight * 0.4, // Tinggi proporsional
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(80),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/onboard.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          height: 1.1
                      ),
                      children: [
                        TextSpan(text: "$title\n"),
                        TextSpan(
                            text: subtitle,
                            style: const TextStyle(color: AppColors.primaryBlue)
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    desc,
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textGrey,
                        height: 1.5
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      _buildFeatureChip(Icons.show_chart, "Pantau Hormon"),
                      const SizedBox(width: 12),
                      _buildFeatureChip(Icons.medication, "Jadwal Obat"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark
              )
          ),
        ],
      ),
    );
  }
}