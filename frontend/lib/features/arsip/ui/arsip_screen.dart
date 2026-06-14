import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../provider/arsip_provider.dart'; // Pastikan path ini benar
import 'arsip_hormon_detail_screen.dart';

class ArsipScreen extends ConsumerStatefulWidget {
  const ArsipScreen({super.key});

  @override
  ConsumerState<ArsipScreen> createState() => _ArsipScreenState();
}

class _ArsipScreenState extends ConsumerState<ArsipScreen> {
  @override
  void initState() {
    super.initState();
    // Tarik data saat layar dibuka
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() => ref.read(arsipProvider.notifier).fetchArsipData(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final arsipState = ref.watch(arsipProvider);

    // 👇 INI YANG KURANG MAS! Kita tarik data usernya dari provider
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
          child: arsipState.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(user), // Sekarang 'user' sudah dikenali di sini
                const SizedBox(height: 35),

                const Text("Arsip Data Hormon",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                const Text(
                  "Tinjau riwayat pemeriksaan laboratorium Anda dan pantau tren kesehatan tiroid secara berkala.",
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.5),
                ),

                const SizedBox(height: 25),
                _buildSearchBar(),
                const SizedBox(height: 40),

                // 👇 Render Daftar Dinamis
                if (arsipState.laporanList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("Belum ada riwayat pemeriksaan laboratorium.",
                          style: TextStyle(color: AppColors.textGrey)),
                    ),
                  )
                else
                  ..._buildDynamicList(arsipState.laporanList),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menyusun urutan Kartu dan Header Tanggal
  List<Widget> _buildDynamicList(List<Map<String, dynamic>> laporanList) {
    List<Widget> widgets = [];
    String lastDate = "";

    for (var laporan in laporanList) {
      // Cek apakah tanggalnya sama dengan kartu sebelumnya. Jika beda, buat Header Tanggal.
      if (laporan['formatted_date'] != lastDate) {
        widgets.add(_buildDateHeader(laporan['formatted_date']));
        lastDate = laporan['formatted_date'];
      }

      widgets.add(_buildHormonCard(
        namaLab: laporan['nama_lab'],
        ringkasanStatus: laporan['ringkasan'],
        time: laporan['time'],
        dataLengkap: laporan['raw_data'],
      ));
    }

    return widgets;
  }

  Widget _buildHeader(user) {
    final String initial = (user?.nama != null && user!.nama.isNotEmpty)
        ? user.nama[0].toUpperCase()
        : '?';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset('assets/images/graves-logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text("Graves disease", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 18)),
          ],
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE3ECF7),
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: "Cari riwayat pemeriksaan...",
          hintStyle: TextStyle(color: Colors.black26, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: AppColors.primaryBlue, size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Text(date,
              style: const TextStyle(
                  color: Colors.black26, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(width: 15),
          Expanded(child: Divider(color: Colors.black.withOpacity(0.05), thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildHormonCard({
    required String namaLab,
    required String ringkasanStatus,
    required String time,
    required Map<String, dynamic> dataLengkap,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArsipHormonDetailScreen(
              idLaporanLab: dataLengkap['id_laporan_lab'], // Diambil dari API
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
            ]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: Color(0xFFEDF4F8),
                  shape: BoxShape.circle),
              child: const Icon(Icons.stacked_line_chart_rounded, color: AppColors.primaryBlue, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          namaLab,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(time,
                          style: const TextStyle(
                              color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(ringkasanStatus,
                      style: const TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  const Text("Lihat Detail >",
                      style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}