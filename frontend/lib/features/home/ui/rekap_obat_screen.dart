import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../models/obat_model.dart';
import '../providers/obat_provider.dart';
import '../../home/providers/home_provider.dart'; // ✅ 1. Import Home Provider

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
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ⚠️ CATATAN PENTING UNTUK BACKEND:
      // Karena jadwal dipisah per hari (id 1 = SEN, id 3 = RAB), jika API ini
      // hanya memanggil idJadwalObat = 1, maka log hari Rabu & Jumat tidak akan ditarik.
      // Pastikan backend kamu menarik log berdasarkan "id_obat" agar semua hari ikut terbawa.
      ref.read(obatProvider.notifier).fetchLogKonsumsi(widget.jadwal.idJadwalObat);
    });
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    super.dispose();
  }

  // ✅ 2. Cek apakah tanggal tersebut termasuk dalam daftar SEMUA hari (SEN, RAB, JUM)
  bool _isHariKonsumsi(DateTime date, List<String> semuaHari) {
    final weekdays = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
    final dayName = weekdays[date.weekday - 1];

    if (semuaHari.isNotEmpty) {
      return semuaHari.any((h) => h.toUpperCase().contains(dayName));
    }
    return true;
  }

  Map<String, int> _buildKepatuhanCount(List<LogKonsumsiObatModel> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      if (log.tglKonsumsi != null && log.status.toLowerCase() == 'diminum') {
        final key = DateFormat('yyyy-MM-dd').format(log.tglKonsumsi!);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  String _getStatusHarian(DateTime date, Map<String, int> kepatuhanCount, int targetFrekuensi, List<String> semuaHari) {
    if (!_isHariKonsumsi(date, semuaHari)) return 'Bukan Jadwal';

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final dateNorm = DateTime(date.year, date.month, date.day);

    if (dateNorm.isAfter(todayNorm)) return 'Belum';

    final key = DateFormat('yyyy-MM-dd').format(date);
    int diminum = kepatuhanCount[key] ?? 0;

    if (diminum == 0) return 'Terlewat';
    if (diminum < targetFrekuensi) return 'Sebagian';
    return 'Teratur';
  }

  Color _getWarnaStatus(String status) {
    switch (status) {
      case 'Teratur':
        return const Color(0xFF00695C);
      case 'Sebagian':
        return Colors.amber.shade600;
      case 'Terlewat':
        return const Color(0xFFC62828);
      case 'Bukan Jadwal':
        return Colors.grey.shade300;
      default:
        return const Color(0xFF1F2937);
    }
  }

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

    // ✅ 3. Menggabungkan semua jadwal untuk mendapatkan "SEN, RAB, JUM" secara akurat
    final semuaJadwalDb = ref.watch(homeProvider).jadwalObat;
    final jadwalTerkait = semuaJadwalDb.where((j) => j.idObat == obat.idObat).toList();

    List<String> gabunganHari = obat.hariKonsumsi ?? [];
    if (gabunganHari.isEmpty) {
      gabunganHari = jadwalTerkait.map((j) => j.hari ?? '').where((h) => h.isNotEmpty).toSet().toList();
    }

    // Persiapan Data
    final targetFrekuensi = widget.times.isNotEmpty ? widget.times.length : 1;
    final kepatuhanCount = _buildKepatuhanCount(logs);

    final tglMulai = obat.tglMulai ?? DateTime.now();
    final tglSelesai = obat.tglSelesai ?? DateTime.now().add(const Duration(days: 30));
    final monthsList = _getMonthsList(tglMulai, tglSelesai);

    int statTotal = 0;
    int statDiminum = 0;
    int statTerlewat = 0;

    DateTime currentCounter = DateTime(tglMulai.year, tglMulai.month, tglMulai.day);
    final endCounter = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    while (!currentCounter.isAfter(endCounter) && !currentCounter.isAfter(tglSelesai)) {
      // Hitung hanya jika hari tersebut masuk dalam gabunganHari (SEN/RAB/JUM)
      if (_isHariKonsumsi(currentCounter, gabunganHari)) {
        statTotal += targetFrekuensi;
        final key = DateFormat('yyyy-MM-dd').format(currentCounter);
        statDiminum += (kepatuhanCount[key] ?? 0);
      }
      currentCounter = currentCounter.add(const Duration(days: 1));
    }

    statTerlewat = (statTotal - statDiminum).clamp(0, 9999);

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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF006699)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      children: widget.times.map((t) {
                        String shortTime = t.length >= 5 ? t.substring(0, 5) : t;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
                          child: Text("$shortTime WIB", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        );
                      }).toList(),
                    )
                  ]
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatBox(label: 'Total Target', value: '$statTotal', bgColor: const Color(0xFFEFEFEF), textColor: Colors.black),
                _StatBox(label: 'Diminum', value: '$statDiminum', bgColor: const Color(0xFFE0F2F1), textColor: const Color(0xFF00695C)),
                _StatBox(label: 'Terlewat', value: '$statTerlewat', bgColor: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),
              ],
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]
              ),
              child: Column(
                children: [
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

                  SizedBox(
                    height: 250,
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
                          gabunganHari: gabunganHari, // ✅ Menggunakan gabunganHari
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: const Color(0xFF00695C), label: 'Teratur'),
                      const SizedBox(width: 12),
                      if (targetFrekuensi > 1) ...[
                        _LegendDot(color: Colors.amber.shade600, label: 'Sebagian'),
                        const SizedBox(width: 12),
                      ],
                      _LegendDot(color: const Color(0xFFC62828), label: 'Terlewat'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildDailyDetailSection(logs, kepatuhanCount, targetFrekuensi, gabunganHari),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid({
    required DateTime monthDate,
    required DateTime tglMulai,
    required DateTime tglSelesai,
    required Map<String, int> kepatuhanCount,
    required int targetFrekuensi,
    required List<String> gabunganHari,
  }) {
    int daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    int firstWeekdayOffset = DateTime(monthDate.year, monthDate.month, 1).weekday - 1;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: daysInMonth + firstWeekdayOffset,
      itemBuilder: (context, index) {
        if (index < firstWeekdayOffset) return const SizedBox.shrink();

        int day = index - firstWeekdayOffset + 1;
        DateTime thisDate = DateTime(monthDate.year, monthDate.month, day);

        bool isOutsideRange = thisDate.isBefore(DateTime(tglMulai.year, tglMulai.month, tglMulai.day)) ||
            thisDate.isAfter(DateTime(tglSelesai.year, tglSelesai.month, tglSelesai.day));

        if (isOutsideRange) {
          return Center(child: Text('$day', style: const TextStyle(color: Color(0xFFD1D5DB), fontWeight: FontWeight.w400)));
        }

        String status = _getStatusHarian(thisDate, kepatuhanCount, targetFrekuensi, gabunganHari);
        Color textColor = _getWarnaStatus(status);

        bool isSelected = _selectedDate != null &&
            _selectedDate!.year == thisDate.year &&
            _selectedDate!.month == thisDate.month &&
            _selectedDate!.day == thisDate.day;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = thisDate;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFFEAF5FF) : Colors.transparent,
              border: isSelected ? Border.all(color: const Color(0xFF006699), width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyDetailSection(List<LogKonsumsiObatModel> logs, Map<String, int> kepatuhanCount, int targetFrekuensi, List<String> gabunganHari) {
    if (_selectedDate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            "Ketuk tanggal di kalender untuk melihat detail.",
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    String formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id').format(_selectedDate!);
    String statusHarian = _getStatusHarian(_selectedDate!, kepatuhanCount, targetFrekuensi, gabunganHari);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Riwayat: $formattedDate', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 16),

        if (statusHarian == 'Bukan Jadwal')
          _buildInfoCard(Icons.bedtime_outlined, "Bukan Jadwal", "Hari ini tidak ada jadwal minum obat ini.", Colors.grey.shade600)
        else if (statusHarian == 'Belum')
          _buildInfoCard(Icons.hourglass_empty, "Belum Tiba", "Jadwal konsumsi untuk tanggal ini belum tiba.", Colors.blue.shade600)
        else
          ..._buildHourlyCards(logs),
      ],
    );
  }

  List<Widget> _buildHourlyCards(List<LogKonsumsiObatModel> logs) {
    List<Widget> cards = [];
    DateTime now = DateTime.now();

    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final logsToday = logs.where((l) =>
    l.tglKonsumsi != null &&
        DateFormat('yyyy-MM-dd').format(l.tglKonsumsi!) == selectedKey &&
        l.status.toLowerCase() == 'diminum'
    ).toList();

    List<String> timeList = widget.times.isNotEmpty ? widget.times : ["08:00:00"];

    for (int i = 0; i < timeList.length; i++) {
      String timeStr = timeList[i];
      String displayTime = timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr;

      List<String> parts = timeStr.split(':');
      int hour = parts.isNotEmpty ? int.parse(parts[0]) : 0;
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

      DateTime targetTimeObj = DateTime(
          _selectedDate!.year, _selectedDate!.month, _selectedDate!.day, hour, minute
      );

      bool isDiminum = i < logsToday.length;

      String slotStatus;
      Color slotColor;
      IconData slotIcon;
      String slotDesc;

      if (isDiminum) {
        slotStatus = "Diminum";
        slotColor = const Color(0xFF00695C);
        slotIcon = Icons.check_circle;
        slotDesc = "Anda sudah meminum obat ini tepat waktu.";
      } else {
        if (now.isAfter(targetTimeObj)) {
          slotStatus = "Terlewat";
          slotColor = const Color(0xFFC62828);
          slotIcon = Icons.cancel;
          slotDesc = "Anda melewatkan jadwal konsumsi obat jam ini.";
        } else {
          slotStatus = "Belum Waktunya";
          slotColor = Colors.blue.shade600;
          slotIcon = Icons.hourglass_empty;
          slotDesc = "Waktu konsumsi untuk jam ini belum tiba.";
        }
      }

      cards.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: slotColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: slotColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(slotIcon, color: slotColor, size: 30),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(slotStatus, style: TextStyle(color: slotColor, fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Text("$displayTime WIB", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(slotDesc, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                    ],
                  ),
                )
              ],
            ),
          )
      );
    }
    return cards;
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black87, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

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