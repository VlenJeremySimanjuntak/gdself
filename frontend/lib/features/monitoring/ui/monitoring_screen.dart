import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../utils/design_system.dart';
import '../../../models/lab_data_model.dart';
import '../../../models/wearable_model.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../../utils/ai_ui_mapper.dart';
import '../../arsip/provider/arsip_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import 'input_lab_screen.dart';
import 'lab_detail_screen.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  String _selectedTab = "TSH";
  int? _visibleTooltipIndex;

  @override
  void initState() {
    super.initState();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() {
        ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
        ref.read(arsipProvider.notifier).fetchArsipData(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    final monitorState = ref.watch(monitoringProvider);
    final homeState = ref.watch(homeProvider);
    final user = ref.watch(userProvider).user;

    List<Map<String, dynamic>> currentData = monitorState.history[_selectedTab] ?? [];
    bool isEmpty = currentData.isEmpty;

    // 👇 AMBIL OBJEK HASIL RE-MAPPING AI GABUNGAN (LAB)
    final aiResult = monitorState.latestAiResult;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: monitorState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : Stack(
        children: [
          Container(
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildHeader(user?.nama ?? "User"),
                    const SizedBox(height: 30),
                    const Text(
                      "MONITOR HORMON",
                      style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2),
                    ),
                    const Text(
                      "Tren Kesehatan Anda",
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark),
                    ),
                    const SizedBox(height: 25),

                    if (!isEmpty && homeState.laporanTerbaru != null) ...[
                      // 👇 MENGIRIMKAN DATA LAB, AI GABUNGAN (LAB), DAN WEARABLE (HARIAN)
                      _buildAlertCard(homeState.laporanTerbaru, aiResult, homeState.wearableTerbaru),
                      const SizedBox(height: 24),
                    ],

                    _buildInteractiveChartCard(screenWidth, currentData),

                    const SizedBox(height: 30),

                    _buildSymptomsSection(homeState.wearableTerbaru),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          _buildFloatingAddButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(String namaUser) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset('assets/images/graves-logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text("Graves disease",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                    fontSize: 18)),
          ],
        ),
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFE3ECF7),
          child: Text(
            namaUser.isNotEmpty ? namaUser[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFF334155), fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // 👇 CARD UTAMA DIUBAH MENGIKUTI 3 MESIN STRUKTUR BE BARU
  Widget _buildAlertCard(
      LaporanLabModel? laporanTerbaru,
      HasilAIGabunganModel? aiResult,
      WearableModel? wearableTerbaru) {

    // 1. Ambil data AI Harian dari objek Wearable
    final aiHarian = (wearableTerbaru != null && wearableTerbaru.hasilAI.isNotEmpty)
        ? wearableTerbaru.hasilAI.first
        : null;

    // 2. Fallback handling skor stabilitas
    double finalScore = aiResult?.score ?? aiHarian?.score ?? 1.0;
    bool isStabil = finalScore < 2.0;

    // 3. Ambil visual data status harian dari AI Jam Tangan
    final statusHarianMap = AiUiMapper.mapStatusHarian(aiHarian?.statusHarian ?? 'NORMAL_HARIAN');

    // 4. Flag Urgensi dihapus, kita ganti menggunakan Trend Report (Mesin 3) untuk saran di bawah
    String saranBottom = aiResult?.trendReport ?? "Terus pertahankan gaya hidup sehat Anda.";

    // 5. Judul & deskripsi ramah pasien
    String rawLabelSkor = AiUiMapper.formatScoreLabel(finalScore);
    // 👇 HILANGKAN SKOR: Memotong "Skor 0.0 — Terkendali" menjadi "Terkendali" saja
    String cleanTitleStatus = rawLabelSkor.contains('—')
        ? rawLabelSkor.split('—').last.trim()
        : (isStabil ? "Terkendali" : "Perlu Perhatian");

    // Tarik Kesimpulan Lab
    String deskripsiLab = aiResult?.kesimpulanLab ??
        "Berdasarkan hasil lab tanggal ${DateFormat('dd MMMM yyyy', 'id_ID').format(laporanTerbaru?.tglPeriksa ?? DateTime.now())}, kadar hormon Anda terpantau stabil.";

    // Tarik Pesan Harian
    String pesanHarianText = aiHarian?.pesanHarian ?? "Pantauan aktivitas wearable harian berada dalam batas normal.";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isStabil ? const Color(0xFFF1F5F5).withOpacity(0.8) : const Color(0xFFFEECEB),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                  isStabil
                      ? Icons.check_circle_outline
                      : Icons.notifications_none_rounded,
                  color: isStabil ? AppColors.normalGreen : AppColors.alertRed,
                  size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusHarianMap['bgColor'],
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                  statusHarianMap['label'].toUpperCase(),
                  style: TextStyle(
                      color: statusHarianMap['color'],
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 👇 Gunakan variabel cleanTitleStatus yang sudah bersih dari tulisan skor
          Text(cleanTitleStatus,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),

          // Informasi Hasil Lab (Mesin 1)
          Text(
            deskripsiLab,
            style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),

          // Informasi Pesan Harian Wearable (Mesin 2)
          Text(
            pesanHarianText,
            style: const TextStyle(
                color: AppColors.textGrey, fontSize: 13, height: 1.5),
          ),

          const Divider(height: 24, thickness: 1, color: Colors.black12),

          // Teks Rekomendasi / Trend (Pengganti Flag Urgensi)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline,
                    size: 16, color: AppColors.primaryBlue),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  saranBottom,
                  style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveChartCard(double width, List<Map<String, dynamic>> currentData) {
    bool isEmpty = currentData.isEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 30, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Grafik Level\nHormon",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textDark,
                      height: 1.3)),
              isEmpty ? _buildWaitingBadge() : _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 20),
          _buildTabSelector(width),
          const SizedBox(height: 35),
          isEmpty
              ? _buildEmptyChartPlaceholder()
              : LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTapDown: (details) {
                  void navigateToDetail(String shortDate) {
                    try {
                      DateTime parsed = DateFormat('dd MMM yyyy', 'id_ID').parse(shortDate);
                      final arsipList = ref.read(arsipProvider).laporanList;

                      int reportIndex = arsipList.indexWhere((r) {
                        DateTime rDate = DateTime.tryParse(r['raw_date'] ?? "") ?? DateTime.now();
                        return rDate.year == parsed.year &&
                            rDate.month == parsed.month &&
                            rDate.day == parsed.day;
                      });

                      if (reportIndex != -1) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => LabDetailScreen(
                                    reportData: arsipList[reportIndex])));
                      } else {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                "Sedang menyinkronkan data, silakan coba lagi dalam beberapa detik.")));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Terjadi kesalahan saat memuat data.")));
                    }
                  }

                  if (currentData.length == 1) {
                    if (_visibleTooltipIndex == 0) {
                      navigateToDetail(currentData[0]['date']);
                    } else {
                      setState(() => _visibleTooltipIndex = 0);
                    }
                    return;
                  }

                  double width = constraints.maxWidth;
                  double localX = details.localPosition.dx;
                  int tappedIndex = (localX < width / 2) ? 0 : 1;

                  if (_visibleTooltipIndex == tappedIndex) {
                    navigateToDetail(currentData[tappedIndex]['date']);
                  } else {
                    setState(() => _visibleTooltipIndex = tappedIndex);
                  }
                },
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: HormoneChartPainter(
                      visibleIndex: _visibleTooltipIndex,
                      points: currentData,
                      paramName: _selectedTab,
                    ),
                  ),
                ),
              );
            },
          ),
          if (!isEmpty) ...[
            const SizedBox(height: 20),
            _buildXAxisLabels(currentData),
          ]
        ],
      ),
    );
  }

  Widget _buildEmptyChartPlaceholder() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [5, 4, 3, 2, 1, 0]
                    .map((y) => Row(
                  children: [
                    SizedBox(
                        width: 20,
                        child: Text("$y",
                            style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))),
                    Expanded(
                        child: Container(
                            height: 1, color: const Color(0xFFF1F5F9))),
                  ],
                ))
                    .toList(),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration:
                  BoxDecoration(color: Colors.white.withOpacity(0.9)),
                  child: const Text(
                    "Belum ada data hormon.\nTambahkan data hormon untuk\nmelihat tren.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ["JAN", "FEB", "MAR", "APR", "MEI", "JUN"]
              .map((m) => Text(m,
              style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildWaitingBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: AppColors.statusGreyBg,
        borderRadius: BorderRadius.circular(10)),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: Colors.grey),
        SizedBox(width: 6),
        Text("Menunggu Data",
            style: TextStyle(
                color: Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildStatusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: AppColors.normalGreen.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10)),
    child: const Text("Normal",
        style: TextStyle(
            color: AppColors.normalGreen,
            fontSize: 11,
            fontWeight: FontWeight.bold)),
  );

  Widget _buildTabSelector(double width) {
    return Row(
      children: ["TSH", "FT4", "FT3"].map((tab) {
        bool isSelected = _selectedTab == tab;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedTab = tab;
            _visibleTooltipIndex = null;
          }),
          child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: EdgeInsets.symmetric(horizontal: width * 0.05, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryBlue : const Color(0xFFF1F5F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(tab,
                style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildXAxisLabels(List<Map<String, dynamic>> currentData) {
    if (currentData.length == 1) {
      return Center(
        child: Text(currentData[0]['month'],
            style: const TextStyle(
                fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w800)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 45),
          child: Text(currentData[0]['month'],
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 35),
          child: Text(currentData[1]['month'],
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _buildSymptomsSection(WearableModel? wearable) {
    String hrValue = wearable != null && wearable.heartRateRHR > 0
        ? "${wearable.heartRateRHR} BPM"
        : "Terkendali";
    String sleepStatus = "Bagus";
    if (wearable != null && wearable.sleepDuration > 0) {
      final hours = wearable.sleepDuration ~/ 3600;
      sleepStatus = hours >= 7 ? "Optimal (${hours}j)" : "Kurang (${hours}j)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Gejala",
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
                child: _buildSymptomCard("Tingkat Stres", "Rendah",
                    Icons.psychology_alt_rounded, const Color(0xFFE3F4F4))),
            const SizedBox(width: 16),
            Expanded(
                child: _buildSymptomCard("Detak Jantung", hrValue,
                    Icons.favorite_border_rounded, const Color(0xFFFEECEB))),
          ],
        ),
        const SizedBox(height: 16),
        _buildSymptomCard("Kualitas Tidur", sleepStatus,
            Icons.nights_stay_outlined, const Color(0xFFE8F1F5),
            isFullWidth: true),
      ],
    );
  }

  Widget _buildSymptomCard(
      String title, String status, IconData icon, Color iconBg,
      {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textDark)),
          Text(status,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFloatingAddButton(BuildContext context) {
    return Positioned(
      bottom: 30,
      right: 24,
      child: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InputLabScreen()),
          ).then((_) {
            // 👇 INI KUNCINYA: Tarik ulang data di semua provider setelah Input Lab ditutup!
            final userId = ref.read(userProvider).user?.idUser;
            if (userId != null) {
              ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
              ref.read(homeProvider.notifier).fetchAll(userId); // Refresh data Beranda
              ref.read(arsipProvider.notifier).fetchArsipData(userId); // Refresh data Arsip
            }
          });
        },
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primaryBlue,
        elevation: 8,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text("Tambah Data Hormon",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}

class HormoneChartPainter extends CustomPainter {
  final int? visibleIndex;
  final List<Map<String, dynamic>> points;
  final String paramName;

  HormoneChartPainter(
      {this.visibleIndex, required this.points, required this.paramName});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final latestData = points.last;
    double minRujukan =
        double.tryParse(latestData['min']?.toString() ?? "0") ?? 0.0;
    double maxRujukan =
        double.tryParse(latestData['max']?.toString() ?? "0") ?? 0.0;

    if (minRujukan == 0.0 && maxRujukan == 0.0) {
      minRujukan = paramName == "TSH"
          ? 0.35
          : paramName == "FT4"
          ? 0.70
          : 1.71;
      maxRujukan = paramName == "TSH"
          ? 4.94
          : paramName == "FT4"
          ? 1.48
          : 3.71;
    }

    List<double> allValues = points
        .map((p) => double.tryParse(p['val']?.toString() ?? "0") ?? 0.0)
        .toList();
    double maxValueInChart =
    [maxRujukan, ...allValues].reduce((a, b) => a > b ? a : b);

    double chartMax = maxValueInChart + (maxValueInChart * 0.2);
    if (chartMax == 0) chartMax = 10;
    double chartMin = 0.0;

    double calculateYPos(double value) {
      return size.height -
          ((value - chartMin) / (chartMax - chartMin)) * size.height;
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    final int gridLines = 6;

    for (int i = 0; i < gridLines; i++) {
      double val = chartMax - (i * (chartMax / (gridLines - 1)));
      double yPos = calculateYPos(val);

      canvas.drawLine(Offset(25, yPos), Offset(size.width, yPos), gridPaint);

      String labelText = val.toStringAsFixed(1);
      if (labelText.endsWith(".0")) {
        labelText = labelText.substring(0, labelText.length - 2);
      }

      _drawText(canvas, Offset(0, yPos - 6), labelText, 9, Colors.grey.shade500, true);
    }

    if (points.length == 1) {
      double val1 = double.tryParse(points[0]['val']?.toString() ?? "0") ?? 0;
      final Offset point = Offset(size.width / 2, calculateYPos(val1));

      _drawPoint(canvas, point, AppColors.primaryBlue);

      if (visibleIndex == 0) {
        _drawTooltip(canvas, point, points[0], paramName, minRujukan, maxRujukan);
      }
      return;
    }

    double val1 = double.tryParse(points[0]['val']?.toString() ?? "0") ?? 0;
    double val2 = double.tryParse(points[1]['val']?.toString() ?? "0") ?? 0;

    final Offset prevPoint = Offset(size.width * 0.25 + 10, calculateYPos(val1));
    final Offset latestPoint = Offset(size.width * 0.85, calculateYPos(val2));

    final paintLine = Paint()
      ..color = AppColors.primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(prevPoint.dx, prevPoint.dy);

    double controlPointX1 = prevPoint.dx + (latestPoint.dx - prevPoint.dx) / 2;
    double controlPointX2 = latestPoint.dx - (latestPoint.dx - prevPoint.dx) / 2;

    path.cubicTo(controlPointX1, prevPoint.dy, controlPointX2, latestPoint.dy,
        latestPoint.dx, latestPoint.dy);
    canvas.drawPath(path, paintLine);

    _drawPoint(canvas, prevPoint, AppColors.primaryBlue);

    _drawPoint(
        canvas,
        latestPoint,
        val2 > maxRujukan || val2 < minRujukan
            ? AppColors.alertRed
            : AppColors.primaryBlue);

    if (visibleIndex == 0) {
      _drawTooltip(canvas, prevPoint, points[0], paramName, minRujukan, maxRujukan);
    }
    if (visibleIndex == 1) {
      _drawTooltip(canvas, latestPoint, points[1], paramName, minRujukan, maxRujukan);
    }
  }

  void _drawPoint(Canvas canvas, Offset offset, Color color) {
    canvas.drawCircle(offset, 7, Paint()..color = color);
    canvas.drawCircle(offset, 3, Paint()..color = Colors.white);
  }

  void _drawTooltip(Canvas canvas, Offset anchor, Map<String, dynamic> data,
      String paramName, double min, double max) {
    double val = double.tryParse(data['val']?.toString() ?? "0") ?? 0;
    String status = "Normal";
    Color statusColor = AppColors.normalGreen;

    if (val < min) {
      status = "Rendah";
      statusColor = Colors.orange;
    } else if (val > max) {
      status = "Tinggi";
      statusColor = AppColors.alertRed;
    }

    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(anchor.dx - 85, anchor.dy - 100, 170, 80),
        const Radius.circular(12));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF2C3E50));

    _drawText(canvas, Offset(anchor.dx - 70, anchor.dy - 90),
        data['date'] ?? "", 13, Colors.white, true);
    _drawText(canvas, Offset(anchor.dx - 70, anchor.dy - 68),
        "$paramName Level: ", 11, Colors.grey.shade400, false);
    _drawText(canvas, Offset(anchor.dx - 5, anchor.dy - 68),
        "${data['val']} ${data['unit']}", 12, Colors.white, true);
    _drawText(canvas, Offset(anchor.dx - 70, anchor.dy - 48), status, 12,
        statusColor, true);
  }

  void _drawText(Canvas canvas, Offset offset, String text, double fontSize,
      Color color, bool isBold) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}