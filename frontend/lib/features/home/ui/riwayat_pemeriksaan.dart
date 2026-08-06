import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// --- PALET WARNA NYAMAN (GRAVES-FRIENDLY) ---
class AppColors {
  static const Color background = Color(0xFFF8FAFB);
  static const Color primaryTeal = Color(0xFF439A97);
  static const Color primaryBlue = Color(0xFF628E90);
  static const Color cardText = Color(0xFF2D3142);
  static const Color secondaryText = Color(0xFF9196A2);
}

class RiwayatPemeriksaanScreen extends StatelessWidget {
  const RiwayatPemeriksaanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent, // Buat transparan agar gradasi terlihat
      child: Container(
        // KUNCI: Gradasi yang identik dengan HomeScreen & MonitoringScreen
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F4F4), AppColors.background],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header Navigasi bergaya iOS (Transparan agar menyatu dengan gradasi)
              const CupertinoSliverNavigationBar(
                largeTitle: Text(
                  "Riwayat",
                  style: TextStyle(fontFamily: 'Poppins', letterSpacing: -0.5),
                ),
                border: null,
                backgroundColor: Colors.transparent,
              ),

              // Konten Daftar Riwayat
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      // GRUP TAHUN 2026
                      _buildYearSection(
                        year: "2026",
                        items: [
                          _buildHistoryTile(
                            date: "25 Maret 2026",
                            stats: "FT3: 3.2 | FT4: 1.4 | TSH: 2.1",
                            status: "Normal",
                            color: CupertinoColors.systemGreen,
                          ),
                          _buildHistoryTile(
                            date: "10 Januari 2026",
                            stats: "FT3: 4.8 | FT4: 2.8 | TSH: 0.1",
                            status: "Tinggi",
                            color: CupertinoColors.systemRed,
                          ),
                        ],
                      ),

                      // GRUP TAHUN 2025
                      _buildYearSection(
                        year: "2025",
                        items: [
                          _buildHistoryTile(
                            date: "15 November 2025",
                            stats: "FT3: 5.1 | FT4: 3.2 | TSH: 0.05",
                            status: "Tinggi",
                            color: CupertinoColors.systemRed,
                          ),
                          _buildHistoryTile(
                            date: "02 September 2025",
                            stats: "FT3: 4.2 | FT4: 2.1 | TSH: 0.8",
                            status: "Normal",
                            color: CupertinoColors.systemGreen,
                          ),
                          _buildHistoryTile(
                            date: "20 Juni 2025",
                            stats: "FT3: 3.8 | FT4: 1.8 | TSH: 1.2",
                            status: "Normal",
                            color: CupertinoColors.systemGreen,
                          ),
                        ],
                      ),

                      const SizedBox(height: 120), // Jarak agar tidak tertutup Navbar
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER ---

  Widget _buildYearSection({required String year, required List<Widget> items}) {
    return CupertinoListSection.insetGrouped(
      backgroundColor: Colors.transparent, // Background section transparan agar gradasi terlihat
      header: Text(
        "TAHUN $year",
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryText,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: items,
    );
  }

  Widget _buildHistoryTile({
    required String date,
    required String stats,
    required String status,
    required Color color,
  }) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      title: Text(
        date,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Poppins',
          color: AppColors.cardText,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          stats,
          style: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      additionalInfo: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      trailing: const Icon(
        CupertinoIcons.chevron_forward,
        size: 14,
        color: CupertinoColors.placeholderText,
      ),
      onTap: () {},
    );
  }
}