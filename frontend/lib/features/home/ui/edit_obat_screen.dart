import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/obat_model.dart';
import '../../home/providers/user_provider.dart';
import '../../home/providers/home_provider.dart';
import '../providers/obat_provider.dart';
import '../../../services/notification_service.dart';

class EditObatScreen extends StatelessWidget {
  final JadwalObatModel jadwal;

  const EditObatScreen({super.key, required this.jadwal});

  @override
  Widget build(BuildContext context) {
    return ObatScheduleEditForm(
      title: 'Edit Obat',
      primaryButtonLabel: 'Simpan Perubahan',
      jadwal: jadwal,
    );
  }
}

class ObatScheduleEditForm extends ConsumerStatefulWidget {
  final String title;
  final String primaryButtonLabel;
  final JadwalObatModel jadwal;

  const ObatScheduleEditForm({
    super.key,
    required this.title,
    required this.primaryButtonLabel,
    required this.jadwal,
  });

  @override
  ConsumerState<ObatScheduleEditForm> createState() => _ObatScheduleEditFormState();
}

class _ObatScheduleEditFormState extends ConsumerState<ObatScheduleEditForm> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  final TextEditingController _namaObatController = TextEditingController();
  final TextEditingController _dosisController = TextEditingController();

  final List<String> _obatSuggestions = const [
    'Propylthiouracil (PTU)',
    'Methimazole',
    'Thiamazole',
    'Bisoprolol',
    'Propranolol',
    'Levothyroxine',
  ];

  final List<_DayOption> _days = const [
    _DayOption('S', 'SEN'),
    _DayOption('S', 'SEL'),
    _DayOption('R', 'RAB'),
    _DayOption('K', 'KAM'),
    _DayOption('J', 'JUM'),
    _DayOption('S', 'SAB'),
    _DayOption('M', 'MIN'),
  ];

  // State Step 1
  late DateTime _tanggalMulai;
  DateTime? _tanggalSelesai;
  String _tipeObat = 'Tablet';
  int _frekuensi = 1;

  // State Step 2
  late List<bool> _selectedDays;
  late List<TimeOfDay?> _times;

  @override
  void initState() {
    super.initState();
    _selectedDays = List<bool>.filled(_days.length, false);
    _times = [];
    _loadExistingData();
  }

  void _loadExistingData() {
    final obat = widget.jadwal.obat;
    _namaObatController.text = obat.namaObat;

    // Hilangkan teks 'mg' jika dari backend sudah tergabung
    String dosisAsli = obat.dosis ?? '';
    _dosisController.text = dosisAsli.replaceAll(RegExp(r'[a-zA-Z\s]'), '');

    if (['Tablet', 'Kapsul', 'Sirup', 'Injeksi', 'Lainnya'].contains(obat.tipeObat)) {
      _tipeObat = obat.tipeObat!;
    } else {
      _tipeObat = 'Tablet';
    }

    _tanggalMulai = obat.tglMulai ?? DateTime.now();
    _tanggalSelesai = obat.tglSelesai;

    // Tunggu build pertama selesai untuk mengambil state dari homeProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final semuaJadwal = ref.read(homeProvider).jadwalObat.where((j) => j.idObat == obat.idObat).toList();

      final Set<String> loadedDays = {};
      final Set<String> loadedTimes = {};

      for (var j in semuaJadwal) {
        if (j.hari != null) {
          // Asumsi format hari misal "Senin", "Selasa", dst. Kita harus match ke longLabel kita ("SEN", "SEL")
          // Namun di sistem Mas sebelumnya menggunakan "Senin, Selasa". Mari kita tampung apa adanya dulu,
          // asumsikan sudah disesuaikan dengan format 'SEN', 'SEL' dsb.
          final splits = j.hari!.split(',');
          for (var h in splits) {
            loadedDays.add(h.trim().toUpperCase());
          }
        }
        if (j.waktuMinumObat != null) {
          final splits = j.waktuMinumObat!.split(',');
          for (var t in splits) {
            if (t.trim().length >= 5) loadedTimes.add(t.trim().substring(0, 5));
          }
        }
      }

      // Checklist Hari
      for (int i = 0; i < _days.length; i++) {
        // Cek kecocokan (bisa disesuaikan jika data lama menggunakan "Senin" bukan "SEN")
        if (loadedDays.contains(_days[i].longLabel) || loadedDays.any((d) => d.contains(_days[i].longLabel))) {
          _selectedDays[i] = true;
        }
      }

      // Setup Waktu & Frekuensi
      final timesList = loadedTimes.toList()..sort();
      _times = timesList.map((t) {
        final parts = t.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }).toList();

      if (obat.frekuensi != null && obat.frekuensi!.isNotEmpty) {
        final f = int.tryParse(obat.frekuensi!.replaceAll(RegExp(r'[^0-9]'), ''));
        if (f != null && f > 0) {
          _frekuensi = f;
        } else {
          _frekuensi = _times.isEmpty ? 1 : _times.length;
        }
      } else {
        _frekuensi = _times.isEmpty ? 1 : _times.length;
      }

      while (_times.length < _frekuensi) {
        _times.add(null);
      }
      if (_times.length > _frekuensi) {
        _times = _times.sublist(0, _frekuensi);
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _namaObatController.dispose();
    _dosisController.dispose();
    super.dispose();
  }

  void _updateTimesList() {
    // Pertahankan jam yang sudah diisi jika mengubah frekuensi
    final currentTimes = List<TimeOfDay?>.from(_times);
    _times = List<TimeOfDay?>.filled(_frekuensi, null);
    for (int i = 0; i < _frekuensi && i < currentTimes.length; i++) {
      _times[i] = currentTimes[i];
    }
  }

  bool _isDateOverlapping(DateTime startA, DateTime? endA, DateTime startB, DateTime? endB) {
    final aStart = DateTime(startA.year, startA.month, startA.day);
    final aEnd = endA != null ? DateTime(endA.year, endA.month, endA.day) : null;
    final bStart = DateTime(startB.year, startB.month, startB.day);
    final bEnd = endB != null ? DateTime(endB.year, endB.month, endB.day) : null;

    bool aStartBeforeOrEqBEnd = bEnd == null || aStart.isBefore(bEnd) || aStart.isAtSameMomentAs(bEnd);
    bool bStartBeforeOrEqAEnd = aEnd == null || bStart.isBefore(aEnd) || bStart.isAtSameMomentAs(aEnd);

    return aStartBeforeOrEqBEnd && bStartBeforeOrEqAEnd;
  }

  void _nextStep() {
    if (_namaObatController.text.trim().isEmpty) return _showMessage('Nama obat belum diisi');
    if (_dosisController.text.trim().isEmpty) return _showMessage('Dosis belum diisi');
    if (_tanggalSelesai != null && _tanggalSelesai!.isBefore(_tanggalMulai)) {
      return _showMessage('Tanggal selesai tidak boleh mendahului tanggal mulai');
    }

    setState(() => _currentStep = 1);
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _prevStep() {
    setState(() => _currentStep = 0);
    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF006699);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: themeBlue),
          onPressed: () {
            if (_currentStep == 1) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(color: themeBlue, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Positioned(right: -100, top: -50, child: _GlowBubble(color: const Color(0xFFE0F7FA).withOpacity(0.5), size: 300)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.5),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Obat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF263238))),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel('Nama Obat'),
                const SizedBox(height: 6),
                _buildMedicineAutocomplete(),
                const SizedBox(height: 16),
                const _FieldLabel('Tanggal Mulai'),
                const SizedBox(height: 6),
                _buildDatePickerField(
                  date: _tanggalMulai,
                  onTap: () async {
                    final picked = await showDialog<DateTime>(
                      context: context,
                      builder: (context) => _CustomCalendarDialog(initialDate: _tanggalMulai),
                    );
                    if (picked != null) setState(() => _tanggalMulai = picked);
                  },
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Tanggal Selesai'),
                const SizedBox(height: 6),
                _buildDatePickerField(
                  date: _tanggalSelesai,
                  hint: "Opsional (Pilih Tanggal)",
                  onTap: () async {
                    final picked = await showDialog<DateTime>(
                      context: context,
                      builder: (context) => _CustomCalendarDialog(initialDate: _tanggalSelesai ?? _tanggalMulai),
                    );
                    if (picked != null) setState(() => _tanggalSelesai = picked);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Informasi Dosis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF263238))),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Tipe Obat'),
                          const SizedBox(height: 6),
                          Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _tipeObat,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                items: ['Tablet', 'Kapsul', 'Sirup', 'Injeksi', 'Lainnya'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _tipeObat = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Dosis'),
                          const SizedBox(height: 6),
                          _InputField(
                            controller: _dosisController,
                            hintText: '0',
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            suffixText: 'mg',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _FieldLabel('Frekuensi'),
                const SizedBox(height: 6),
                Row(
                  children: [1, 2, 3].map((int freq) {
                    final isSelected = _frekuensi == freq;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _frekuensi = freq;
                            _updateTimesList();
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: freq == 3 ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? const Color(0xFFE5E7EB) : Colors.transparent),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${freq}x Sehari",
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text("Selanjutnya", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final obatState = ref.watch(obatProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jadwal Pengobatan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF263238))),
          const SizedBox(height: 12),
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    final shouldSelectAll = !_selectedDays.every((value) => value);
                    setState(() {
                      for (var i = 0; i < _selectedDays.length; i++) {
                        _selectedDays[i] = shouldSelectAll;
                      }
                    });
                  },
                  child: const Text('Pilih Semua', style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_days.length, (index) {
                    final day = _days[index];
                    final selected = _selectedDays[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDays[index] = !_selectedDays[index]),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected ? const Color(0xFF006699) : const Color(0xFFE5E7EB),
                            ),
                            alignment: Alignment.center,
                            child: Text(day.shortLabel, style: TextStyle(color: selected ? Colors.white : const Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: 6),
                          Text(day.longLabel, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Waktu Konsumsi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF263238))),
          const SizedBox(height: 4),
          const Text('Pilih waktu konsumsi obat sesuai frekuensi harian.', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          const SizedBox(height: 16),

          ..._times.asMap().entries.map((entry) => _buildTimeSlotCard(entry.key, entry.value)),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: obatState.isLoading ? null : _saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006699),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 2,
              ),
              child: obatState.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(widget.primaryButtonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMedicineAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) return const Iterable<String>.empty();
        return _obatSuggestions.where((option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) => _namaObatController.text = selection,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (_namaObatController.text.isNotEmpty && controller.text.isEmpty) controller.text = _namaObatController.text;
        return _InputField(
          controller: controller,
          focusNode: focusNode,
          hintText: 'Misal: Paracetamol',
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 80,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      title: Text(option, style: const TextStyle(color: Color(0xFF2F3B42), fontWeight: FontWeight.w600, fontSize: 14)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField({DateTime? date, String hint = "dd/mm/yyyy", required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null ? DateFormat('dd/MM/yyyy', 'id_ID').format(date) : hint,
                style: TextStyle(color: date != null ? const Color(0xFF334155) : Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotCard(int index, TimeOfDay? time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0xFFDDEBFA), shape: BoxShape.circle),
            child: const Icon(Icons.access_time, color: Color(0xFF006699), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Waktu', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Ketuk untuk mengatur', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              TimeOfDay? minTime;
              if (index > 0) minTime = _times[index - 1];
              TimeOfDay? maxTime;
              if (index < _times.length - 1) maxTime = _times[index + 1];

              final picked = await showDialog<TimeOfDay>(
                context: context,
                builder: (context) => _CustomTimePickerDialog(
                  initialTime: time ?? const TimeOfDay(hour: 8, minute: 0),
                  minTime: minTime,
                  maxTime: maxTime,
                ),
              );

              if (picked != null) setState(() => _times[index] = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(10)),
              child: Text(
                time == null ? '--:--' : _formatTime(time),
                style: const TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    final selectedDays = <String>[];
    for (var i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) selectedDays.add(_days[i].longLabel);
    }

    if (selectedDays.isEmpty) return _showMessage('Pilih minimal satu hari konsumsi (Senin-Minggu)');
    if (_times.any((time) => time == null)) return _showMessage('Lengkapi semua kotak waktu konsumsi');

    final user = ref.read(userProvider).user;
    if (user == null || user.idUser == 0) return _showMessage('Session user tidak ditemukan.');

    final namaObat = _namaObatController.text.trim();
    final dosis = _dosisController.text.trim();
    final semuaJadwal = ref.read(homeProvider).jadwalObat;

    // VALIDASI BENTROK (Overlap) dengan pengecualian ID Obat ini
    bool isBentrok = false;
    for (var jdwl in semuaJadwal) {
      if (jdwl.idObat == widget.jadwal.idObat) continue; // LEWATI DIRI SENDIRI

      if (jdwl.obat.namaObat.toLowerCase() == namaObat.toLowerCase()) {
        final startLama = jdwl.obat.tglMulai;
        final endLama = jdwl.obat.tglSelesai;

        if (startLama != null) {
          if (_isDateOverlapping(_tanggalMulai, _tanggalSelesai, startLama, endLama)) {
            isBentrok = true;
            break;
          }
        }
      }
    }

    if (isBentrok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal! Rentang tanggal bertabrakan dengan jadwal obat yang sama di riwayat/rekapan.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final formattedMulai = DateFormat('yyyy-MM-dd').format(_tanggalMulai);
    final formattedSelesai = _tanggalSelesai != null ? DateFormat('yyyy-MM-dd').format(_tanggalSelesai!) : null;
    final waktuKonsumsiList = _times.whereType<TimeOfDay>().map((time) => _formatTimeForApi(time)).toList();

    // Call Edit API
    final success = await ref.read(obatProvider.notifier).editObatDenganJadwal(
      idObat: widget.jadwal.idObat,
      userId: user.idUser,
      namaObat: namaObat,
      dosis: dosis,
      waktuKonsumsi: waktuKonsumsiList,
      tanggalMulai: formattedMulai,
      tanggalSelesai: formattedSelesai, // 👈 Tambahkan ini agar tanggal selesai masuk ke database
      hariKonsumsi: selectedDays,       // (statusAktif dihapus dari sini)
    );

    if (success) {
      try {
        // Hapus alarm lama (Berdasarkan ID lama/Hashcode)
        await NotificationService().batalkanAlarmObat(
          idObat: widget.jadwal.obat.namaObat.hashCode.abs(),
          hariKonsumsi: ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'], // Hapus semua hari terkait
          jumlahWaktu: 10, // Max arbitrary
        );

        // Buat alarm baru
        await NotificationService().jadwalkanAlarmObat(
          idObat: namaObat.hashCode.abs(),
          namaObat: namaObat,
          hariKonsumsi: selectedDays,
          waktuKonsumsi: _times.whereType<TimeOfDay>().toList(),
        );
      } catch (e) {
        debugPrint("Gagal menyinkronkan alarm edit: $e");
      }

      await _showSuccessPopup();
    } else {
      final errorMsg = ref.read(obatProvider).errorMessage;
      _showMessage(errorMsg ?? 'Gagal memperbarui obat ke server');
    }
  }

  Future<void> _showSuccessPopup() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: Color(0xFF00695C), size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                    'Obat Berhasil\nDiperbarui',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.w900, fontSize: 22, height: 1.2)
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop(true); // Kembali dan trigger refresh
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006699),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))
                    ),
                    child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }
}

// ============================================================================
// WIDGET-WIDGET PENDUKUNG (Sama persis dengan Tambah Obat)
// ============================================================================
class _DayOption {
  final String shortLabel;
  final String longLabel;
  const _DayOption(this.shortLabel, this.longLabel);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.w600));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final String? suffixText;

  const _InputField({required this.controller, required this.hintText, this.focusNode, this.textAlign = TextAlign.left, this.keyboardType, this.suffixText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textAlign: textAlign,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixText: suffixText,
          suffixStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        style: const TextStyle(color: Color(0xFF334155), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFFE8ECEE).withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
      child: child,
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

class _CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final TimeOfDay? minTime;
  final TimeOfDay? maxTime;
  const _CustomTimePickerDialog({required this.initialTime, this.minTime, this.maxTime});
  @override
  State<_CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<_CustomTimePickerDialog> {
  late DateTime _selectedDateTime;
  bool _isInvalid = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateTime = DateTime(now.year, now.month, now.day, widget.initialTime.hour, widget.initialTime.minute);
    _validateTime();
  }

  void _validateTime() {
    bool invalid = false;
    final selectedTime = TimeOfDay(hour: _selectedDateTime.hour, minute: _selectedDateTime.minute);
    if (widget.minTime != null) {
      if (selectedTime.hour < widget.minTime!.hour || (selectedTime.hour == widget.minTime!.hour && selectedTime.minute <= widget.minTime!.minute)) invalid = true;
    }
    if (widget.maxTime != null && !invalid) {
      if (selectedTime.hour > widget.maxTime!.hour || (selectedTime.hour == widget.maxTime!.hour && selectedTime.minute >= widget.maxTime!.minute)) invalid = true;
    }
    setState(() => _isInvalid = invalid);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Pilih Waktu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                Icon(Icons.access_time, color: Color(0xFF4B5563)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: _selectedDateTime,
                onDateTimeChanged: (DateTime newDateTime) {
                  _selectedDateTime = newDateTime;
                  _validateTime();
                },
              ),
            ),
            if (_isInvalid)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: const [
                    Icon(Icons.error, color: Color(0xFFD32F2F), size: 16),
                    SizedBox(width: 6),
                    Expanded(child: Text("Mohon pilih jam secara berurutan", style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: const Text("Batal", style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInvalid ? null : () => Navigator.pop(context, TimeOfDay(hour: _selectedDateTime.hour, minute: _selectedDateTime.minute)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006699), disabledBackgroundColor: Colors.grey.shade400, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  const _CustomCalendarDialog({required this.initialDate});
  @override
  State<_CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<_CustomCalendarDialog> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  final List<String> _weekdays = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekdayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    if (firstWeekdayOffset == 7) firstWeekdayOffset = 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kalender", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMMM yyyy', 'id_ID').format(_currentMonth), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937))),
                Row(
                  children: [
                    InkWell(onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))), child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF006699)))),
                    const SizedBox(width: 8),
                    InkWell(onTap: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))), child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF006699)))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: _weekdays.map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF)))))).toList()),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: daysInMonth + firstWeekdayOffset,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemBuilder: (context, index) {
                if (index < firstWeekdayOffset) return const SizedBox.shrink();
                int day = index - firstWeekdayOffset + 1;
                DateTime thisDate = DateTime(_currentMonth.year, _currentMonth.month, day);
                bool isSelected = _selectedDate.year == thisDate.year && _selectedDate.month == thisDate.month && _selectedDate.day == thisDate.day;
                return InkWell(
                  onTap: () => setState(() => _selectedDate = thisDate),
                  child: Container(
                    decoration: BoxDecoration(color: isSelected ? const Color(0xFF006699) : Colors.transparent, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(day.toString(), style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF4B5563), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text("Batal", style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.w700)))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, _selectedDate), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006699), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}