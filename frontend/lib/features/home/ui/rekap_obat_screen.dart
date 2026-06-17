import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/obat_model.dart';
import '../providers/obat_provider.dart';

class RekapObatScreen extends ConsumerStatefulWidget {
  final JadwalObatModel jadwal;
  final List<String> times;

  const RekapObatScreen({
    super.key,
    required this.jadwal,
    this.times = const [],
  });

  @override
  ConsumerState<RekapObatScreen> createState() => _RekapObatScreenState();
}

class _RekapObatScreenState extends ConsumerState<RekapObatScreen> {
  final PageController _monthPageController = PageController();
  int _currentMonthIndex = 0;
  int _visibleMissedCount = 10; // Paginasi: Tampilkan 10 data awal

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(obatProvider.notifier).fetchLogKonsumsi(widget.jadwal.idJadwalObat);
    });
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    super.dispose();
  }

  // 1. Hitung jumlah obat yang diminum per hari
  Map<String, int> _buildKepatuhanCount(List<LogKonsumsiObatModel> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      if (log.tglKonsumsi != null && log.status?.toLowerCase() == 'diminum') {
        final key = DateFormat('yyyy-MM-dd').format(log.tglKonsumsi!);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  // 2. Tentukan status harian (Teratur, Sebagian, Terlewat)
  String _getStatusHarian(DateTime date, Map<String, int> kepatuhanCount, int targetFrekuensi) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final dateNorm = DateTime(date.year, date.month, date.day);

    if (dateNorm.isAfter(todayNorm)) return 'Belum'; // Masa depan

    int diminum = kepatuhanCount[key] ?? 0;

    if (diminum == 0) return 'Terlewat';
    if (diminum < targetFrekuensi) return 'Sebagian';
    return 'Teratur';
  }

  // 3. Warna berdasarkan status
  Color _getWarnaStatus(String status) {
    switch (status) {
      case 'Teratur':
        return const Color(0xFF00695C); // Hijau
      case 'Sebagian':
        return Colors.amber.shade600;   // Kuning gelap
      case 'Terlewat':
        return const Color(0xFFC62828); // Merah
      default:
        return const Color(0xFF1F2937); // Hitam (Default / Belum)
    }
  }

  // 4. Buat daftar bulan untuk PageView
  List<DateTime> _getMonthsList(DateTime start, DateTime end) {
    List<DateTime> months = [];
    DateTime current = DateTime(start.year, start.month, 1);
    DateTime endMonth = DateTime(end.year, end.month, 1);

    while (!current.isAfter(endMonth)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final obatState = ref.watch(obatProvider);
    final obat = widget.jadwal.obat;
    final logs = obatState.logKonsumsiList;

    // Persiapan Data
    final targetFrekuensi = widget.times.isNotEmpty ? widget.times.length : 1;
    final kepatuhanCount = _buildKepatuhanCount(logs);

    final tglMulai = obat.tglMulai ?? DateTime.now();
    final tglSelesai = obat.tglSelesai ?? DateTime.now().add(const Duration(days: 30));
    final monthsList = _getMonthsList(tglMulai, tglSelesai);

    // Hitung Statistik Keseluruhan & Kumpulkan Data Terlewat
    int statTotal = 0;
    int statDiminum = 0;
    int statTerlewat = 0;

    // Simpan history untuk paginasi (menggunakan class internal _MissedData)
    List<_MissedData> riwayatTidakTeratur = [];

    DateTime currentCounter = DateTime(tglMulai.year, tglMulai.month, tglMulai.day);
    final endCounter = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Looping dari tgl mulai sampai HARI INI saja untuk statistik
    while (!currentCounter.isAfter(endCounter) && !currentCounter.isAfter(tglSelesai)) {
      statTotal += targetFrekuensi; // Total pil yang DITARGETKAN

      final key = DateFormat('yyyy-MM-dd').format(currentCounter);
      final diminumHariIni = kepatuhanCount[key] ?? 0;

      statDiminum += diminumHariIni; // Pil yang DIMINUM

      final statusHariIni = _getStatusHarian(currentCounter, kepatuhanCount, targetFrekuensi);
      if (statusHariIni == 'Terlewat' || statusHariIni == 'Sebagian') {
        riwayatTidakTeratur.add(_MissedData(date: currentCounter, status: statusHariIni));
      }

      currentCounter = currentCounter.add(const Duration(days: 1));
    }

    // Total terlewat murni dari selisih target vs diminum
    statTerlewat = (statTotal - statDiminum).clamp(0, 9999);

    // Balik urutan riwayat agar yang terbaru di atas
    riwayatTidakTeratur = riwayatTidakTeratur.reversed.toList();

    // Potong data berdasarkan paginasi (10 data)
    final itemsToShow = riwayatTidakTeratur.take(_visibleMissedCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006699)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Rekap Obat", style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20, top: 18),
            child: Text(
              '${DateFormat('d MMM yyyy').format(tglMulai)} - ${DateFormat('d MMM yyyy').format(tglSelesai)}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: obatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hero Card ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFF00695C), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                        child: Icon(PhosphorIcons.pill(PhosphorIconsStyle.regular), color: const Color(0xFF00695C), size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(obat.namaObat, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            Text("${obat.dosis ?? '-'}    ${obat.frekuensi ?? '-'}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    ],
                  ),
                  if (widget.times.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: widget.times.map((t) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
                        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )).toList(),
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Statistik Boxes ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatBox(label: 'Total', value: '$statTotal', bgColor: const Color(0xFFEFEFEF), textColor: Colors.black),
                _StatBox(label: 'Diminum', value: '$statDiminum', bgColor: const Color(0xFFE0F2F1), textColor: const Color(0xFF00695C)),
                _StatBox(label: 'Terlewat', value: '$statTerlewat', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
              ],
            ),
            const SizedBox(height: 24),

            // --- Kalender Lintas Bulan (PageView) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
              ),
              child: Column(
                children: [
                  // Header Kalender dengan Navigasi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF006699)),
                        onPressed: _currentMonthIndex > 0
                            ? () {
                          _monthPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                            : null,
                      ),
                      Text(
                        monthsList.isNotEmpty ? DateFormat('MMMM yyyy', 'id').format(monthsList[_currentMonthIndex]) : '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF006699)),
                        onPressed: _currentMonthIndex < monthsList.length - 1
                            ? () {
                          _monthPageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nama Hari (Senin - Minggu)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['S', 'S', 'R', 'K', 'J', 'S', 'M']
                        .map((day) => SizedBox(
                      width: 32,
                      child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.w900))),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Slider Kalender
                  SizedBox(
                    height: 250, // Tinggi kalender
                    child: PageView.builder(
                      controller: _monthPageController,
                      itemCount: monthsList.length,
                      onPageChanged: (index) {
                        setState(() => _currentMonthIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return _buildMonthGrid(
                          monthDate: monthsList[index],
                          tglMulai: tglMulai,
                          tglSelesai: tglSelesai,
                          kepatuhanCount: kepatuhanCount,
                          targetFrekuensi: targetFrekuensi,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Legenda
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: const Color(0xFF00695C), label: 'Teratur'),
                      const SizedBox(width: 16),
                      if (targetFrekuensi > 1) ...[ // Sebagian hanya muncul jika frekuensi > 1
                        _LegendDot(color: Colors.amber.shade600, label: 'Sebagian'),
                        const SizedBox(width: 16),
                      ],
                      _LegendDot(color: const Color(0xFFC62828), label: 'Terlewat'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- Waktu Terlewat (Dengan Paginasi) ---
            if (itemsToShow.isNotEmpty) ...[
              const Align(alignment: Alignment.centerLeft, child: Text('Riwayat Tidak Teratur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              const SizedBox(height: 16),

              ...itemsToShow.map((item) => _MissedItem(data: item, times: widget.times)),

              // Tombol Tampilkan Lebih Banyak (Paginasi)
              if (riwayatTidakTeratur.length > _visibleMissedCount)
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _visibleMissedCount += 10;
                      });
                    },
                    child: const Text('Tampilkan Lebih Banyak', style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ],
        ),
      ),
    );
  }

  // --- Grid Kalender Per Bulan ---
  Widget _buildMonthGrid({
    required DateTime monthDate,
    required DateTime tglMulai,
    required DateTime tglSelesai,
    required Map<String, int> kepatuhanCount,
    required int targetFrekuensi,
  }) {
    int daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    int firstWeekdayOffset = DateTime(monthDate.year, monthDate.month, 1).weekday - 1; // 0 = Senin, 6 = Minggu

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: daysInMonth + firstWeekdayOffset,
      itemBuilder: (context, index) {
        if (index < firstWeekdayOffset) return const SizedBox.shrink(); // Kotak kosong sebelum tgl 1

        int day = index - firstWeekdayOffset + 1;
        DateTime thisDate = DateTime(monthDate.year, monthDate.month, day);

        // Cek apakah tanggal berada di luar rentang jadwal
        bool isOutsideRange = thisDate.isBefore(DateTime(tglMulai.year, tglMulai.month, tglMulai.day)) ||
            thisDate.isAfter(DateTime(tglSelesai.year, tglSelesai.month, tglSelesai.day));

        if (isOutsideRange) {
          return Center(child: Text('$day', style: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w400)));
        }

        String status = _getStatusHarian(thisDate, kepatuhanCount, targetFrekuensi);
        Color textColor = _getWarnaStatus(status);

        return Center(
          child: Text(
            '$day',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800, // Tebal
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}

// --- Data Class untuk Paginasi Riwayat ---
class _MissedData {
  final DateTime date;
  final String status;
  _MissedData({required this.date, required this.status});
}

// --- Komponen UI ---
class _StatBox extends StatelessWidget {
  final String label, value;
  final Color bgColor, textColor;
  const _StatBox({required this.label, required this.value, required this.bgColor, required this.textColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: textColor)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w500))
    ]);
  }
}

class _MissedItem extends StatelessWidget {
  final _MissedData data;
  final List<String> times;
  const _MissedItem({required this.data, required this.times});

  @override
  Widget build(BuildContext context) {
    final displayTime = times.isNotEmpty ? times.map((t) => t.replaceAll(':', '.')).join(' / ') : '--.--';
    final isSebagian = data.status == 'Sebagian';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isSebagian ? const Color(0xFFFFF9E6) : const Color(0xFFFCF8F8),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: isSebagian ? const Color(0xFFFDF6E3) : const Color(0xFFE5ECEB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIcons.pill(PhosphorIconsStyle.regular),
              color: isSebagian ? Colors.amber.shade800 : const Color(0xFF00695C), size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMMM yyyy', 'id').format(data.date),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text('$displayTime WIB', style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          Text(
            data.status,
            style: TextStyle(
                color: isSebagian ? Colors.amber.shade800 : const Color(0xFF991B1B),
                fontWeight: FontWeight.w700, fontSize: 13
            ),
          )
        ],
      ),
    );
  }
}