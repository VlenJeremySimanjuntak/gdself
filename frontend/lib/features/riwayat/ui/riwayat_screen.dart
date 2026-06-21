import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/usg_tiroid_model.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../../monitoring/ui/lab_detail_screen.dart';
import '../provider/riwayat_provider.dart';
import 'riwayat_hormon_detail_screen.dart';
import '../../monitoring/ui/usg_detail_screen.dart';

class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  String _activeFilter = 'LAB';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() {
        ref.read(riwayatProvider.notifier).fetchRiwayatData(userId);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final riwayatState = ref.watch(riwayatProvider);
    final user = ref.watch(userProvider).user;
    final rawItems = riwayatState.items;

    final filteredItems = rawItems.where((item) {
      if (_activeFilter == 'LAB' && item['type'] != 'lab') return false;
      if (_activeFilter == 'USG' && item['type'] != 'usg') return false;

      if (_activeFilter == 'USG' && _searchQuery.isNotEmpty) {
        final title = (item['raw_data'] as UsgTiroidModel).namaRs.toLowerCase();
        final subtitle = (item['formatted_date'] ?? '').toString().toLowerCase();

        if (!title.contains(_searchQuery) && !subtitle.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    String topDate = DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());
    if (rawItems.isNotEmpty) {
      topDate = rawItems.first['formatted_date'] ?? topDate;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4],
            colors: [Color(0xFFEAF5FF), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: riwayatState.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildTopHeader(user),
                const SizedBox(height: 40),

                const Text("Riwayat\nLaboratorium",
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                        height: 1.1,
                        letterSpacing: -1.0)),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDFF0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_today_outlined, color: Color(0xFF005085), size: 22),
                    ),
                    const SizedBox(width: 16),
                    Text(topDate, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 32),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _activeFilter == 'USG'
                      ? Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildSearchBar(),
                  )
                      : const SizedBox.shrink(),
                ),

                _buildFilterChips(),
                const SizedBox(height: 16),

                if (filteredItems.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Text("Data tidak ditemukan.",
                          style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.w500)),
                    ),
                  )
                else
                  ..._buildGroupedItems(filteredItems),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/graves-logo.png',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.medical_services,
                  color: Color(0xFF005085),
                  size: 28,
                );
              },
            ),
            const SizedBox(width: 10),
            const Text(
              "Graves disease",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Color(0xFF005085),
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EFEE),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: const InputDecoration(
          hintText: "Cari nama rumah sakit...",
          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B), size: 22),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildChip("LAB", "LAB"),
        const SizedBox(width: 12),
        _buildChip("USG", "USG"),
      ],
    );
  }

  Widget _buildChip(String label, String filterValue) {
    bool isSelected = _activeFilter == filterValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = filterValue;
          _searchQuery = '';
          _searchController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDFF0FF) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: isSelected ? const Color(0xFF005085) : const Color(0xFF475569),
              letterSpacing: 0.5
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems(List<Map<String, dynamic>> items) {
    List<Widget> widgets = [];
    String lastDate = '';

    for (var item in items) {
      final date = item['formatted_date'] ?? '-';
      if (date != lastDate) {
        widgets.add(_buildDateHeader(date));
        lastDate = date;
      }

      if (item['type'] == 'lab') {
        widgets.add(_buildLabCard(item));
      } else if (item['type'] == 'usg') {
        widgets.add(_buildUsgCard(item));
      }
    }
    return widgets;
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, right: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          date,
          style: const TextStyle(
            color: Color(0xFF334155),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildLabCard(Map<String, dynamic> item) {
    return _buildCard(
      icon: Icons.stacked_line_chart_rounded,
      iconBgColor: const Color(0xFFE6F0F9),
      iconColor: const Color(0xFF005A8C),
      title: 'Hasil Laboratorium',
      subtitle: item['formatted_date'] ?? '-',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LabDetailScreen(
              reportData: item,
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsgCard(Map<String, dynamic> item) {
    final usg = item['raw_data'] as UsgTiroidModel;
    return _buildCard(
      icon: Icons.description_outlined,
      iconBgColor: const Color(0xFFE6F0F9),
      iconColor: const Color(0xFF005A8C),
      title: usg.namaRs.isNotEmpty ? usg.namaRs : 'Pemeriksaan USG',
      subtitle: item['formatted_date'] ?? '-',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UsgDetailScreen(
              usgId: usg.idUsg!,
              usgData: usg,
            ),
          ),
        );
      },
    );
  }

  // ✅ PERBAIKAN: Kurung tutup yang benar
  Widget _buildCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}