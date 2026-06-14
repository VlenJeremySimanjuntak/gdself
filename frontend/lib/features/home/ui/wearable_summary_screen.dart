import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

class WearableSummaryScreen extends StatefulWidget {
  final String metricType;

  const WearableSummaryScreen({super.key, required this.metricType});

  @override
  State<WearableSummaryScreen> createState() => _WearableSummaryScreenState();
}

class _WearableSummaryScreenState extends State<WearableSummaryScreen> {
  int _selectedTabIndex = 0; // 0 = 7 Hari, 1 = 31 Hari, 2 = 12 Bulan

  // 👇 Generator Data Dummy (Lebih banyak data agar grafiknya rapat seperti di gambar)
  List<double> _generateDummyData(int length) {
    final random = Random();
    List<double> data = [];
    double currentVal = 80.0;

    // Membuat pergerakan data yang lumayan natural (naik turun)
    for (int i = 0; i < length; i++) {
      double change = (random.nextDouble() * 30) - 15; // Berubah antara -15 sampai +15
      currentVal += change;
      if (currentVal < 60) currentVal = 60 + random.nextDouble() * 10;
      if (currentVal > 145) currentVal = 145 - random.nextDouble() * 10;
      data.add(currentVal);
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    // Jumlah titik data di grafik (dibuat agak banyak agar menyerupai gambar)
    int dataLength = _selectedTabIndex == 0 ? 50 : (_selectedTabIndex == 1 ? 100 : 150);
    List<double> chartData = _generateDummyData(dataLength);

    double maxVal = chartData.reduce(max);
    double minVal = chartData.reduce(min);
    double avgVal = chartData.reduce((a, b) => a + b) / chartData.length;
    double latestVal = chartData.last;

    // Jika yang dibuka bukan Detak Jantung, tampilkan UI biasa (bisa disesuaikan nanti)
    if (widget.metricType != 'Detak Jantung') {
      return Scaffold(
        appBar: AppBar(title: Text(widget.metricType)),
        body: const Center(child: Text("Halaman ini khusus fokus ke UI Detak Jantung dulu ya Mas.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ==========================================
            // BAGIAN ATAS: GRAFIK DENGAN LATAR MERAH
            // ==========================================
            Container(
              color: const Color(0xFFFF5252), // Warna merah khas detak jantung
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              child: Column(
                children: [
                  // Header & Tombol Back
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          "Detak Jantung",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.share, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TABS (7 Hari, 31 Hari, 12 Bulan) - Diubah menjadi text putih
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTopTab("7 Hari", 0),
                      _buildTopTab("31 Hari", 1),
                      _buildTopTab("12 Bulan", 2),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // AREA GRAFIK GARIS
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: LineChartPainter(data: chartData),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // BAGIAN TENGAH: STATISTIK ANGKA (Putih)
            // ==========================================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  // Nilai Terkini
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.favorite, color: Color(0xFFFF5252), size: 36),
                      const SizedBox(width: 8),
                      Text(
                        latestVal.toInt().toString(),
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, height: 1.0, color: Color(0xFF263238)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Status Pembakaran lemak\nkali/menit",
                          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 3 Kolom Statistik (Rata-rata, Min, Max)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatColumn("Rata-rata denyut\njantung", "${avgVal.toInt()}"),
                      _buildStatColumn("Denyut jantung\nterendah", "${minVal.toInt()}"),
                      _buildStatColumn("Denyut jantung\ntertinggi", "${maxVal.toInt()}"),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12), // Jarak abu-abu pemisah

            // ==========================================
            // BAGIAN BAWAH: ZONA RENTANG (Zone List)
            // ==========================================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFFFF5252), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text("Rentang denyut jantung", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                  ),

                  // List Zona Detak Jantung
                  _buildZoneItem("Status Pernapasan tenang", "(≤100kali/menit)", 88, const Color(0xFFEC407A)),
                  _buildZoneItem("Status Pengurunan tekanan", "(101~120kali/menit)", 4, const Color(0xFF29B6F6)),
                  _buildZoneItem("Status Pembakaran lemak", "(121~140kali/menit)", 7, const Color(0xFF66BB6A)),
                  _buildZoneItem("Status Kardio", "(141~160kali/menit)", 1, const Color(0xFFFFCA28)),
                  _buildZoneItem("Status Anaerobik", "(161~180kali/menit)", 0, const Color(0xFFFFA726)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk Tab di atas (7 Hari, 31 Hari, 12 Bulan)
  Widget _buildTopTab(String title, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(width: 24, height: 3, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ),
    );
  }

  // Widget untuk 3 kolom Rata-rata, Min, Max
  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            const SizedBox(width: 2),
            const Text(" kali/menit", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  // Widget untuk Baris Persentase Zona
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
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              Text("$percentage%", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                height: 4,
                // Mengatur panjang bar berdasarkan persentase
                width: percentage > 0 ? (MediaQuery.of(context).size.width - 48) * (percentage / 100) : 4,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =======================================================
// KELAS PAINTER UNTUK MENGGAMBAR GRAFIK GARIS (LINE CHART)
// =======================================================
class LineChartPainter extends CustomPainter {
  final List<double> data;

  LineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 1. Gambar Garis Putus-putus Horizontal (Grid latar belakang)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Garis untuk nilai 0, 50, 100, 150, 200 (seperti di gambar)
    List<int> yLabels = [0, 50, 100, 150, 200];
    for (int label in yLabels) {
      double yPos = size.height - ((label / 200) * size.height);

      // Gambar teks label Y
      final textPainter = TextPainter(
        text: TextSpan(text: label.toString(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(16, yPos - 14));

      // Gambar garis putus-putus
      double startX = 40;
      while (startX < size.width - 16) {
        canvas.drawLine(Offset(startX, yPos), Offset(startX + 4, yPos), gridPaint);
        startX += 8;
      }
    }

    // 2. Gambar Garis Grafik Utama (Data Detak Jantung)
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    double stepX = (size.width - 56) / (data.length - 1); // Ruang untuk X

    for (int i = 0; i < data.length; i++) {
      double x = 40 + (i * stepX);
      double y = size.height - ((data[i] / 200) * size.height); // Skala maks 200

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y); // Menghubungkan garis antar titik
      }
    }

    canvas.drawPath(path, linePaint);

    // 3. Label Waktu/X-Axis Dummy di Bawah
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