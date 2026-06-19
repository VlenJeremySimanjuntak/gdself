import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

import '../../monitoring/ui/edit_lab_screen.dart';
import '../provider/riwayat_provider.dart';

class RiwayatHormonDetailScreen extends ConsumerStatefulWidget {
  final int idLaporanLab;

  const RiwayatHormonDetailScreen({super.key, required this.idLaporanLab});

  @override
  ConsumerState<RiwayatHormonDetailScreen> createState() => _RiwayatHormonDetailScreenState();
}

class _RiwayatHormonDetailScreenState extends ConsumerState<RiwayatHormonDetailScreen> {
  String _activeHormone = "FT3";
  int? _visibleTooltipIndex;

  Map<String, dynamic>? _getParamData(Map<String, dynamic>? report, String paramName) {
    if (report == null) return null;
    List<dynamic> hasil = report['hasil_lab'] ?? [];
    for (var h in hasil) {
      if (h['parameter']?['nama_parameter']?.toString().toUpperCase() == paramName) {
        return h;
      }
    }
    return null;
  }

  Map<String, dynamic>? _formatForEdit(Map<String, dynamic>? param) {
    if (param == null) return null;
    return {
      'val': double.tryParse(param['nilai_hasil']?.toString() ?? "0"),
      'min': double.tryParse(param['rujukan_min']?.toString() ?? "0"),
      'max': double.tryParse(param['rujukan_max']?.toString() ?? "0"),
      'satuan': param['parameter']?['satuan'] ?? "",
    };
  }

  @override
  Widget build(BuildContext context) {
    final riwayatState = ref.watch(riwayatProvider);
    final laporanList = riwayatState.laporanList;

    int currentIndex = laporanList.indexWhere((l) => l['id_laporan_lab'] == widget.idLaporanLab);
    if (currentIndex == -1) {
      return const Scaffold(body: Center(child: Text("Data tidak ditemukan")));
    }

    final currentReport = laporanList[currentIndex];
    final currentRawData = currentReport['raw_data'];
    final ringkasan = currentReport['ringkasan'] ?? "";

    final previousRawData = (currentIndex + 1 < laporanList.length) ? laporanList[currentIndex + 1]['raw_data'] : null;

    DateTime curDate = DateTime.tryParse(currentRawData['tgl_periksa'] ?? "") ?? DateTime.now();
    String curDateStr = DateFormat('dd MMM yyyy', 'id_ID').format(curDate);
    String curMonthStr = DateFormat('MMM', 'id_ID').format(curDate).toUpperCase();

    String prevDateStr = "";
    String prevMonthStr = "";
    if (previousRawData != null) {
      DateTime pDate = DateTime.tryParse(previousRawData['tgl_periksa'] ?? "") ?? DateTime.now();
      prevDateStr = DateFormat('dd MMM yyyy', 'id_ID').format(pDate);
      prevMonthStr = DateFormat('MMM', 'id_ID').format(pDate).toUpperCase();
    }

    var currParam = _getParamData(currentRawData, _activeHormone);
    var prevParam = _getParamData(previousRawData, _activeHormone);

    double currVal = double.tryParse(currParam?['nilai_hasil']?.toString() ?? "0") ?? 0.0;
    double minRujukan = double.tryParse(currParam?['rujukan_min']?.toString() ?? "0") ?? 0.0;
    double maxRujukan = double.tryParse(currParam?['rujukan_max']?.toString() ?? "0") ?? 0.0;
    String unit = currParam?['parameter']?['satuan'] ?? "";

    List<double> dataPoints = [];
    List<String> datesText = [];
    List<String> xLabels = [];

    if (prevParam != null) {
      double prevVal = double.tryParse(prevParam['nilai_hasil']?.toString() ?? "0") ?? 0.0;
      dataPoints.add(prevVal);
      datesText.add(prevDateStr);
      xLabels.add(prevMonthStr);
    }

    dataPoints.add(currVal);
    datesText.add(curDateStr);
    xLabels.add(curMonthStr);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF005F82)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Riwayat Data Hormon", // ✅ Diubah dari "Arsip" menjadi "Riwayat"
          style: TextStyle(color: Color(0xFF005F82), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildAlertCard(ringkasan),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard("TSH", currentRawData),
                _buildStatCard("FT3", currentRawData),
                _buildStatCard("FT4", currentRawData),
              ],
            ),
            const SizedBox(height: 25),
            _buildChartCard(
              currentRawData,
              curDateStr,
              dataPoints,
              datesText,
              xLabels,
              minRujukan,
              maxRujukan,
              unit,
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(String ringkasan) {
    bool isStabil = ringkasan.toLowerCase().contains("stabil") || ringkasan.toLowerCase().contains("normal");

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F5), borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(isStabil ? Icons.check_circle_outline : Icons.notifications_none_outlined, color: const Color(0xFF005F82), size: 28),
              Text(
                  isStabil ? "STATUS AMAN" : "PERLU PERHATIAN",
                  style: TextStyle(color: isStabil ? const Color(0xFF00897B) : const Color(0xFFF27E6D), fontWeight: FontWeight.bold, fontSize: 11)
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(isStabil ? "Hormon Terkendali" : "Lonjakan Hormon", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D4052))),
          const SizedBox(height: 10),
          Text(
            "$ringkasan\nTidak ada perubahan signifikan terkait detak jantung, tidur, dan stres.\nPertahankan pola hidup sehat Anda.",
            style: const TextStyle(color: Color(0xFF7D848D), fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, Map<String, dynamic> report) {
    var param = _getParamData(report, label);
    String valStr = "-";
    String status = "Kosong";
    Color statusColor = Colors.grey;
    Color statusBg = Colors.grey.shade200;

    if (param != null) {
      double val = double.tryParse(param['nilai_hasil']?.toString() ?? "0") ?? 0;
      double min = double.tryParse(param['rujukan_min']?.toString() ?? "0") ?? 0;
      double max = double.tryParse(param['rujukan_max']?.toString() ?? "0") ?? 0;

      valStr = val.toStringAsFixed(2);
      if (valStr.endsWith(".00")) valStr = valStr.substring(0, valStr.length - 3);

      if (min == 0 && max == 0) {
        status = "Normal";
        statusColor = const Color(0xFF00897B);
        statusBg = const Color(0xFFCCF1E1);
      } else if (val < min) {
        status = "Rendah";
        statusColor = Colors.orange.shade800;
        statusBg = Colors.orange.shade100;
      } else if (val > max) {
        status = "Tinggi";
        statusColor = const Color(0xFFF27E6D);
        statusBg = const Color(0xFFF27E6D).withOpacity(0.2);
      } else {
        status = "Normal";
        statusColor = const Color(0xFF00897B);
        statusBg = const Color(0xFFCCF1E1);
      }
    }

    bool isActive = _activeHormone == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeHormone = label;
          _visibleTooltipIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE3F4F4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: isActive ? Border.all(color: const Color(0xFF005F82).withOpacity(0.2)) : null,
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF7D848D), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(valStr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF005F82))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
      Map<String, dynamic> currentRawData,
      String currentDateStr,
      List<double> dataPoints,
      List<String> datesText,
      List<String> xLabels,
      double minRujukan,
      double maxRujukan,
      String unit,
      ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Grafik Level $_activeHormone", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(currentDateStr, style: const TextStyle(color: Color(0xFF7D848D), fontSize: 14)),
                  ],
                ),
              ),
              Row(
                children: [
                  _badgeNormal(dataPoints.isNotEmpty ? dataPoints.last : 0, minRujukan, maxRujukan),
                  const SizedBox(width: 10),
                  Theme(
                    data: Theme.of(context).copyWith(hoverColor: Colors.transparent, splashColor: Colors.transparent),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 22),
                      color: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => EditLabScreen(
                            idLaporanLab: currentRawData['id_laporan_lab'],
                            tanggal: currentRawData['tgl_periksa'] ?? "",
                            namaLab: currentRawData['nama_lab'] ?? "Klinik",
                            tshData: _formatForEdit(_getParamData(currentRawData, "TSH")),
                            ft4Data: _formatForEdit(_getParamData(currentRawData, "FT4")),
                            ft3Data: _formatForEdit(_getParamData(currentRawData, "FT3")),
                          )));
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_note_rounded, color: Color(0xFF005F82), size: 18),
                              SizedBox(width: 8),
                              Text("Edit Data", style: TextStyle(color: Color(0xFF005F82), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 30),
          _chartTabs(),
          const SizedBox(height: 40),

          GestureDetector(
            onTapDown: (details) {
              if (dataPoints.length == 1) {
                setState(() => _visibleTooltipIndex = (_visibleTooltipIndex == 0) ? null : 0);
                return;
              }
              double width = MediaQuery.of(context).size.width - 96;
              setState(() {
                if (details.localPosition.dx < width / 2) {
                  _visibleTooltipIndex = (_visibleTooltipIndex == 0) ? null : 0;
                } else {
                  _visibleTooltipIndex = (_visibleTooltipIndex == 1) ? null : 1;
                }
              });
            },
            child: SizedBox(
              height: 250,
              width: double.infinity,
              child: CustomPaint(
                painter: _HormoneChartPainter(
                  dataPoints: dataPoints,
                  activeHormone: _activeHormone,
                  unit: unit,
                  visibleTooltipIndex: _visibleTooltipIndex,
                  datesText: datesText,
                  minRujukan: minRujukan,
                  maxRujukan: maxRujukan,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),
          xLabels.length == 1
              ? Center(child: Text(xLabels[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)))
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(xLabels[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(xLabels[1], style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _badgeNormal(double val, double min, double max) {
    String status = "Normal";
    Color txtColor = const Color(0xFF00897B);
    Color bgColor = const Color(0xFFCCF1E1);

    if (min != 0 && max != 0) {
      if (val < min || val > max) {
        status = "Perhatian";
        txtColor = const Color(0xFFF27E6D);
        bgColor = const Color(0xFFF27E6D).withOpacity(0.2);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: txtColor),
          const SizedBox(width: 8),
          Text(status, style: TextStyle(color: txtColor, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chartTabs() {
    return Row(
      children: ["TSH", "FT3", "FT4"].map((t) {
        bool active = t == _activeHormone;
        return GestureDetector(
          onTap: () {
            setState(() {
              _activeHormone = t;
              _visibleTooltipIndex = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(color: active ? const Color(0xFF005F82) : const Color(0xFFF1F5F5), borderRadius: BorderRadius.circular(12)),
            child: Text(t, style: TextStyle(color: active ? Colors.white : Colors.black26, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }
}

class _HormoneChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final String activeHormone;
  final String unit;
  final int? visibleTooltipIndex;
  final List<String> datesText;
  final double minRujukan;
  final double maxRujukan;

  _HormoneChartPainter({
    required this.dataPoints,
    required this.activeHormone,
    required this.unit,
    required this.visibleTooltipIndex,
    required this.datesText,
    required this.minRujukan,
    required this.maxRujukan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    double _min = minRujukan == 0.0 ? (activeHormone == "TSH" ? 0.35 : activeHormone == "FT4" ? 0.70 : 1.71) : minRujukan;
    double _max = maxRujukan == 0.0 ? (activeHormone == "TSH" ? 4.94 : activeHormone == "FT4" ? 1.48 : 3.71) : maxRujukan;

    double maxValueInChart = [_max, ...dataPoints].reduce((a, b) => a > b ? a : b);
    double chartMax = maxValueInChart + (maxValueInChart * 0.2);
    if (chartMax == 0) chartMax = 10;
    double chartMin = 0.0;

    double calculateYPos(double value) {
      return size.height - ((value - chartMin) / (chartMax - chartMin)) * size.height;
    }

    final gridPaint = Paint()..color = const Color(0xFFF1F5F9)..strokeWidth = 1;
    final int gridLines = 6;

    for (int i = 0; i < gridLines; i++) {
      double val = chartMax - (i * (chartMax / (gridLines - 1)));
      double yPos = calculateYPos(val);

      canvas.drawLine(Offset(25, yPos), Offset(size.width, yPos), gridPaint);

      String labelText = val.toStringAsFixed(1);
      if (labelText.endsWith(".0")) labelText = labelText.substring(0, labelText.length - 2);
      _drawText(canvas, labelText, 0, yPos - 6, Colors.grey.shade500, 10, true);
    }

    double topBoxY = calculateYPos(_max);
    double bottomBoxY = calculateYPos(_min);

    final paintNormalRange = Paint()..color = const Color(0xFFE3F4F4).withOpacity(0.6);
    canvas.drawRect(Rect.fromLTWH(25, topBoxY, size.width - 25, bottomBoxY - topBoxY), paintNormalRange);

    _drawText(canvas, "Batas Tertinggi ($_max $unit)", 30, topBoxY - 15, Colors.grey.shade600, 9, true);
    _drawText(canvas, "Batas Terendah ($_min $unit)", 30, bottomBoxY + 5, Colors.grey.shade600, 9, true);

    if (dataPoints.length == 1) {
      double val1 = dataPoints[0];
      final Offset point = Offset(size.width / 2, calculateYPos(val1));
      _drawPoint(canvas, point, const Color(0xFF005F82));
      if (visibleTooltipIndex == 0) {
        _drawTooltip(canvas, point, datesText[0], val1, _min, _max);
      }
      return;
    }

    double val1 = dataPoints[0];
    double val2 = dataPoints[1];

    final Offset prevPoint = Offset(size.width * 0.15 + 20, calculateYPos(val1));
    final Offset latestPoint = Offset(size.width * 0.85, calculateYPos(val2));

    final paintLine = Paint()
      ..color = const Color(0xFF005F82)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(prevPoint.dx, prevPoint.dy);
    double controlPointX1 = prevPoint.dx + (latestPoint.dx - prevPoint.dx) / 2;
    double controlPointX2 = latestPoint.dx - (latestPoint.dx - prevPoint.dx) / 2;
    path.cubicTo(controlPointX1, prevPoint.dy, controlPointX2, latestPoint.dy, latestPoint.dx, latestPoint.dy);
    canvas.drawPath(path, paintLine);

    _drawPoint(canvas, prevPoint, const Color(0xFF005F82));
    _drawPoint(canvas, latestPoint, val2 > _max || val2 < _min ? const Color(0xFFF27E6D) : const Color(0xFF005F82));

    if (visibleTooltipIndex == 0) _drawTooltip(canvas, prevPoint, datesText[0], val1, _min, _max);
    if (visibleTooltipIndex == 1) _drawTooltip(canvas, latestPoint, datesText[1], val2, _min, _max);
  }

  void _drawPoint(Canvas canvas, Offset offset, Color color) {
    canvas.drawCircle(offset, 8, Paint()..color = color);
    canvas.drawCircle(offset, 4, Paint()..color = Colors.white);
  }

  void _drawTooltip(Canvas canvas, Offset anchor, String dateText, double val, double min, double max) {
    String status = "Normal";
    Color statusColor = const Color(0xFFCCF1E1);
    if (val < min) { status = "Rendah"; statusColor = Colors.orange; }
    if (val > max) { status = "Tinggi"; statusColor = const Color(0xFFF27E6D); }

    double tooltipWidth = 160;
    double tooltipHeight = 85;

    double posX = anchor.dx - (tooltipWidth / 2);
    if (posX < 25) posX = 25;
    double posY = anchor.dy - tooltipHeight - 15;

    final tooltipRect = RRect.fromRectAndRadius(Rect.fromLTWH(posX, posY, tooltipWidth, tooltipHeight), const Radius.circular(12));
    canvas.drawRRect(tooltipRect, Paint()..color = const Color(0xFF2D4052));

    _drawText(canvas, dateText, posX + 15, posY + 12, Colors.white, 13, true);
    _drawText(canvas, "$activeHormone Level:", posX + 15, posY + 36, Colors.grey.shade400, 12, false);
    _drawText(canvas, "$val $unit", posX + 80, posY + 36, Colors.white, 12, true);
    _drawText(canvas, status, posX + 15, posY + 58, statusColor, 12, false);
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, double size, bool isBold) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _HormoneChartPainter oldDelegate) => true;
}