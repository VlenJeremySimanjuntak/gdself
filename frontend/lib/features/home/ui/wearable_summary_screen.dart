import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

// ✅ Mengambil AppColors langsung dari design_system.dart
import '../../../utils/design_system.dart';

class WearableSummaryScreen extends StatefulWidget {
  final String metricType;

  const WearableSummaryScreen({super.key, required this.metricType});

  @override
  State<WearableSummaryScreen> createState() => _WearableSummaryScreenState();
}

class _WearableSummaryScreenState extends State<WearableSummaryScreen> {
  int _selectedTabIndex = 0; // 0 = 7 Hari/Hari, 1 = 31 Hari/Minggu, 2 = 12 Bulan/Bulan

  // ==========================================
  // DATA DUMMY DETAK JANTUNG
  // ==========================================
  List<double> _generateHeartDummyData(int length) {
    final random = Random();
    List<double> data = [];
    double currentVal = 80.0;
    for (int i = 0; i < length; i++) {
      double change = (random.nextDouble() * 30) - 15;
      currentVal += change;
      if (currentVal < 60) currentVal = 60 + random.nextDouble() * 10;
      if (currentVal > 145) currentVal = 145 - random.nextDouble() * 10;
      data.add(currentVal);
    }
    return data;
  }

  // ==========================================
  // DATA DUMMY TIDUR
  // ==========================================
  List<SleepSegment> _generateSleepDummyData() {
    return [
      SleepSegment(start: 0.00, end: 0.10, type: SleepType.light),
      SleepSegment(start: 0.10, end: 0.12, type: SleepType.awake),
      SleepSegment(start: 0.12, end: 0.25, type: SleepType.deep),
      SleepSegment(start: 0.25, end: 0.40, type: SleepType.light),
      SleepSegment(start: 0.40, end: 0.55, type: SleepType.deep),
      SleepSegment(start: 0.55, end: 0.65, type: SleepType.light),
      SleepSegment(start: 0.65, end: 0.70, type: SleepType.rem),
      SleepSegment(start: 0.70, end: 0.85, type: SleepType.deep),
      SleepSegment(start: 0.85, end: 0.90, type: SleepType.light),
      SleepSegment(start: 0.90, end: 0.92, type: SleepType.awake),
      SleepSegment(start: 0.92, end: 1.00, type: SleepType.light),
    ];
  }

  // ==========================================
  // DATA DUMMY TEKANAN DARAH (Sistolik & Diastolik)
  // ==========================================
  List<Map<String, double>> _generateBpDummyData(int length) {
    final random = Random();
    List<Map<String, double>> data = [];
    double sys = 115.0; // Sistolik awal
    double dia = 75.0;  // Diastolik awal
    for (int i = 0; i < length; i++) {
      sys += (random.nextDouble() * 10) - 5;
      dia += (random.nextDouble() * 6) - 3;
      if (sys < 90) sys = 90 + random.nextDouble() * 5;
      if (sys > 150) sys = 150 - random.nextDouble() * 5;
      if (dia < 60) dia = 60 + random.nextDouble() * 5;
      if (dia > 100) dia = 100 - random.nextDouble() * 5;
      data.add({'sys': sys, 'dia': dia});
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    // Router internal untuk menampilkan UI berdasarkan metricType
    final metric = widget.metricType.toLowerCase();
    if (metric == 'tidur') {
      return _buildSleepSummary();
    } else if (metric == 'tekanan darah') {
      return _buildBloodPressureSummary();
    } else {
      return _buildHeartRateSummary();
    }
  }

  // =========================================================================
  // 1. UI REKAP TIDUR
  // =========================================================================
  Widget _buildSleepSummary() {
    final sleepSegments = _generateSleepDummyData();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                        const Text("Tidur", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          children: const [
                            Icon(Icons.share, color: Colors.white, size: 20),
                            SizedBox(width: 16),
                            Icon(Icons.calendar_today, color: Colors.white, size: 20),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
                    child: Row(
                      children: [
                        _buildPillTab("Hari", 0),
                        _buildPillTab("Minggu", 1),
                        _buildPillTab("Bulan", 2),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.chevron_left, color: Colors.white, size: 16)),
                      const SizedBox(width: 16),
                      const Text("5 Mar 2026", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.chevron_right, color: Colors.white, size: 16)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: CustomPaint(painter: SleepChartPainter(segments: sleepSegments)),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: const [
                      Text("6", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text(" jam ", style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                      Text("32", style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text(" menit", style: TextStyle(fontSize: 16, color: AppColors.textGrey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Expanded(flex: 46, child: Container(color: AppColors.primaryBlue)),
                          Expanded(flex: 38, child: Container(color: AppColors.activeNavBg)),
                          Expanded(flex: 15, child: Container(color: AppColors.alertRed)),
                          Expanded(flex: 1, child: Container(color: AppColors.errorRed)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSleepDetailItem(AppColors.primaryBlue, "Tidur nyenyak", "3 jam 0 menit"),
                      _buildSleepDetailItem(AppColors.activeNavBg, "Tidur ringan", "2 jam 28 menit"),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSleepDetailItem(AppColors.alertRed, "Gerakan mata cepat", "1 jam 0 menit"),
                      _buildSleepDetailItem(AppColors.errorRed, "Bangun", "4 Menit"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: Text("Analisis kualitas tidur", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                  const SizedBox(height: 24),
                  _buildAnalysisItem(Icons.nightlight_round, AppColors.primaryBlue, "Tidur terlalu malam", "Waktu terbaik untuk tidur merupakan sebelum jam 22.00, begadang kelamaan mungkin menurunkan kekebalan tubuh dan mempercepat penuaan."),
                  const SizedBox(height: 16),
                  _buildAnalysisItem(Icons.battery_alert, AppColors.primaryBlue, "Kurang tidur", "Total waktu terbaik untuk tidur merupakan 7 sampai 9 jam, kurang tidur mungkin menurunkan kekebalan tubuh dan memperlambat mampu bereaksi."),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. UI REKAP DETAK JANTUNG
  // =========================================================================
  Widget _buildHeartRateSummary() {
    int dataLength = _selectedTabIndex == 0 ? 50 : (_selectedTabIndex == 1 ? 100 : 150);
    List<double> chartData = _generateHeartDummyData(dataLength);

    double maxVal = chartData.reduce(max);
    double minVal = chartData.reduce(min);
    double avgVal = chartData.reduce((a, b) => a + b) / chartData.length;
    double latestVal = chartData.last;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                        const Text("Detak Jantung", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Icon(Icons.share, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopLineTab("7 Hari", 0),
                      _buildTopLineTab("31 Hari", 1),
                      _buildTopLineTab("12 Bulan", 2),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(painter: HeartLineChartPainter(data: chartData)),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.favorite, color: AppColors.alertRed, size: 36),
                      const SizedBox(width: 8),
                      Text(latestVal.toInt().toString(), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, height: 1.0, color: AppColors.textDark)),
                      const SizedBox(width: 12),
                      const Expanded(child: Text("Status Normal\nkali/menit", style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.3))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn("Rata-rata", "${avgVal.toInt()}"),
                      _buildStatColumn("Terendah", "${minVal.toInt()}"),
                      _buildStatColumn("Tertinggi", "${maxVal.toInt()}"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Rentang denyut jantung", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.statusGreyBg)),
                  _buildZoneItem("Rendah", "(< 60 kali/menit)", 10, const Color(0xFF64B5F6)),
                  _buildZoneItem("Normal", "(60 - 100 kali/menit)", 85, AppColors.normalGreen),
                  _buildZoneItem("Tinggi", "(> 100 kali/menit)", 5, AppColors.alertRed),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. UI REKAP TEKANAN DARAH
  // =========================================================================
  Widget _buildBloodPressureSummary() {
    int dataLength = _selectedTabIndex == 0 ? 50 : (_selectedTabIndex == 1 ? 100 : 150);
    List<Map<String, double>> chartData = _generateBpDummyData(dataLength);

    double latestSys = chartData.last['sys']!;
    double latestDia = chartData.last['dia']!;

    double avgSys = chartData.map((e) => e['sys']!).reduce((a, b) => a + b) / chartData.length;
    double avgDia = chartData.map((e) => e['dia']!).reduce((a, b) => a + b) / chartData.length;

    String status = (latestSys < 120 && latestDia < 80) ? "Normal" : "Tinggi";
    Color statusColor = status == "Normal" ? AppColors.normalGreen : AppColors.alertRed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- BAGIAN ATAS ---
            Container(
              color: AppColors.primaryBlue,
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
                        const Text("Tekanan Darah", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const Icon(Icons.share, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopLineTab("7 Hari", 0),
                      _buildTopLineTab("31 Hari", 1),
                      _buildTopLineTab("12 Bulan", 2),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Grafik 2 Garis (Sistolik & Diastolik)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(painter: BloodPressureChartPainter(data: chartData)),
                  ),

                  // Legenda Garis
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 12, height: 3, color: Colors.white),
                      const SizedBox(width: 6),
                      const Text("Sistolik", style: TextStyle(color: Colors.white, fontSize: 12)),
                      const SizedBox(width: 20),
                      Container(width: 12, height: 3, color: AppColors.activeNavBg),
                      const SizedBox(width: 6),
                      const Text("Diastolik", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),

            // --- BAGIAN TENGAH ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(Icons.water_drop, color: statusColor, size: 36),
                      const SizedBox(width: 8),
                      Text("${latestSys.toInt()}/${latestDia.toInt()}", style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, height: 1.0, color: AppColors.textDark)),
                      const SizedBox(width: 12),
                      Expanded(child: Text("Status $status\nmmHg", style: const TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.3))),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn("Rata-rata Sistolik", "${avgSys.toInt()}"),
                      _buildStatColumn("Rata-rata Diastolik", "${avgDia.toInt()}"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- BAGIAN BAWAH: ZONA & ANALISIS ---
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assessment, color: AppColors.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text("Kategori Tekanan Darah", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: AppColors.statusGreyBg)),
                  _buildZoneItem("Normal", "(< 120 / < 80 mmHg)", status == "Normal" ? 100 : 0, AppColors.normalGreen),
                  _buildZoneItem("Tinggi", "(≥ 120 / ≥ 80 mmHg)", status == "Tinggi" ? 100 : 0, AppColors.alertRed),

                  const SizedBox(height: 24),
                  _buildAnalysisItem(
                      Icons.info_outline,
                      AppColors.primaryBlue,
                      "Informasi Medis",
                      "Sistolik mengukur tekanan di pembuluh darah saat jantung berdetak. Diastolik mengukur tekanan di pembuluh darah saat jantung beristirahat di antara detak."
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // COMPONENT HELPERS
  // ==========================================
  Widget _buildTopLineTab(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
            const SizedBox(height: 4),
            if (isSelected) Container(width: 24, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ),
    );
  }

  Widget _buildPillTab(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.primaryBlue : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.4)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildZoneItem(String title, String subtitle, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(height: 4, width: double.infinity, decoration: BoxDecoration(color: AppColors.statusGreyBg, borderRadius: BorderRadius.circular(2))),
              Container(height: 4, width: percentage > 0 ? (MediaQuery.of(context).size.width - 48) * (percentage / 100) : 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepDetailItem(Color color, String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey), overflow: TextOverflow.ellipsis)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(IconData icon, Color iconColor, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: AppColors.textGrey, fontSize: 12, height: 1.4)),
            ],
          ),
        )
      ],
    );
  }
}

// =======================================================
// PAINTER GRAFIK TEKANAN DARAH (2 GARIS)
// =======================================================
class BloodPressureChartPainter extends CustomPainter {
  final List<Map<String, double>> data;
  BloodPressureChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Skala Y untuk Tekanan Darah (40 - 160)
    List<int> yLabels = [40, 80, 120, 160];
    for (int label in yLabels) {
      double yPos = size.height - (((label - 40) / 120) * size.height);
      final textPainter = TextPainter(text: TextSpan(text: label.toString(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(16, yPos - 6));

      double startX = 40;
      while (startX < size.width - 16) {
        canvas.drawLine(Offset(startX, yPos), Offset(startX + 4, yPos), gridPaint);
        startX += 8;
      }
    }

    final sysLinePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final diaLinePaint = Paint()
      ..color = AppColors.activeNavBg
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final sysPath = Path();
    final diaPath = Path();
    double stepX = (size.width - 56) / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double sysY = size.height - (((data[i]['sys']! - 40) / 120) * size.height);
      double diaY = size.height - (((data[i]['dia']! - 40) / 120) * size.height);

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

    final xTextPainter1 = TextPainter(text: const TextSpan(text: "07:20", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
    final xTextPainter2 = TextPainter(text: const TextSpan(text: "13:45", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
    final xTextPainter3 = TextPainter(text: const TextSpan(text: "20:10", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();

    xTextPainter1.paint(canvas, Offset(40, size.height + 8));
    xTextPainter2.paint(canvas, Offset((size.width / 2) - 10, size.height + 8));
    xTextPainter3.paint(canvas, Offset(size.width - 40, size.height + 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =======================================================
// PAINTER GRAFIK DETAK JANTUNG (GARIS)
// =======================================================
class HeartLineChartPainter extends CustomPainter {
  final List<double> data;
  HeartLineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    List<int> yLabels = [0, 50, 100, 150, 200];
    for (int label in yLabels) {
      double yPos = size.height - ((label / 200) * size.height);
      final textPainter = TextPainter(text: TextSpan(text: label.toString(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
      textPainter.paint(canvas, Offset(16, yPos - 14));

      double startX = 40;
      while (startX < size.width - 16) {
        canvas.drawLine(Offset(startX, yPos), Offset(startX + 4, yPos), gridPaint);
        startX += 8;
      }
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double stepX = (size.width - 56) / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double y = size.height - ((data[i] / 200) * size.height);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    final xTextPainter1 = TextPainter(text: const TextSpan(text: "07:20", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
    final xTextPainter2 = TextPainter(text: const TextSpan(text: "13:45", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();
    final xTextPainter3 = TextPainter(text: const TextSpan(text: "20:10", style: TextStyle(color: Colors.white70, fontSize: 10)), textDirection: ui.TextDirection.ltr)..layout();

    xTextPainter1.paint(canvas, Offset(40, size.height + 8));
    xTextPainter2.paint(canvas, Offset((size.width / 2) - 10, size.height + 8));
    xTextPainter3.paint(canvas, Offset(size.width - 40, size.height + 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// =======================================================
// PAINTER GRAFIK TIDUR (KOTAK-KOTAK)
// =======================================================
enum SleepType { deep, light, rem, awake }

class SleepSegment {
  final double start;
  final double end;
  final SleepType type;
  SleepSegment({required this.start, required this.end, required this.type});
}

class SleepChartPainter extends CustomPainter {
  final List<SleepSegment> segments;
  SleepChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height - 30;
    final double startX = 30;
    final double endX = size.width - 30;
    final double width = endX - startX;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, chartHeight), Offset(endX, chartHeight), gridPaint);
    canvas.drawLine(Offset(startX, chartHeight * 0.5), Offset(endX, chartHeight * 0.5), gridPaint);

    for (var seg in segments) {
      Color color;
      double topY;

      switch (seg.type) {
        case SleepType.deep:
          color = AppColors.primaryBlue;
          topY = chartHeight * 0.6;
          break;
        case SleepType.light:
          color = AppColors.activeNavBg;
          topY = chartHeight * 0.3;
          break;
        case SleepType.rem:
          color = AppColors.alertRed;
          topY = chartHeight * 0.1;
          break;
        case SleepType.awake:
          color = AppColors.errorRed;
          topY = 0;
          break;
      }

      final rect = Rect.fromLTRB(
        startX + (seg.start * width),
        topY,
        startX + (seg.end * width),
        chartHeight,
      );

      final paint = Paint()..color = color;
      canvas.drawRect(rect, paint);
    }

    _drawText(canvas, "22:00", Offset(startX - 10, chartHeight + 10));
    _drawText(canvas, "0:00", Offset(startX + (width * 0.25) - 10, chartHeight + 10));
    _drawText(canvas, "2:00", Offset(startX + (width * 0.5) - 10, chartHeight + 10));
    _drawText(canvas, "4:00", Offset(startX + (width * 0.75) - 10, chartHeight + 10));
    _drawText(canvas, "6:00", Offset(endX - 10, chartHeight + 10));
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}