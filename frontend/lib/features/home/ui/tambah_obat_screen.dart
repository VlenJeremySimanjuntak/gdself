import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/obat_model.dart';
import '../../home/providers/user_provider.dart';
import '../providers/obat_provider.dart';
import '../../../services/notification_service.dart';

// Class Draft untuk passing data ke popup
class ObatScheduleDraft {
  final int? idObat;
  final String namaObat;
  final String dosis;
  final DateTime tanggalMulai;
  final List<String> hariTerpilih;
  final List<TimeOfDay> waktuKonsumsi;

  const ObatScheduleDraft({
    this.idObat,
    required this.namaObat,
    required this.dosis,
    required this.tanggalMulai,
    required this.hariTerpilih,
    required this.waktuKonsumsi,
  });
}

class TambahObatScreen extends StatelessWidget {
  const TambahObatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ObatScheduleForm(
      title: 'Tambah Obat',
      primaryButtonLabel: 'Simpan Jadwal Obat',
    );
  }
}

class ObatScheduleForm extends ConsumerStatefulWidget {
  final String title;
  final String primaryButtonLabel;

  const ObatScheduleForm({
    super.key,
    required this.title,
    required this.primaryButtonLabel,
  });

  @override
  ConsumerState<ObatScheduleForm> createState() => _ObatScheduleFormState();
}

class _ObatScheduleFormState extends ConsumerState<ObatScheduleForm> {
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
    _DayOption('S', 'Senin'),
    _DayOption('S', 'Selasa'),
    _DayOption('R', 'Rabu'),
    _DayOption('K', 'Kamis'),
    _DayOption('J', 'Jumat'),
    _DayOption('S', 'Sabtu'),
    _DayOption('M', 'Minggu'),
  ];

  late DateTime _tanggalMulai;
  late List<bool> _selectedDays;
  late List<TimeOfDay?> _times;

  @override
  void initState() {
    super.initState();
    _tanggalMulai = DateTime.now();
    _selectedDays = List<bool>.filled(_days.length, false);
    _times = [];
  }

  @override
  void dispose() {
    _namaObatController.dispose();
    _dosisController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF005F82);
    final obatState = ref.watch(obatProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FBFF), Color(0xFFF4F7FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(left: -90, top: 120, child: _GlowBubble(color: const Color(0xFFB5F0DA).withOpacity(0.35), size: 210)),
              Positioned(right: -100, top: 0, child: _GlowBubble(color: const Color(0xFFB8D9FF).withOpacity(0.25), size: 230)),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: themeBlue),
                        ),
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFE3ECF7),
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=vlen'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          Text(widget.title, style: const TextStyle(fontSize: 32, height: 1.05, fontWeight: FontWeight.w800, color: Color(0xFF2F3B42), letterSpacing: -0.7)),
                          const SizedBox(height: 32),
                          _FormCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Expanded(child: _SectionLabel('NAMA OBAT')),
                                    SizedBox(width: 16),
                                    SizedBox(width: 92, child: _SectionLabel('DOSIS')),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildMedicineAutocomplete()),
                                    const SizedBox(width: 16),
                                    SizedBox(width: 92, child: _buildDosageField()),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const _SectionLabel('TANGGAL MULAI'),
                                const SizedBox(height: 8),
                                _buildDatePickerField(context),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text('JADWAL MINGGUAN', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
                          const SizedBox(height: 8),
                          _buildWeeklyScheduleCard(),
                          const SizedBox(height: 22),
                          const Text('WAKTU KONSUMSI', style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
                          const SizedBox(height: 8),
                          if (_times.isEmpty)
                            _buildEmptyTimeState()
                          else
                            ..._times.asMap().entries.map((entry) => _buildTimeSlot(entry.key, entry.value)),
                          const SizedBox(height: 10),
                          _buildAddTimeButton(),
                          const SizedBox(height: 34),
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              onPressed: obatState.isLoading ? null : _saveSchedule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006699), // Diubah sesuai tema Figma baru
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(34)),
                                elevation: 8,
                                shadowColor: const Color(0x33006699),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: obatState.isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_outlined, size: 22),
                                  const SizedBox(width: 12),
                                  Text(widget.primaryButtonLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        if (_namaObatController.text.isNotEmpty && controller.text.isEmpty) {
          controller.text = _namaObatController.text;
        }
        return _InputField(
          controller: controller,
          focusNode: focusNode,
          hintText: 'Nama Obat',
          textInputAction: TextInputAction.next,
          suffixIcon: const Icon(Icons.medication_liquid_outlined, color: Color(0xFF9CA3AF), size: 20),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 48,
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

  Widget _buildDosageField() {
    return _InputField(
      controller: _dosisController,
      hintText: '0',
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      suffixText: 'mg',
      suffixStyle: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
    );
  }

  // 👇 PERUBAHAN: Memanggil Custom Date Picker Dialog
  Widget _buildDatePickerField(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDialog<DateTime>(
          context: context,
          builder: (context) => _CustomCalendarDialog(initialDate: _tanggalMulai),
        );
        if (picked != null) {
          setState(() => _tanggalMulai = picked);
        }
      },
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(
          children: [
            Expanded(
              child: Text(DateFormat('d MMMM yyyy', 'id_ID').format(_tanggalMulai), style: const TextStyle(color: Color(0xFF4B5563), fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.calendar_month_outlined, color: Color(0xFF9CA3AF), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleCard() {
    final allSelected = _selectedDays.isNotEmpty && _selectedDays.every((value) => value);

    return _FormCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
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
            child: const Text('PILIH SEMUA', style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.w800, fontSize: 12)),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_days.length, (index) {
              final day = _days[index];
              final selected = _selectedDays[index];
              return GestureDetector(
                onTap: () => setState(() => _selectedDays[index] = !_selectedDays[index]),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? const Color(0xFF006699) : Colors.white,
                        border: Border.all(color: selected ? const Color(0xFF006699) : const Color(0xFFC5CFDC), width: 1.7),
                      ),
                      alignment: Alignment.center,
                      child: Text(day.shortLabel, style: TextStyle(color: selected ? Colors.white : const Color(0xFF728096), fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    const SizedBox(height: 8),
                    Text(day.longLabel, style: TextStyle(color: selected ? const Color(0xFF006699) : const Color(0xFF8A96A8), fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ),
          if (allSelected) const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildEmptyTimeState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F2F6))),
      child: const Center(child: Text('Belum ada waktu konsumsi', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700, fontSize: 14))),
    );
  }

  // 👇 PERUBAHAN: Memanggil Custom Time Picker Dialog
  Widget _buildTimeSlot(int index, TimeOfDay? time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F2F6)),
        boxShadow: [BoxShadow(color: const Color(0xFF102A43).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Color(0xFFD7ECFF), shape: BoxShape.circle),
            child: const Icon(Icons.access_time_rounded, color: Color(0xFF006699), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Waktu', style: TextStyle(color: Color(0xFF2F3B42), fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Ketuk untuk mengatur', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.2)),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              // Cek batas minimal waktu (waktu sebelumnya)
              TimeOfDay? minTime;
              if (index > 0) minTime = _times[index - 1];

              // Cek batas maksimal waktu (waktu sesudahnya)
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

              if (picked != null) {
                setState(() => _times[index] = picked);
              }
            },
            child: Container(
              width: 96,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFF7FBFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCFE0F2))),
              child: Text(time == null ? '--:--' : _formatTime(time), style: const TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _times.length == 1 ? null : () => setState(() => _times.removeAt(index)),
            icon: const Icon(Icons.delete_outline, color: Color(0xFFE55353), size: 20),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAddTimeButton() {
    return GestureDetector(
      onTap: () => setState(() => _times.add(null)),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: const Color(0xFFD0D8E5), radius: 16),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF006699), size: 22),
              SizedBox(width: 10),
              Text('Tambah Waktu', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    final namaObat = _namaObatController.text.trim();
    final dosis = _dosisController.text.trim();

    final selectedDays = <String>[];
    for (var i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) selectedDays.add(_days[i].longLabel);
    }

    if (namaObat.isEmpty) return _showMessage('Nama obat belum diisi');
    if (dosis.isEmpty) return _showMessage('Dosis belum diisi');
    if (selectedDays.isEmpty) return _showMessage('Pilih minimal satu hari konsumsi');
    if (_times.isEmpty) return _showMessage('Tambahkan minimal satu waktu konsumsi');
    if (_times.any((time) => time == null)) return _showMessage('Lengkapi semua waktu konsumsi terlebih dahulu');

    final user = ref.read(userProvider).user;
    if (user == null || user.idUser == 0) return _showMessage('Session user tidak ditemukan. Silakan login ulang.');

    final formattedDate = DateFormat('yyyy-MM-dd').format(_tanggalMulai);
    final waktuKonsumsiList = _times.whereType<TimeOfDay>().map((time) => _formatTimeForApi(time)).toList();

    final success = await ref.read(obatProvider.notifier).tambahObatDenganJadwal(
      userId: user.idUser,
      namaObat: namaObat,
      dosis: dosis,
      waktuKonsumsi: waktuKonsumsiList,
      tanggalMulai: formattedDate,
      hariKonsumsi: selectedDays,
    );

    if (success) {
      // ========================================================
      // 👇 TAMBAHAN: NYALAKAN ALARM SETELAH SUKSES SIMPAN DB 👇
      // ========================================================
      try {
        await NotificationService().jadwalkanAlarmObat(
          // Menggunakan hashCode sebagai ID unik karena API belum return ID asli
          idObat: namaObat.hashCode.abs(),
          namaObat: namaObat,
          hariKonsumsi: selectedDays,
          waktuKonsumsi: _times.whereType<TimeOfDay>().toList(),
        );
      } catch (e) {
        debugPrint("Gagal menyetel alarm: $e");
      }
      // ========================================================
      // 👆 SAMPAI SINI 👆
      // ========================================================

      final draft = ObatScheduleDraft(
        namaObat: namaObat,
        dosis: dosis,
        tanggalMulai: _tanggalMulai,
        hariTerpilih: selectedDays,
        waktuKonsumsi: _times.whereType<TimeOfDay>().toList(),
      );
      await _showSuccessPopup(draft);
    } else {
      final errorMsg = ref.read(obatProvider).errorMessage;
      _showMessage(errorMsg ?? 'Gagal menyimpan obat ke server');
    }
  }

  Future<void> _showSuccessPopup(ObatScheduleDraft draft) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(color: Color(0xFFE8F7EF), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_outline, color: Color(0xFF118C52), size: 38),
              ),
              const SizedBox(height: 16),
              const Text('Obat Berhasil Ditambahkan', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF2F3B42), fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text('${draft.namaObat} berhasil disimpan dengan ${draft.waktuKonsumsi.length} waktu konsumsi.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.4)),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(draft);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006699), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(TimeOfDay time) {
    // Format AM/PM menyesuaikan gambar
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatTimeForApi(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }
}

// ============================================================================
// CUSTOM TIME PICKER (Sesuai Gambar Figma & Aturan Berurutan)
// ============================================================================
class _CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final TimeOfDay? minTime; // Jam sebelumnya (tidak boleh lebih kecil dari ini)
  final TimeOfDay? maxTime; // Jam sesudahnya (tidak boleh lebih besar dari ini)

  const _CustomTimePickerDialog({
    required this.initialTime,
    this.minTime,
    this.maxTime,
  });

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

    // Cek batas minimal (Harus lebih besar dari minTime)
    if (widget.minTime != null) {
      if (selectedTime.hour < widget.minTime!.hour ||
          (selectedTime.hour == widget.minTime!.hour && selectedTime.minute <= widget.minTime!.minute)) {
        invalid = true;
      }
    }

    // Cek batas maksimal (Harus lebih kecil dari maxTime)
    if (widget.maxTime != null && !invalid) {
      if (selectedTime.hour > widget.maxTime!.hour ||
          (selectedTime.hour == widget.maxTime!.hour && selectedTime.minute >= widget.maxTime!.minute)) {
        invalid = true;
      }
    }

    setState(() {
      _isInvalid = invalid;
    });
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

            // Picker Roda Gigi
            SizedBox(
              height: 120,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false, // Memakai AM/PM
                initialDateTime: _selectedDateTime,
                onDateTimeChanged: (DateTime newDateTime) {
                  _selectedDateTime = newDateTime;
                  _validateTime();
                },
              ),
            ),

            // Peringatan Merah
            if (_isInvalid)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.error, color: Color(0xFFD32F2F), size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Mohon pilih jam dari yang paling awal ke yang paling akhir",
                        style: TextStyle(color: Color(0xFFD32F2F), fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Batal", style: TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInvalid ? null : () {
                      Navigator.pop(context, TimeOfDay(hour: _selectedDateTime.hour, minute: _selectedDateTime.minute));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006699),
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
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

// ============================================================================
// CUSTOM CALENDAR DIALOG (Sesuai Gambar Figma)
// ============================================================================
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

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekdayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    if (firstWeekdayOffset == 7) firstWeekdayOffset = 0; // Minggu jadi 0

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
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF9CA3AF), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(_currentMonth),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: _previousMonth,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: const Icon(Icons.chevron_left, size: 18, color: Color(0xFF006699)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _nextMonth,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF006699)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Header Hari
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _weekdays.map((day) => Expanded(
                child: Center(
                  child: Text(day, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9CA3AF))),
                ),
              )).toList(),
            ),
            const SizedBox(height: 10),

            // Grid Tanggal
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: daysInMonth + firstWeekdayOffset,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekdayOffset) return const SizedBox.shrink();

                int day = index - firstWeekdayOffset + 1;
                DateTime thisDate = DateTime(_currentMonth.year, _currentMonth.month, day);
                bool isSelected = _selectedDate.year == thisDate.year && _selectedDate.month == thisDate.month && _selectedDate.day == thisDate.day;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDate = thisDate);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF006699) : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text("Batal", style: TextStyle(color: Color(0xFF006699), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006699),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
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

// Widget Bawaan Lainnya
class _DayOption {
  final String shortLabel;
  final String longLabel;
  const _DayOption(this.shortLabel, this.longLabel);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5));
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? suffixText;
  final TextStyle? suffixStyle;

  const _InputField({required this.controller, required this.hintText, this.focusNode, this.textAlign = TextAlign.left, this.keyboardType, this.textInputAction, this.suffixIcon, this.suffixText, this.suffixStyle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textAlign: textAlign,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFFB5BDC7), fontSize: 15, fontWeight: FontWeight.w500),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          suffixIcon: suffixIcon,
          suffixText: suffixText,
          suffixStyle: suffixStyle,
        ),
        style: const TextStyle(color: Color(0xFF334155), fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _FormCard({required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: const Color(0xFFF4F8F7), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE3E8EE))),
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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.4;
    const dashWidth = 8.0;
    const dashSpace = 5.0;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}