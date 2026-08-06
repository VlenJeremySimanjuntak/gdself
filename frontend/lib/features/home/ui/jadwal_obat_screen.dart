import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../models/obat_model.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import 'detail_obat_screen.dart';
import 'tambah_obat_screen.dart';

class JadwalObatScreen extends ConsumerStatefulWidget {
  const JadwalObatScreen({super.key});

  @override
  ConsumerState<JadwalObatScreen> createState() => _JadwalObatScreenState();
}

class _JadwalObatScreenState extends ConsumerState<JadwalObatScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late ScrollController _scrollController;
  late TabController _tabController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tabController = TabController(length: 2, vsync: this);

    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 10 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Pemicu re-render list saat tab ditekan
      }
    });

    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() => ref.read(homeProvider.notifier).fetchAll(userId));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      await ref.read(homeProvider.notifier).fetchAll(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _isScrolled ? Colors.white.withOpacity(0.95) : Colors.transparent,
        elevation: _isScrolled ? 1 : 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006699)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Jadwal Obat",
          style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          Positioned(left: -90, top: 80, child: _GlowBubble(color: const Color(0xFFB5F0DA).withOpacity(0.4), size: 250)),
          Positioned(right: -100, top: -20, child: _GlowBubble(color: const Color(0xFFB8D9FF).withOpacity(0.3), size: 250)),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: homeState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : homeState.errorMessage != null
                  ? Center(child: Text('Error: ${homeState.errorMessage}'))
                  : SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text("Obat", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    _buildDateCard(),
                    const SizedBox(height: 24),
                    const Text("Daftar Obat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 24),

                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF006699),
                      indicatorWeight: 3,
                      labelColor: const Color(0xFF006699),
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      tabs: const [
                        Tab(text: "Sedang Berjalan"),
                        Tab(text: "Rekapan Obat"),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Filter list data berdasarkan status aktif atau selesai (index tab)
                    _buildMedicationList(homeState.jadwalObat, isSelesai: _tabController.index == 1),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahObatScreen()),
          );

          if (result == true && mounted) {
            await Future.delayed(const Duration(milliseconds: 300));
            await _refresh();
          }
        },
        icon: Icon(PhosphorIcons.plusCircle(PhosphorIconsStyle.regular), size: 20),
        label: const Text("Tambah Obat", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF006699),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFE8ECEE), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFDDEBFA), shape: BoxShape.circle),
            child: const Icon(Icons.calendar_today, color: Color(0xFF005F82), size: 18),
          ),
          const SizedBox(width: 16),
          Text(
            DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFE8ECEE), borderRadius: BorderRadius.circular(16)),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: "Cari Obat",
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.regular), color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMedicationList(List<JadwalObatModel> jadwalObat, {required bool isSelesai}) {
    final groupedById = <int, List<JadwalObatModel>>{};
    for (final j in jadwalObat) {
      groupedById.putIfAbsent(j.idObat, () => []).add(j);
    }

    final filteredList = <List<JadwalObatModel>>[];
    for (final entry in groupedById.entries) {
      final list = entry.value;
      final obat = list.first.obat;

      if (obat.namaObat.toLowerCase().contains(_searchQuery.toLowerCase())) {
        // ✅ LOGIKA BARU UNTUK MEMASTIKAN STATUS:
        // Karena semua obat sekarang pasti ada tanggal_selesai,
        // Status "Selesai" berlaku JIKA HARI INI > TANGGAL SELESAI
        bool statusObatSelesai = false;

        if (obat.tglSelesai != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final endDate = DateTime(obat.tglSelesai!.year, obat.tglSelesai!.month, obat.tglSelesai!.day);

          // True jika batas waktu sudah lewat dari hari ini
          statusObatSelesai = endDate.isBefore(today);
        }

        if (statusObatSelesai == isSelesai) {
          filteredList.add(list);
        }
      }
    }

    if (filteredList.isEmpty) return _buildEmptyState();

    return Column(
      children: filteredList.map((list) {
        final obat = list.first.obat;

        final times = <String>{};
        for (var j in list) {
          if (j.waktuMinumObat != null) {
            for (var t in j.waktuMinumObat!.split(',')) {
              final trimmed = t.trim();
              if (trimmed.length >= 5) times.add(trimmed.substring(0, 5));
            }
          }
        }

        return _buildMedicationItem(context, obat, times.toList()..sort(), list);
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE8ECEE),
            radius: 40,
            child: Icon(
              PhosphorIcons.pill(PhosphorIconsStyle.regular),
              color: Colors.grey.shade500,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum Ada Obat',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF263238)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tidak ada jadwal obat yang\nsesuai dengan pencarian/kategori ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(BuildContext context, ObatModel obat, List<String> times, List<JadwalObatModel> allJadwal) {
    // Membentuk string rentang tanggal: 12 Jul 2026 - 20 Jul 2026
    String rentangTgl = "-";
    if (obat.tglMulai != null && obat.tglSelesai != null) {
      final mulai = DateFormat('d MMM yyyy', 'id_ID').format(obat.tglMulai!);
      final selesai = DateFormat('d MMM yyyy', 'id_ID').format(obat.tglSelesai!);
      rentangTgl = "$mulai - $selesai";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          final daysSet = <String>{};
          for (var j in allJadwal) {
            if (j.hari != null) daysSet.addAll(j.hari!.split(',').map((e) => e.trim()));
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailObatScreen(
                jadwal: allJadwal.first,
                times: times,
                days: daysSet.toList(),
              ),
            ),
          ).then((result) {
            if (result == true && mounted) _refresh();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFF00695C), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFF00695C).withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: Icon(PhosphorIcons.pill(PhosphorIconsStyle.regular), color: const Color(0xFF00695C), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obat.namaObat,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF101828), letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${obat.dosis ?? '-'}    ${obat.frekuensi ?? '-'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    // Menampilkan Tanggal Mulai dan Selesai
                    Text(
                      rentangTgl,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    if (times.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: times.map((t) => _buildTimeChip(t)).toList(),
                      )
                    else
                      Text('Belum ada jam', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
      child: Text(time, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4B5563), fontSize: 12)),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
      ),
    );
  }
}