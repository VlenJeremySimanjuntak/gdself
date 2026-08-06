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
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final obatId = widget.jadwal.obat.idObat;
      final obatNotifier = ref.read(obatProvider.notifier);

      await obatNotifier.fetchJadwal(obatId);
      await obatNotifier.fetchRekapObat(obatId);

      final jadwalList = ref.read(obatProvider).jadwalList;
      final listJadwalId = jadwalList.map((j) => j.idJadwalObat).toList();

      if (listJadwalId.isNotEmpty) {
        await obatNotifier.fetchSemuaLogUntukObat(listJadwalId);
      } else {
        await obatNotifier.fetchLogKonsumsi(widget.jadwal.idJadwalObat);
      }
    });
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    super.dispose();
  }

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
      if (log.tglKonsumsi != null) {
        final status = log.status.toLowerCase();
        if (status == 'diminum' || status == 'teratur') {
          final key = DateFormat('yyyy-MM-dd').format(log.tglKonsumsi!);
          map[key] = (map[key] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  String _getStatusHarian(DateTime date, Map<String, int> kepatuhanCount, int targetFrekuensi, List<String> semuaHari, DateTime maxDate) {
    if (!_isHariKonsumsi(date, semuaHari)) return 'Bukan Jadwal';

    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final dateNorm = DateTime(date.year, date.month, date.day);
    final maxDateNorm = DateTime(maxDate.year, maxDate.month, maxDate.day);

    if (dateNorm.isAfter(maxDateNorm)) return 'Belum';
    if (dateNorm.isAfter(todayNorm)) return 'Belum';

    final key = DateFormat('yyyy-MM-dd').format(date);
    int jumlahDiminum = kepatuhanCount[key] ?? 0;

    if (dateNorm.isBefore(todayNorm)) {
      if (jumlahDiminum >= targetFrekuensi) {
        return 'Teratur';
      } else if (jumlahDiminum > 0) {
        return 'Sebagian';
      } else {
        return 'Terlewat';
      }
    }

    int passedSchedules = 0;
    List<String> timeList = widget.times.isNotEmpty ? widget.times : ["08:00:00"];
    for (String t in timeList) {
      List<String> parts = t.split(':');
      int hour = parts.isNotEmpty ? int.parse(parts[0]) : 0;
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      DateTime targetTime = DateTime(date.year, date.month, date.day, hour, minute);
      if (now.isAfter(targetTime)) {
        passedSchedules++;
      }
    }

    if (jumlahDiminum >= targetFrekuensi) {
      return 'Teratur';
    } else if (jumlahDiminum > 0) {
      return 'Sebagian';
    } else {
      if (passedSchedules > 0) {
        return 'Terlewat';
      } else {
        return 'Belum';
      }
    }
  }

  Color _getWarnaStatus(String status) {
    switch (status) {
      case 'Teratur':
        return const Color(0xFF0C7D6A); // Sesuai warna Teal di mockup
      case 'Sebagian':
        return Colors.amber.shade700;
      case 'Terlewat':
        return const Color(0xFFFF4B4B); // Merah cerah sesuai mockup
      case 'Bukan Jadwal':
        return Colors.transparent;
      case 'Belum':
        return const Color(0xFF94A3B8);
      default:
        return const Color(0xFF94A3B8);
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
    final jadwalTerkait = obatState.jadwalList;

    List<String> gabunganHari = obat.hariKonsumsi ?? [];
    if (gabunganHari.isEmpty) {
      gabunganHari = jadwalTerkait.map((j) => j.hari ?? '').where((h) => h.isNotEmpty).toSet().toList();
    }

    final targetFrekuensi = widget.times.isNotEmpty ? widget.times.length : 1;
    final kepatuhanCount = _buildKepatuhanCount(logs);

    final tglMulai = obat.tglMulai ?? DateTime.now();
    final tglAkhirKalender = obat.tglSelesai ?? DateTime.now();
    final monthsList = _getMonthsList(tglMulai, tglAkhirKalender);

    // Cek apakah terapi sudah selesai
    final nowNorm = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final akhirNorm = DateTime(tglAkhirKalender.year, tglAkhirKalender.month, tglAkhirKalender.day);
    final isTerapiSelesai = nowNorm.isAfter(akhirNorm);

    final rekapMap = obatState.rekapData;
    final rekapObat = rekapMap[widget.jadwal.obat.idObat] as Map<String, dynamic>?;

    final int statDiminum = (rekapObat?['stat_diminum'] as num?)?.toInt() ?? 0;
    final int statTotal = (rekapObat?['stat_total'] as num?)?.toInt() ?? 0;
    final int statTerlewat = (statTotal - statDiminum).clamp(0, 9999);
    final double persentaseKepatuhan = (rekapObat?['persentase'] as num?)?.toDouble() ?? 0.0;

    String rawStatus = rekapObat?['status_kepatuhan'] as String? ?? 'Menunggu Data';
    String rawPesan = rekapObat?['pesan_edukasi'] as String? ?? 'Belum ada jadwal konsumsi obat yang tercatat.';

    String aiStatusTitle = rawStatus.toUpperCase();
    String aiSubtitle = rawPesan;
    Color aiColor = Colors.grey.shade600; // Default warna untuk 'Menunggu Data'

    // Mapping warna UI berdasarkan status string dari backend
    if (rawStatus.toLowerCase() == 'kepatuhan baik') {
      aiColor = const Color(0xFF0C7D6A); // Teal (Sesuai mockup)
    } else if (rawStatus.toLowerCase() == 'perlu peninjauan') {
      aiColor = const Color(0xFFFF4B4B); // Merah cerah
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC), // Background abu sangat tipis/biru muda
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF546E7A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rekap Obat",
              style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormat('d MMM yyyy', 'id_ID').format(tglMulai)} - ${DateFormat('d MMM yyyy', 'id_ID').format(tglAkhirKalender)}',
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: obatState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C7D6A)))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CARD INFO OBAT (Sesuai Mockup)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32), // Sudut dibuat lebih membulat
                border: Border.all(color: const Color(0xFFB8E7D5), width: 1.5), // Warna border hijau mint tipis
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72, // Lingkaran ikon diperbesar
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF5F3), // Background lingkaran hijau sangat pudar
                      shape: BoxShape.circle,
                    ),
                    child: Icon(PhosphorIcons.pill(PhosphorIconsStyle.regular), color: const Color(0xFF00695C), size: 36),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obat.namaObat,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF131F33), // Biru dongker gelap/hitam
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "${obat.dosis ?? '-'} ",
                              style: const TextStyle(
                                color: Color(0xFF64748B), // Abu-abu tua
                                fontWeight: FontWeight.bold, // Dosis di-bold
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "${obat.frekuensi ?? '-'}",
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500, // Frekuensi medium
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Jam Pill (Sesuai gambar: background abu muda, teks hitam)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: widget.times.map((t) {
                            // Mengubah format "08:00" menjadi "08.00"
                            String shortTime = t.length >= 5 ? t.substring(0, 5).replaceAll(':', '.') : t;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAEFEB), // Abu-abu dengan sentuhan hijau pudar
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                shortTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black, // Teks hitam tebal
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. CARD KEPATUHAN TERAPI
            const Text("KEPATUHAN TERAPI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32), // Mengikuti lengkungan card sebelumnya
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  // Bagian Persentase & Edukasi (Background Biru Muda)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FB), // Biru-abu sangat muda
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Kiri: Lingkaran Persentase & Status Title
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 65,
                                  height: 65,
                                  child: CircularProgressIndicator(
                                    value: persentaseKepatuhan / 100,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    color: aiColor,
                                    strokeWidth: 6,
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Text(
                                  "${persentaseKepatuhan.toInt()}%",
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: aiColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              aiStatusTitle,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: aiColor, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        // Kanan: Pesan Edukasi
                        Expanded(
                          child: Text(
                            aiSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600, // Sedikit ditebalkan sesuai gambar
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiga Kolom Statistik
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: 'Total', value: '$statTotal', bgColor: const Color(0xFFEBEBEB), labelColor: const Color(0xFF333333))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Diminum', value: '$statDiminum', bgColor: const Color(0xFFE0F7F6), labelColor: const Color(0xFF00695C))),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: 'Terlewat', value: '$statTerlewat', bgColor: const Color(0xFFFFEBEE), labelColor: const Color(0xFFB71C1C))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 3. CARD KALENDER KEPATUHAN (Teks bewarna tanpa background lingkaran penuh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF0C7D6A)),
                        onPressed: _currentMonthIndex > 0
                            ? () {
                          _monthPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                            : null,
                      ),
                      Text(
                        monthsList.isNotEmpty ? DateFormat('MMMM yyyy', 'id').format(monthsList[_currentMonthIndex]) : '',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0C7D6A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF0C7D6A)),
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
                      child: Center(child: Text(day, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B)))),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250, // Disesuaikan agar muat
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
                          maxDate: tglAkhirKalender,
                          kepatuhanCount: kepatuhanCount,
                          targetFrekuensi: targetFrekuensi,
                          gabunganHari: gabunganHari,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _LegendDot(color: Color(0xFF0C7D6A), label: 'Teratur'),
                      const SizedBox(width: 16),
                      _LegendDot(color: Colors.amber.shade700, label: 'Sebagian'), // Ditambahkan untuk status Sebagian
                      const SizedBox(width: 16),
                      const _LegendDot(color: Color(0xFFFF4B4B), label: 'Terlewat'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Teks Bantuan
            const Center(
              child: Text(
                  "Ketuk tanggal di kalender untuk melihat detail.",
                  style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontSize: 12)
              ),
            ),
            const SizedBox(height: 24),

            // 4. DETAIL RIWAYAT HARIAN
            _buildDailyDetailSection(logs, kepatuhanCount, targetFrekuensi, gabunganHari, tglAkhirKalender),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid({
    required DateTime monthDate,
    required DateTime tglMulai,
    required DateTime maxDate,
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
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: daysInMonth + firstWeekdayOffset,
      itemBuilder: (context, index) {
        if (index < firstWeekdayOffset) return const SizedBox.shrink();

        int day = index - firstWeekdayOffset + 1;
        DateTime thisDate = DateTime(monthDate.year, monthDate.month, day);

        bool isOutsideRange = thisDate.isBefore(DateTime(tglMulai.year, tglMulai.month, tglMulai.day)) ||
            thisDate.isAfter(DateTime(maxDate.year, maxDate.month, maxDate.day));

        if (isOutsideRange) {
          return const SizedBox.shrink();
        }

        String status = _getStatusHarian(thisDate, kepatuhanCount, targetFrekuensi, gabunganHari, maxDate);
        Color textColor = _getWarnaStatus(status);

        if (status == 'Bukan Jadwal') {
          return Center(child: Text('$day', style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w500)));
        }

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
              // Jika dipilih, berikan background tipis agar terlihat
              color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor, // Warna menyesuaikan status (Teal/Merah)
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyDetailSection(List<LogKonsumsiObatModel> logs, Map<String, int> kepatuhanCount, int targetFrekuensi, List<String> gabunganHari, DateTime maxDate) {
    if (_selectedDate == null) {
      return const SizedBox.shrink(); // Disembunyikan jika belum dipilih
    }

    String formattedDate = DateFormat('EEEE, d MMMM yyyy', 'id').format(_selectedDate!);
    String statusHarian = _getStatusHarian(_selectedDate!, kepatuhanCount, targetFrekuensi, gabunganHari, maxDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),
        if (statusHarian == 'Bukan Jadwal')
          _buildInfoCard(Icons.bedtime_outlined, "Bukan Jadwal", "Hari ini tidak ada jadwal minum obat ini.", Colors.grey)
        else if (statusHarian == 'Belum')
          _buildInfoCard(Icons.hourglass_empty, "Belum Tiba", "Jadwal konsumsi untuk tanggal ini belum tiba.", Colors.blue)
        else
          ..._buildHourlyCards(logs),
      ],
    );
  }

  List<Widget> _buildHourlyCards(List<LogKonsumsiObatModel> logs) {
    List<Widget> cards = [];
    DateTime now = DateTime.now();
    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final jadwalTerkait = ref.watch(obatProvider).jadwalList;
    List<String> timeList = widget.times.isNotEmpty ? widget.times : ["08:00:00"];

    for (int i = 0; i < timeList.length; i++) {
      String timeStr = timeList[i].trim();
      String displayTime = timeStr.length >= 5 ? timeStr.substring(0, 5).replaceAll(':', '.') : timeStr;

      List<String> parts = timeStr.split(':');
      int hour = parts.isNotEmpty ? int.parse(parts[0]) : 0;
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      DateTime targetTimeObj = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, hour, minute);

      LogKonsumsiObatModel? actualLog;
      for (var log in logs) {
        if (log.tglKonsumsi == null) continue;
        if (DateFormat('yyyy-MM-dd').format(log.tglKonsumsi!) == selectedKey) {
          final matchingJadwal = jadwalTerkait.firstWhere(
                (j) => j.idJadwalObat == log.idJadwalObat,
            orElse: () => JadwalObatModel(idJadwalObat: 0, idObat: 0, obat: widget.jadwal.obat),
          );

          String dbTime = matchingJadwal.waktuMinumObat?.trim() ?? "";
          if (matchingJadwal.idJadwalObat != 0 &&
              (dbTime.length >= 5 ? dbTime.substring(0, 5) : dbTime) == (timeStr.length >= 5 ? timeStr.substring(0, 5) : timeStr)) {
            String s = log.status.trim().toLowerCase();
            if (s == 'diminum' || s == 'teratur') {
              actualLog = log;
              break;
            }
          }
        }
      }

      String slotStatus;
      Color slotColor;
      IconData slotIcon;

      if (actualLog != null) {
        slotStatus = "Diminum";
        slotColor = const Color(0xFF0C7D6A);
        slotIcon = Icons.check_circle;
      } else {
        if (now.isAfter(targetTimeObj)) {
          slotStatus = "Terlewat";
          slotColor = const Color(0xFFFF4B4B);
          slotIcon = Icons.cancel;
        } else {
          slotStatus = "Belum Waktunya";
          slotColor = Colors.grey;
          slotIcon = Icons.hourglass_empty;
        }
      }

      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: slotColor.withOpacity(0.2), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: slotColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(slotIcon, color: slotColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$displayTime WIB", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text(slotStatus, style: TextStyle(color: slotColor, fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        ),
      );
    }
    return cards;
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// KOTAK STATISTIK BAWAH (TOTAL, DIMINUM, TERLEWAT)
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color bgColor, labelColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        // Border dihilangkan agar sesuai gambar referensi
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500, // Regular/Medium
                color: labelColor,
              )
          ),
          const SizedBox(height: 6),
          Text(
              value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black // Angka selalu hitam sesuai gambar
              )
          ),
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
    return Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF78909C), fontWeight: FontWeight.w600))
        ]
    );
  }
}