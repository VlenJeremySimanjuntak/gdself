import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../models/obat_model.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../providers/obat_provider.dart';
import 'tambah_obat_screen.dart';
import 'edit_obat_screen.dart';
import '../../../services/notification_service.dart';


class JadwalObatScreen extends ConsumerStatefulWidget {
  const JadwalObatScreen({super.key});

  @override
  ConsumerState<JadwalObatScreen> createState() => _JadwalObatScreenState();
}

class _JadwalObatScreenState extends ConsumerState<JadwalObatScreen> {
  String _searchQuery = '';

  // State untuk fitur Hapus (Long Press / Multi-Select)
  bool _isSelectionMode = false;
  final Set<int> _selectedObatIds = {};

  // State lokal untuk switch agar tidak full refresh layar
  final Map<int, bool> _localSwitchStates = {};

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
      Future.microtask(() {
        ref.read(homeProvider.notifier).fetchAll(userId);
      });
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
      _localSwitchStates.clear();
    }
  }

  void _toggleSelection(int idObat) {
    setState(() {
      if (_selectedObatIds.contains(idObat)) {
        _selectedObatIds.remove(idObat);
        if (_selectedObatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedObatIds.add(idObat);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final user = ref.watch(userProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _isScrolled ? Colors.white.withOpacity(0.95) : Colors.transparent,
        elevation: _isScrolled ? 1 : 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005F82)),
          onPressed: () {
            // Jika mode seleksi, tombol back berfungsi sebagai cancel
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
        // Judul tetap "Obat", tidak berubah jadi angka
        title: const Text(
          "Obat",
          style: TextStyle(color: Color(0xFF005F82), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isSelectionMode)
          // Tombol "Batalkan" muncul saat menahan item
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedObatIds.clear();
                });
              },
              child: const Text("Batalkan", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
            )
          else
          // Foto Profil
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE3ECF7),
                backgroundImage: const NetworkImage('https://i.pravatar.cc/150?u=vlen'),
                child: (user?.nama == null)
                    ? const Text('V', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold))
                    : null,
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            left: -90,
            top: 80,
            child: _GlowBubble(color: const Color(0xFFB5F0DA).withOpacity(0.4), size: 250),
          ),
          Positioned(
            right: -100,
            top: -20,
            child: _GlowBubble(color: const Color(0xFFB8D9FF).withOpacity(0.3), size: 250),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: homeState.isLoading && _localSwitchStates.isEmpty
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
                    const Text(
                      "Obat",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDateCard(),
                    const SizedBox(height: 24),
                    _buildSearchBar(),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildAddButton(),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Daftar Obat",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMedicationList(homeState.jadwalObat),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Tombol Hapus (2)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isSelectionMode && _selectedObatIds.isNotEmpty
          ? SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () => _showDeleteConfirmation(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC62828), // Merah gelap
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25), // Pill shape
            ),
            elevation: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline, size: 20),
              const SizedBox(width: 8),
              Text(
                "Hapus (${_selectedObatIds.length})",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildDateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFDDEBFA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today, color: Color(0xFF005F82), size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D4052)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: const InputDecoration(
          hintText: "Cari obat...",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const TambahObatScreen()));
        if (result != null) await _refresh();
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text("Tambah Obat", style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006699),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildMedicationList(List<JadwalObatModel> jadwalObat) {
    String _norm(String? v) {
      if (v == null) return '';
      final cleaned = v.trim();
      if (cleaned.length >= 5) return cleaned.substring(0, 5);
      return cleaned;
    }

    final groupedByObat = <int, List<JadwalObatModel>>{};
    for (final jadwal in jadwalObat) {
      groupedByObat.putIfAbsent(jadwal.idObat, () => []).add(jadwal);
    }

    final filtered = groupedByObat.entries
        .where((entry) => entry.value.isNotEmpty)
        .where((entry) => entry.value.first.obat.namaObat.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Belum ada obat', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filtered.map((entry) {
        final jadwalGroup = entry.value;
        final firstJadwal = jadwalGroup.first;

        final times = <String>{};
        for (final j in jadwalGroup) {
          if (j.waktuMinumObat != null && j.waktuMinumObat!.isNotEmpty) {
            final splitTimes = j.waktuMinumObat!.split(',');
            for (var t in splitTimes) {
              times.add(_norm(t));
            }
          }
        }

        return _buildMedicationItem(
          context,
          firstJadwal.obat.namaObat,
          firstJadwal.obat.dosis ?? '-',
          firstJadwal.obat.statusAktif,
          firstJadwal,
          times.toList()..sort(),
        );
      }).toList(),
    );
  }

  // 👇 PERUBAHAN: Desain Card dengan Garis Hijau Kiri (Sesuai Figma)
  Widget _buildMedicationItem(
      BuildContext context,
      String name,
      String dosage,
      bool isActiveFromServer,
      JadwalObatModel jadwalObat,
      List<String> times,
      ) {
    final isSelected = _selectedObatIds.contains(jadwalObat.idObat);
    final currentStatus = _localSwitchStates[jadwalObat.idObat] ?? isActiveFromServer;

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
              activeColor: const Color(0xFF4285F4), // Biru khas selection
              shape: const CircleBorder(),
              side: const BorderSide(color: Colors.grey, width: 1.5),
              onChanged: (bool? value) {
                _toggleSelection(jadwalObat.idObat);
              },
            )
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: GestureDetector(
              onLongPress: () {
                if (!_isSelectionMode) {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedObatIds.add(jadwalObat.idObat);
                  });
                }
              },
              onTap: () {
                if (_isSelectionMode) {
                  _toggleSelection(jadwalObat.idObat);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditObatScreen(jadwal: jadwalObat),
                    ),
                  ).then((_) => _refresh());
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F4FA) : Colors.white,
                  borderRadius: BorderRadius.circular(32), // Sangat membulat
                  border: Border.all(
                    color: isSelected ? const Color(0xFF4285F4) : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30), // Mengikuti kontur shadow
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Garis hijau di pinggir kiri
                        Container(
                          width: 8,
                          color: const Color(0xFF00695C), // Warna hijau gelap khas desain Mas
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE8F5E9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(PhosphorIcons.pill(PhosphorIconsStyle.regular), color: const Color(0xFF00695C), size: 26),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF101828)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$dosage",
                                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      if (times.isNotEmpty)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: times.map((time) => _buildTimeChip(time.trim())).toList(),
                                        )
                                      else
                                        Text('Belum ada jam minum', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Switch Aktif/Nonaktif
                                Transform.scale(
                                  scale: 0.85,
                                  child: Switch(
                                    value: currentStatus,
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: const Color(0xFF00695C),
                                    inactiveThumbColor: Colors.white,
                                    inactiveTrackColor: Colors.grey.shade300,
                                    onChanged: _isSelectionMode
                                        ? null
                                        : (bool newValue) {
                                      setState(() {
                                        _localSwitchStates[jadwalObat.idObat] = newValue;
                                      });
                                      _toggleStatus(jadwalObat, newValue, times);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _toggleStatus(JadwalObatModel jadwalObat, bool newStatus, List<String> times) async {
    final user = ref.read(userProvider).user;
    if (user == null) return;

    final hariList = jadwalObat.obat.hariKonsumsi?.split(',').where((e) => e.isNotEmpty).toList() ?? [];
    final formattedDate = jadwalObat.obat.tanggalMulai != null
        ? DateFormat('yyyy-MM-dd').format(jadwalObat.obat.tanggalMulai!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final waktuKonsumsiFormatted = times.map((t) => "$t:00").toList();

    final success = await ref.read(obatProvider.notifier).editObatDenganJadwal(
      idObat: jadwalObat.idObat,
      userId: user.idUser,
      namaObat: jadwalObat.obat.namaObat,
      dosis: jadwalObat.obat.dosis ?? '',
      waktuKonsumsi: waktuKonsumsiFormatted,
      tanggalMulai: formattedDate,
      hariKonsumsi: hariList,
      statusAktif: newStatus,
    );

    if (success) {
      // ========================================================
      // 👇 TAMBAHAN: UPDATE ALARM SAAT SAKELAR DIGESER 👇
      // ========================================================
      try {
        if (newStatus) {
          // 1. Jika Diaktifkan -> Jadwalkan Alarm baru
          // Ubah string jam "08:00" ke objek TimeOfDay agar dimengerti NotificationService
          List<TimeOfDay> timeOfDays = times.map((t) {
            final parts = t.split(':');
            return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }).toList();

          await NotificationService().jadwalkanAlarmObat(
            idObat: jadwalObat.idObat,
            namaObat: jadwalObat.obat.namaObat,
            hariKonsumsi: hariList,
            waktuKonsumsi: timeOfDays,
          );
          debugPrint("🔔 Alarm diaktifkan untuk ${jadwalObat.obat.namaObat}");
        } else {
          // 2. Jika Dinonaktifkan -> Batalkan/Hapus Alarm dari HP
          await NotificationService().batalkanAlarmObat(
            idObat: jadwalObat.idObat,
            hariKonsumsi: hariList,
            jumlahWaktu: times.length,
          );
          debugPrint("🔕 Alarm dimatikan untuk ${jadwalObat.obat.namaObat}");
        }
      } catch (e) {
        debugPrint("Gagal sinkronisasi alarm saat toggle: $e");
      }
      // ========================================================

      // Tampilkan notifikasi kecil di bawah layar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${jadwalObat.obat.namaObat} berhasil di-${newStatus ? "aktifkan" : "nonaktifkan"}'),
          backgroundColor: newStatus ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      // Jika API gagal, kembalikan posisi sakelar ke posisi semula
      setState(() {
        _localSwitchStates[jadwalObat.idObat] = !newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengubah status di server'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Obat', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus ${_selectedObatIds.length} obat yang dipilih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSelectedItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedItems() async {
    bool adaError = false;
    for (final idObat in _selectedObatIds) {
      final sukses = await ref.read(obatProvider.notifier).hapusObat(idObat);
      if (!sukses) adaError = true;
    }

    if (adaError) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beberapa obat gagal dihapus'), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Obat berhasil dihapus'), backgroundColor: Colors.green));
    }

    setState(() {
      _isSelectionMode = false;
      _selectedObatIds.clear();
    });
    await _refresh();
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