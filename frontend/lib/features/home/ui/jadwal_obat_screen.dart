import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gdself/features/home/ui/rekap_obat_screen.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../models/obat_model.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../providers/obat_provider.dart';
import 'detail_obat_screen.dart';
import 'tambah_obat_screen.dart';
import 'edit_obat_screen.dart';

class JadwalObatScreen extends ConsumerStatefulWidget {
  const JadwalObatScreen({super.key});

  @override
  ConsumerState<JadwalObatScreen> createState() => _JadwalObatScreenState();
}

class _JadwalObatScreenState extends ConsumerState<JadwalObatScreen> {
  String _searchQuery = '';
  int _selectedTab = 0;
  bool _isSelectionMode = false;
  final Set<int> _selectedObatIds = {};
  late ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 10 && _isScrolled) {
        setState(() => _isScrolled = false);
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
    super.dispose();
  }

  Future<void> _refresh() async {
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      await ref.read(homeProvider.notifier).fetchAll(userId);
    }
  }

  void _toggleSelection(int idObat) {
    setState(() {
      if (_selectedObatIds.contains(idObat)) {
        _selectedObatIds.remove(idObat);
        if (_selectedObatIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedObatIds.add(idObat);
      }
    });
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
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _isSelectionMode = false;
                _selectedObatIds.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "Jadwal Obat",
          style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isSelectionMode)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedObatIds.clear();
                });
              },
              child: const Text("Batalkan", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
            )
        ],
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
                    const SizedBox(height: 16),
                    _buildCustomTabBar(),
                    const SizedBox(height: 32),
                    _buildMedicationList(homeState.jadwalObat),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: _isSelectionMode && _selectedObatIds.isNotEmpty
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: _isSelectionMode && _selectedObatIds.isNotEmpty
          ? SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () => _showDeleteConfirmation(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 20),
              const SizedBox(width: 8),
              Text("Hapus (${_selectedObatIds.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      )
          : ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const TambahObatScreen()));
          if (result != null) await _refresh();
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

  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE8ECEE), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Center(child: Text("Sedang Dikonsumsi", style: TextStyle(color: _selectedTab == 0 ? const Color(0xFF1F2937) : Colors.grey.shade600, fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal))),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
                ),
                child: Center(child: Text("Rekapan Obat", style: TextStyle(color: _selectedTab == 1 ? const Color(0xFF1F2937) : Colors.grey.shade600, fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationList(List<JadwalObatModel> jadwalObat) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final groupedById = <int, List<JadwalObatModel>>{};
    for (final j in jadwalObat) {
      groupedById.putIfAbsent(j.idObat, () => []).add(j);
    }

    final Map<String, List<JadwalObatModel>> groupedByDate = {};

    for (final entry in groupedById.entries) {
      final list = entry.value;
      final obat = list.first.obat;

      bool isAktif = true;
      if (obat.tglSelesai != null) {
        final batas = DateTime(obat.tglSelesai!.year, obat.tglSelesai!.month, obat.tglSelesai!.day);
        isAktif = batas.isAfter(today) || batas.isAtSameMomentAs(today);
      }

      if ((_selectedTab == 0 && !isAktif) || (_selectedTab == 1 && isAktif)) continue;
      if (!obat.namaObat.toLowerCase().contains(_searchQuery.toLowerCase())) continue;

      final startStr = obat.tglMulai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(obat.tglMulai!) : '-';
      final endStr = obat.tglSelesai != null ? DateFormat('d MMMM yyyy', 'id_ID').format(obat.tglSelesai!) : '-';
      final dateKey = "$startStr - $endStr";

      groupedByDate.putIfAbsent(dateKey, () => []).addAll(list);
    }

    if (groupedByDate.isEmpty) return _buildEmptyState();

    return Column(
      children: groupedByDate.entries.map((entry) {
        final dateKey = entry.key;
        final jadwalList = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12, right: 8),
                child: Text(
                  dateKey,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
                ),
              ),
            ),
            ..._renderCardsForDateGroup(jadwalList),
          ],
        );
      }).toList(),
    );
  }

  List<Widget> _renderCardsForDateGroup(List<JadwalObatModel> list) {
    final uniqueObatIds = list.map((j) => j.idObat).toSet();

    return uniqueObatIds.map((id) {
      final obatJadwals = list.where((j) => j.idObat == id).toList();
      final obat = obatJadwals.first.obat;

      final times = <String>{};
      for (var j in obatJadwals) {
        if (j.waktuMinumObat != null) {
          for (var t in j.waktuMinumObat!.split(',')) {
            final trimmed = t.trim();
            if (trimmed.length >= 5) times.add(trimmed.substring(0, 5));
          }
        }
      }

      return _buildMedicationItem(context, obat, times.toList()..sort(), obatJadwals);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
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
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anda belum menambahkan\njadwal konsumsi obat untuk hari ini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  // 👇 DESAIN KAPSUL FULL (Rounded 40) seperti di gambar
  Widget _buildMedicationItem(BuildContext context, ObatModel obat, List<String> times, List<JadwalObatModel> allJadwal) {
    final isSelected = _selectedObatIds.contains(obat.idObat);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSelectionMode ? 40 : 0,
            child: _isSelectionMode
                ? Checkbox(
              value: isSelected,
              activeColor: const Color(0xFF4285F4),
              shape: const CircleBorder(),
              onChanged: (bool? value) => _toggleSelection(obat.idObat),
            ) : const SizedBox.shrink(),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedObatIds.add(obat.idObat);
                  });
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(obat.idObat);
                } else {
                  final daysSet = <String>{};
                  for (var j in allJadwal) {
                    if (j.hari != null) daysSet.addAll(j.hari!.split(',').map((e) => e.trim()));
                  }

                  if (_selectedTab == 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailObatScreen(
                          jadwal: allJadwal.first,
                          times: times,
                          days: daysSet.toList(),
                        ),
                      ),
                    ).then((_) => _refresh());
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RekapObatScreen(
                          jadwal: allJadwal.first,
                          times: times,
                        ),
                      ),
                    ).then((_) => _refresh());
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F4FA) : Colors.white,
                  borderRadius: BorderRadius.circular(40), // Bentuk Kapsul Sempurna
                  border: Border.all(
                      color: isSelected ? const Color(0xFF4285F4) : const Color(0xFF00695C),
                      width: 1.5
                  ), // Border hijau melingkari seluruh kartu
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00695C).withOpacity(0.15), // Efek glow hijau halus di bawah
                        blurRadius: 15,
                        offset: const Offset(0, 6)
                    )
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
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF101828), letterSpacing: -0.3)
                          ),
                          const SizedBox(height: 4),
                          Text(
                              "${obat.dosis ?? '-'}    ${obat.frekuensi ?? '-'}",
                              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)
                          ),
                          const SizedBox(height: 12),
                          if (times.isNotEmpty)
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: times.map((t) => _buildTimeChip(t)).toList()
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
          ),
        ],
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Obat', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus ${_selectedObatIds.length} obat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBubble({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withOpacity(0.0)])));
  }
}