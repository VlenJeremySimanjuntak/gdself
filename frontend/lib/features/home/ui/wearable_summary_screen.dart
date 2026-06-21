import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'dart:ui' as ui;

import '../../../utils/design_system.dart';
import '../../home/providers/wearable_provider.dart';
import '../../../models/wearable_model.dart';

class WearableSummaryScreen extends ConsumerStatefulWidget {
  final String metricType;
  final int userId;

  const WearableSummaryScreen({
    super.key,
    required this.metricType,
    required this.userId,
  });

  @override
  ConsumerState<WearableSummaryScreen> createState() => _WearableSummaryScreenState();
}

class _WearableSummaryScreenState extends ConsumerState<WearableSummaryScreen> {
  // ✅ Variabel untuk melacak tab yang dipilih (0: Hari, 1: Minggu, 2: Bulan)
  int _selectedTabIndex = 0;

  // ✅ Variabel untuk navigasi tanggal
  late DateTime _currentDate;
  late DateTime _todayDate;

  @override
  void initState() {
    super.initState();

    // ✅ Inisialisasi tanggal
    _todayDate = DateTime.now();
    _todayDate = DateTime(_todayDate.year, _todayDate.month, _todayDate.day);
    _currentDate = _todayDate;

    Future.microtask(() => ref.read(wearableProvider.notifier).fetchWearableData(widget.userId));
  }

  // ✅ Fungsi untuk mendapatkan rentang tanggal berdasarkan tab dan currentDate
  Map<String, DateTime> _getDateRange() {
    DateTime startDate;
    DateTime endDate;

    if (_selectedTabIndex == 0) {
      // Mode Harian: 1 hari saja
      startDate = _currentDate;
      endDate = _currentDate.add(const Duration(days: 1)); // Sampai akhir hari
    } else if (_selectedTabIndex == 1) {
      // Mode Mingguan: 7 hari ke belakang dari currentDate
      startDate = _currentDate.subtract(const Duration(days: 6));
      endDate = _currentDate.add(const Duration(days: 1)); // Sampai akhir hari
    } else {
      // Mode Bulanan: 30 hari ke belakang dari currentDate
      startDate = _currentDate.subtract(const Duration(days: 29));
      endDate = _currentDate.add(const Duration(days: 1)); // Sampai akhir hari
    }

    return {
      'start': startDate,
      'end': endDate,
    };
  }

  // ✅ Fungsi untuk filter data berdasarkan rentang tanggal
  List<WearableModel> _filterDataByDateRange(List<WearableModel> allData) {
    final dateRange = _getDateRange();
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    return allData.where((w) {
      if (w.tglData == null) return false;

      // Konversi tglData ke DateTime (hanya tanggal, abaikan waktu)
      final dataDate = DateTime(w.tglData!.year, w.tglData!.month, w.tglData!.day);

      // Cek apakah data dalam rentang
      return (dataDate.isAfter(startDate.subtract(const Duration(days: 1))) ||
          dataDate.isAtSameMomentAs(startDate)) &&
          dataDate.isBefore(endDate);
    }).toList();
  }

  // ✅ Fungsi untuk navigasi tanggal
  void _goToPreviousDate() {
    setState(() {
      if (_selectedTabIndex == 0) {
        _currentDate = _currentDate.subtract(const Duration(days: 1));
      } else if (_selectedTabIndex == 1) {
        _currentDate = _currentDate.subtract(const Duration(days: 7));
      } else if (_selectedTabIndex == 2) {
        _currentDate = _currentDate.subtract(const Duration(days: 30));
      }
    });
  }

  void _goToNextDate() {
    DateTime newDate;
    if (_selectedTabIndex == 0) {
      newDate = _currentDate.add(const Duration(days: 1));
    } else if (_selectedTabIndex == 1) {
      newDate = _currentDate.add(const Duration(days: 7));
    } else {
      newDate = _currentDate.add(const Duration(days: 30));
    }

    // Cegah melewati tanggal hari ini
    if (newDate.isAfter(_todayDate)) return;

    setState(() {
      _currentDate = newDate;
    });
  }

  // ✅ Format tanggal untuk label
  String _formatDate(DateTime? date) {
    if (date == null) return "Hari ini";
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return "${date.day} ${months[date.month - 1]} (${days[date.weekday - 1]})";
  }

  // ✅ Fungsi untuk mendapatkan label tanggal sesuai mode
  String _getDateLabel() {
    final dateRange = _getDateRange();
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!.subtract(const Duration(days: 1));

    if (_selectedTabIndex == 0) {
      return _formatDate(_currentDate);
    } else {
      return "${_formatDate(startDate)} - ${_formatDate(endDate)}";
    }
  }

  // ✅ Cek apakah tombol next bisa ditekan
  bool get _canGoNext {
    if (_selectedTabIndex == 0) {
      return _currentDate.isBefore(_todayDate);
    } else {
      return _currentDate.isBefore(_todayDate);
    }
  }

  bool _hasValidData(List<WearableModel> data) {
    if (data.isEmpty) return false;
    return data.any((w) => w.heartRateRHR > 0 || w.sleepDuration > 0 || w.sistolik > 0 || w.diastolik > 0);
  }

  @override
  Widget build(BuildContext context) {
    final wearableState = ref.watch(wearableProvider);
    final metric = widget.metricType.toLowerCase();

    if (wearableState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }

    if (wearableState.errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        ),
        body: Center(child: Text(wearableState.errorMessage!, style: const TextStyle(color: AppColors.textGrey))),
      );
    }

    final allData = wearableState.wearableData ?? [];

    // ✅ Filter data berdasarkan rentang tanggal yang dipilih
    final filteredData = _filterDataByDateRange(allData);

    if (filteredData.isEmpty || !_hasValidData(filteredData)) {
      return _buildEmptyDataScreen(metric);
    }

    if (metric == 'tidur') return _buildSleepSummary(filteredData);
    if (metric == 'tekanan darah') return _buildBloodPressureSummary(filteredData);
    return _buildHeartRateSummary(filteredData);
  }

  // ==========================================
  // 1. UI REKAP DETAK JANTUNG
  // ==========================================
  Widget _buildHeartRateSummary(List<WearableModel> data) {
    // ✅ Urutkan data berdasarkan tanggal (terlama ke terbaru untuk grafik)
    data.sort((a, b) {
      if (a.tglData == null || b.tglData == null) return 0;
      return a.tglData!.compareTo(b.tglData!);
    });

    final validData = data.where((w) => w.heartRateRHR > 0).toList();
    if (validData.isEmpty) return _buildEmptyDataScreen('detak jantung');

    // Data untuk grafik (urutan dari terlama ke terbaru)
    final chartData = validData.map((w) => w.heartRateRHR.toDouble()).toList();

    // Data terbaru untuk tampilan
    final latestData = validData.last; // ✅ Ambil data terakhir (terbaru)
    final double latestVal = latestData.heartRateRHR.toDouble();
    final double maxVal = chartData.reduce(max);
    final double minVal = chartData.reduce(min);
    final double avgVal = chartData.reduce((a, b) => a + b) / chartData.length;

    String updateTime = latestData.waktuData?.substring(0, 5) ?? "--:--";
    if (updateTime == "null:null") updateTime = "--:--";

    return _buildBaseScreen(
      title: "Jantung",
      dateLabel: _getDateLabel(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("${minVal.toInt()}-${maxVal.toInt()}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const Text(" bpm", style: TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text("Rentang denyut jantung", style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("${latestVal.toInt()}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      const Text(" bpm", style: TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Terakhir diperbarui $updateTime", style: const TextStyle(fontSize: 13, color: AppColors.textGrey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: CustomPaint(painter: HeartLineChartPainter(data: chartData)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: AppColors.alertRed, size: 20),
                const SizedBox(width: 8),
                Text("Rata-rata: ${avgVal.toInt()} bpm", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // 2. UI REKAP TIDUR
  // ==========================================
  Widget _buildSleepSummary(List<WearableModel> data) {
    // ✅ Urutkan data berdasarkan tanggal
    data.sort((a, b) {
      if (a.tglData == null || b.tglData == null) return 0;
      return a.tglData!.compareTo(b.tglData!);
    });

    final validData = data.where((w) => w.sleepDuration > 0).toList();
    if (validData.isEmpty) return _buildEmptyDataScreen('tidur');

    // ✅ Hitung rata-rata atau total sesuai mode
    int totalMinutes;
    if (_selectedTabIndex == 0) {
      // Mode Harian: tampilkan data terbaru
      totalMinutes = validData.last.sleepDuration;
    } else {
      // Mode Mingguan/Bulanan: hitung rata-rata
      totalMinutes = (validData.map((w) => w.sleepDuration).reduce((a, b) => a + b) / validData.length).round();
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    return _buildBaseScreen(
      title: "Tidur",
      dateLabel: _getDateLabel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _selectedTabIndex == 0 ? "Total Waktu Tidur" : "Rata-rata Waktu Tidur",
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$hours", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text(" j ", style: TextStyle(fontSize: 18, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
              Text("$minutes", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text(" m", style: TextStyle(fontSize: 18, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            height: 200,
            width: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F0FA),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                FractionallySizedBox(
                  heightFactor: (totalMinutes / 480).clamp(0.1, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            totalMinutes >= 420 ? "Tidur Anda sudah cukup optimal." : "Waktu tidur Anda kurang dari anjuran.",
            style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
          )
        ],
      ),
    );
  }

  // ==========================================
  // 3. UI REKAP TEKANAN DARAH
  // ==========================================
  Widget _buildBloodPressureSummary(List<WearableModel> data) {
    // ✅ Urutkan data berdasarkan tanggal
    data.sort((a, b) {
      if (a.tglData == null || b.tglData == null) return 0;
      return a.tglData!.compareTo(b.tglData!);
    });

    final validData = data.where((w) => w.sistolik > 0 && w.diastolik > 0).toList();
    if (validData.isEmpty) return _buildEmptyDataScreen('tekanan darah');

    // Data untuk grafik (urutan dari terlama ke terbaru)
    final chartData = validData.map((w) => {
      'sys': w.sistolik.toDouble(),
      'dia': w.diastolik.toDouble()
    }).toList();

    // Data terbaru untuk tampilan
    final latestData = validData.last; // ✅ Ambil data terakhir (terbaru)
    double latestSys = latestData.sistolik.toDouble();
    double latestDia = latestData.diastolik.toDouble();

    double avgSys = chartData.map((e) => e['sys']!).reduce((a, b) => a + b) / chartData.length;
    double avgDia = chartData.map((e) => e['dia']!).reduce((a, b) => a + b) / chartData.length;

    String updateTime = latestData.waktuData?.substring(0, 5) ?? "--:--";

    return _buildBaseScreen(
      title: "Tekanan Darah",
      dateLabel: _getDateLabel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tekanan darah", style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("${latestSys.toInt()}/${latestDia.toInt()}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text(" mmHg", style: TextStyle(fontSize: 14, color: AppColors.textGrey, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text("Terakhir diperbarui $updateTime", style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),

          const SizedBox(height: 32),

          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: CustomPaint(painter: BloodPressureChartPainter(data: chartData)),
          ),

          const SizedBox(height: 12),

          // Legenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("● ", style: TextStyle(color: Color(0xFFE5A93D), fontSize: 14)),
              const Text("Sistolik", style: TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 24),
              const Text("● ", style: TextStyle(color: AppColors.primaryBlue, fontSize: 14)),
              const Text("Diastolik", style: TextStyle(color: AppColors.textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),

          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _selectedTabIndex == 0 ? "Tekanan darah saat ini" : "Tekanan darah rata-rata",
                  style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text("${avgSys.toInt()}/${avgDia.toInt()}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                    const Text(" mmHg", style: TextStyle(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET PEMBUNGKUS LAYAR (HEADER & TABS)
  // ==========================================
  Widget _buildBaseScreen({required String title, required String dateLabel, required Widget child}) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: Text(title, style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.more_vert, color: AppColors.textDark))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Tab interaktif
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  _buildInteractiveTab(0, "Hari"),
                  _buildInteractiveTab(1, "Minggu"),
                  _buildInteractiveTab(2, "Bulan"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Navigasi tanggal dengan tombol interaktif
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tombol Previous
                GestureDetector(
                  onTap: _goToPreviousDate,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.chevron_left, color: AppColors.textDark, size: 20),
                  ),
                ),
                const SizedBox(width: 16),

                // Label Tanggal
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(width: 16),

                // Tombol Next
                GestureDetector(
                  onTap: _canGoNext ? _goToNextDate : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _canGoNext ? const Color(0xFFF0F2F5) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: _canGoNext ? AppColors.textDark : Colors.grey.shade400,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    );
  }

  // Helper untuk membuat tab yang bisa ditekan
  Widget _buildInteractiveTab(int index, String title) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
            // Reset ke tanggal hari ini saat ganti tab
            _currentDate = _todayDate;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.textDark : AppColors.textGrey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LAYAR DATA KOSONG
  // ==========================================
  Widget _buildEmptyDataScreen(String metric) {
    String title;
    IconData icon;

    if (metric == 'tidur') {
      title = 'Belum Ada Data Tidur';
      icon = Icons.nightlight_round;
    } else if (metric == 'tekanan darah') {
      title = 'Belum Ada Data Tekanan Darah';
      icon = Icons.water_drop;
    } else {
      title = 'Belum Ada Data Detak Jantung';
      icon = Icons.favorite;
    }

    // ✅ Tampilkan informasi rentang tanggal yang dipilih
    String dateInfo = _getDateLabel();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // ✅ Tambahkan navigasi tab dan tanggal di halaman kosong
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Tab interaktif
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    children: [
                      _buildInteractiveTab(0, "Hari"),
                      _buildInteractiveTab(1, "Minggu"),
                      _buildInteractiveTab(2, "Bulan"),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Navigasi tanggal
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _goToPreviousDate,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chevron_left, color: AppColors.textDark, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      dateInfo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _canGoNext ? _goToNextDate : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _canGoNext ? const Color(0xFFF0F2F5) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: _canGoNext ? AppColors.textDark : Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Konten kosong di tengah
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 24),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 12),
                    const Text(
                      'Data aktivitas belum tersedia untuk rentang tanggal ini.\nCoba pilih tanggal lain atau pastikan jam tangan Anda telah terhubung.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.5),
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
}

// =======================================================
// PAINTER GRAFIK
// =======================================================
class HeartLineChartPainter extends CustomPainter {
  final List<double> data;
  HeartLineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()..color = Colors.grey.shade200..strokeWidth = 1..style = PaintingStyle.stroke;
    for (int label in [0, 50, 100, 150, 200]) {
      double yPos = size.height - ((label / 200) * size.height);

      final textPainter = TextPainter(
          text: TextSpan(text: label.toString(), style: const TextStyle(color: AppColors.textGrey, fontSize: 10)),
          textDirection: ui.TextDirection.ltr
      )..layout();
      textPainter.paint(canvas, Offset(8, yPos - 6));

      canvas.drawLine(Offset(32, yPos), Offset(size.width, yPos), gridPaint);
    }

    final linePaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double stepX = (size.width - 40) / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double y = size.height - ((data[i] / 200) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // ✅ Tambahkan titik pada setiap data point
    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double y = size.height - ((data[i] / 200) * size.height);
      canvas.drawCircle(
          Offset(x, y),
          4,
          Paint()..color = AppColors.primaryBlue
      );
    }
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BloodPressureChartPainter extends CustomPainter {
  final List<Map<String, double>> data;
  BloodPressureChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()..color = Colors.grey.shade200..strokeWidth = 1..style = PaintingStyle.stroke;
    for (int label in [40, 80, 120, 160]) {
      double yPos = size.height - (((label - 40) / 120) * size.height);
      final textPainter = TextPainter(
          text: TextSpan(text: label.toString(), style: const TextStyle(color: AppColors.textGrey, fontSize: 10)),
          textDirection: ui.TextDirection.ltr
      )..layout();
      textPainter.paint(canvas, Offset(8, yPos - 6));
      canvas.drawLine(Offset(32, yPos), Offset(size.width, yPos), gridPaint);
    }

    final sysLinePaint = Paint()
      ..color = const Color(0xFFE5A93D)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final diaLinePaint = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final sysPath = Path();
    final diaPath = Path();
    double stepX = (size.width - 40) / (data.length > 1 ? data.length - 1 : 1);

    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double sysY = size.height - (((data[i]['sys']! - 40) / 120) * size.height);
      double diaY = size.height - (((data[i]['dia']! - 40) / 120) * size.height);

      canvas.drawCircle(Offset(x, sysY), 4, Paint()..color = const Color(0xFFE5A93D));
      canvas.drawCircle(Offset(x, diaY), 4, Paint()..color = AppColors.primaryBlue);

      if (i == 0) {
        sysPath.moveTo(x, sysY);
        diaPath.moveTo(x, diaY);
      } else {
        sysPath.lineTo(x, sysY);
        diaPath.lineTo(x, diaY);
      }
    }

    canvas.drawPath(sysPath, sysLinePaint);
    canvas.drawPath(diaPath, diaLinePaint);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}