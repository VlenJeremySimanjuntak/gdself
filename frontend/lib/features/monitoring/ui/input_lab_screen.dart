import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import '../../../core/widgets/app_status_dialog.dart';
import 'widgets/self_report_kondisi_dialog.dart';

class InputLabScreen extends ConsumerStatefulWidget {
  final KondisiPengguna kondisiSaatIni;

  const InputLabScreen({
    super.key,
    this.kondisiSaatIni = KondisiPengguna.baik,
  });

  @override
  ConsumerState<InputLabScreen> createState() => _InputLabScreenState();
}

class _InputLabScreenState extends ConsumerState<InputLabScreen> {
  final _formKey = GlobalKey<FormState>();
  late final bool _modeSensitifTinggi;

  final _labController = TextEditingController();
  final _dateController = TextEditingController();

  final _tshValCtrl = TextEditingController();
  final _tshMinCtrl = TextEditingController();
  final _tshMaxCtrl = TextEditingController();

  final _ft4ValCtrl = TextEditingController();
  final _ft4MinCtrl = TextEditingController();
  final _ft4MaxCtrl = TextEditingController();

  final _ft3ValCtrl = TextEditingController();
  final _ft3MinCtrl = TextEditingController();
  final _ft3MaxCtrl = TextEditingController();

  final _trabValCtrl = TextEditingController();
  final _trabMinCtrl = TextEditingController();
  final _trabMaxCtrl = TextEditingController();

  // ✅ Unit options dipisah per hormon sesuai satuan klinis yang valid
  final List<String> _unitOptionsTSH = ['mIU/L', 'μIU/mL'];
  final List<String> _unitOptionsFT4 = ['pmol/L', 'ng/dL'];
  final List<String> _unitOptionsFT3 = ['pmol/L', 'pg/mL'];

  // ✅ Default unit per hormon
  String _selectedUnitTSH = 'mIU/L';
  String _selectedUnitFT4 = 'pmol/L';
  String _selectedUnitFT3 = 'pmol/L';

  // ✅ Preview nilai setelah konversi
  String? _previewTSH;
  String? _previewFT4;
  String? _previewFT3;

  // ✅ Loading lokal hanya di tombol
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _modeSensitifTinggi = widget.kondisiSaatIni == KondisiPengguna.tidakNyaman;
    _tshValCtrl.addListener(_updateState);
    _ft4ValCtrl.addListener(_updateState);
    _ft3ValCtrl.addListener(_updateState);
    _trabValCtrl.addListener(_updateState);
  }

  @override
  void dispose() {
    _tshValCtrl.removeListener(_updateState);
    _ft4ValCtrl.removeListener(_updateState);
    _ft3ValCtrl.removeListener(_updateState);
    _trabValCtrl.removeListener(_updateState);
    _labController.dispose();
    _dateController.dispose();
    _tshValCtrl.dispose();
    _tshMinCtrl.dispose();
    _tshMaxCtrl.dispose();
    _ft4ValCtrl.dispose();
    _ft4MinCtrl.dispose();
    _ft4MaxCtrl.dispose();
    _ft3ValCtrl.dispose();
    _ft3MinCtrl.dispose();
    _ft3MaxCtrl.dispose();
    _trabValCtrl.dispose();
    _trabMinCtrl.dispose();
    _trabMaxCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ KONVERSI SATUAN KE INTERNASIONAL
  // ============================================================
  double _konversiKeSatuanInternasional(
      String parameter, double nilai, String satuan) {
    switch (parameter) {
      case 'FT4':
        if (satuan == 'ng/dL') return nilai * 12.87;
        return nilai;
      case 'FT3':
        if (satuan == 'pg/mL') return nilai * 1.536;
        return nilai;
      case 'TSH':
      case 'TSHs': // Taruh case penanganan TSHs di sini
        return nilai;
      default:
        return nilai;
    }
  }

  String _satuanInternasional(String parameter) {
    switch (parameter) {
      case 'TSH':
      case 'TSHs': // Tambahkan di sini
        return 'mIU/L';
      case 'FT4':
        return 'pmol/L';
      case 'FT3':
        return 'pmol/L';
      case 'TRAb':
        return 'IU/L';
      default:
        return '';
    }
  }

  bool _perluKonversi(String parameter, String satuan) {
    return satuan != _satuanInternasional(parameter);
  }

  void _updateState() {
    setState(() {
      _previewTSH = null;

      final ft4Val = double.tryParse(_ft4ValCtrl.text.replaceAll(',', '.'));
      if (ft4Val != null && _perluKonversi('FT4', _selectedUnitFT4)) {
        final converted = _konversiKeSatuanInternasional('FT4', ft4Val, _selectedUnitFT4);
        _previewFT4 = '≈ ${converted.toStringAsFixed(4)} ${_satuanInternasional('FT4')}';
      } else {
        _previewFT4 = null;
      }

      final ft3Val = double.tryParse(_ft3ValCtrl.text.replaceAll(',', '.'));
      if (ft3Val != null && _perluKonversi('FT3', _selectedUnitFT3)) {
        final converted = _konversiKeSatuanInternasional('FT3', ft3Val, _selectedUnitFT3);
        _previewFT3 = '≈ ${converted.toStringAsFixed(4)} ${_satuanInternasional('FT3')}';
      } else {
        _previewFT3 = null;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime now = DateTime.now();

    DateTime tempSelectedDate = _dateController.text.isNotEmpty
        ? (DateTime.tryParse(_dateController.text) ?? now)
        : now;

    if (tempSelectedDate.isAfter(now)) {
      tempSelectedDate = now;
    }

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Kalender",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textDark)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.grey, size: 24),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primaryBlue,
                        onPrimary: Colors.white,
                        onSurface: AppColors.textDark,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryBlue),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempSelectedDate,
                      firstDate: DateTime(2000),
                      lastDate: now,
                      onDateChanged: (DateTime date) {
                        tempSelectedDate = date;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Batal",
                            style: TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, tempSelectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text("Simpan",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  double _parseSafeDouble(String value, double fallback) {
    if (value.isEmpty) return fallback;
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }

  // ✨ METODE BARU: Dialog Validasi Sebelum Menyimpan Data ke Server
  Future<bool> _tampilkanKonfirmasiData(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Periksa Kembali Data",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Apakah Anda yakin seluruh nilai parameter hormon tiroid yang dimasukkan sudah benar? Ketepatan data sangat memengaruhi hasil analisis mesin kecerdasan buatan.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        "Periksa Ulang",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Ya, Sudah Benar",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    return yakin ?? false;
  }

  void _simpanDataLab() async {
    // ✅ DIUBAH: Peringatan jika belum lengkap diubah jadi POP-UP Dialog
    if (!_formKey.currentState!.validate()) {
      AppStatusDialog.show(
        context,
        isSuccess: false,
        title: "Data Belum Lengkap",
        message: "Mohon lengkapi semua kolom yang wajib diisi.",
        onOk: () => Navigator.pop(context),
      );
      return;
    }

    // =========================================================================
    // 🌟 SINKRONISASI VALIDASI ANTI-TREMOR DI SISI FLUTTER (PRE-CHECK)
    // =========================================================================
    bool cekValiditasBatas(String namaHormon, TextEditingController minCtrl, TextEditingController maxCtrl, double defMin, double defMax) {
      final minVal = _parseSafeDouble(minCtrl.text, defMin);
      final maxVal = _parseSafeDouble(maxCtrl.text, defMax);

      if (minVal > 0 && maxVal > 0 && minVal >= maxVal) {
        if (namaHormon == "TRAb" && minVal == maxVal) {
          return true; // Loloskan!
        }
        // Validasi batas juga menggunakan POP-UP
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Rentang Tidak Valid",
          message: "Rentang rujukan $namaHormon tidak valid (Batas Bawah tidak boleh lebih besar atau sama dengan Batas Atas).",
          onOk: () => Navigator.pop(context),
        );
        return false;
      }
      return true;
    }

    // Jalankan validasi lokal sebelum hit ke server
    if (!cekValiditasBatas("TSHs", _tshMinCtrl, _tshMaxCtrl, 0.35, 4.94)) return;
    if (_ft4ValCtrl.text.isNotEmpty && !cekValiditasBatas("FT4", _ft4MinCtrl, _ft4MaxCtrl, 9.0, 19.0)) return;
    if (_ft3ValCtrl.text.isNotEmpty && !cekValiditasBatas("FT3", _ft3MinCtrl, _ft3MaxCtrl, 2.6, 5.7)) return;
    if (_trabValCtrl.text.isNotEmpty && !cekValiditasBatas("TRAb", _trabMinCtrl, _trabMaxCtrl, 0.0, 2.0)) return;

    // =========================================================================

    final dataSudahValid = await _tampilkanKonfirmasiData(context);
    if (!dataSudahValid || !context.mounted) return;

    final user = ref.read(userProvider).user;
    if (user == null) return;

    setState(() => _isSaving = true);

    List<Map<String, dynamic>> parameters = [];

    void addParam(
        String namaParam,
        TextEditingController valCtrl,
        String unit,
        double defaultMin,
        double defaultMax,
        TextEditingController minCtrl,
        TextEditingController maxCtrl) {
      final val = _parseSafeDouble(valCtrl.text, 0.0);
      if (val == 0.0) return;

      final double valInt = _konversiKeSatuanInternasional(namaParam, val, unit);
      final double minVal = _parseSafeDouble(minCtrl.text, 0.0);
      final double maxVal = _parseSafeDouble(maxCtrl.text, 0.0);

      parameters.add({
        "nama_parameter": namaParam, // Menggunakan 'TSH' agar klop dengan check data controller Go
        "nilai_hasil": valInt,
        "satuan": _satuanInternasional(namaParam),
        "kategori": "Thyroid",
        "nilai_batas_bawah": minVal != 0
            ? _konversiKeSatuanInternasional(namaParam, minVal, unit)
            : defaultMin,
        "nilai_batas_atas": maxVal != 0
            ? _konversiKeSatuanInternasional(namaParam, maxVal, unit)
            : defaultMax,
      });
    }

    // Pengiriman parameter disesuaikan dengan key master 'TSH' agar lolos validasi parsial Go
    addParam('TSH', _tshValCtrl, _selectedUnitTSH, 0.35, 4.94, _tshMinCtrl, _tshMaxCtrl);
    addParam('FT4', _ft4ValCtrl, _selectedUnitFT4, 9.0, 19.0, _ft4MinCtrl, _ft4MaxCtrl);
    addParam('FT3', _ft3ValCtrl, _selectedUnitFT3, 2.6, 5.7, _ft3MinCtrl, _ft3MaxCtrl);

    if (_trabValCtrl.text.isNotEmpty) {
      final minTrab = _parseSafeDouble(_trabMinCtrl.text, 0.0);
      final maxTrab = _parseSafeDouble(_trabMaxCtrl.text, 1.75);

      // Jika user mengisi Batas Negatif sama dengan Batas Positif (misal sama-sama 1.75),
      // otomatis set Batas Bawah menjadi 0.0 agar lolos validasi rentang.
      final finalMinTrab = (minTrab >= maxTrab) ? 0.0 : minTrab;

      parameters.add({
        "nama_parameter": "TRAb",
        "nilai_hasil": _parseSafeDouble(_trabValCtrl.text, 0.0),
        "satuan": "IU/L",
        "kategori": "Thyroid",
        "nilai_batas_bawah": finalMinTrab,
        "nilai_batas_atas": maxTrab,
      });
    }

    final payload = {
      "id_user": user.idUser,
      "tgl_periksa": _dateController.text, // Format pendek yyyy-MM-dd aman
      "nama_lab": _labController.text.isNotEmpty ? _labController.text : "Laboratorium Klinik",
      "parameters": parameters,
    };

    try {
      final notifier = ref.read(monitoringProvider.notifier);
      final success = await notifier.simpanHasilLab(payload);

      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: success,
          title: success ? "Berhasil!" : "Gagal!",
          message: success
              ? "Data lab berhasil disimpan."
              : "Terjadi kesalahan, silakan periksa kesesuaian data rujukan lab Anda.",
          onOk: () {
            Navigator.pop(context);
            if (success) Navigator.pop(context);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Kesalahan",
          message: "Terjadi kesalahan koneksi: $e",
          onOk: () => Navigator.pop(context),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: const Text("Tambah Data Hormon",
            style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Tambah Data Hormon",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                "Masukkan hasil laboratorium terbaru Anda. (Data parameter TSHs wajib diisi)",
                style: TextStyle(
                    fontSize: 13, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 24),
              _buildMainCard(),
              const SizedBox(height: 16),

              // ✅ 1. FT3 dipindah ke atas
              _buildHormoneSection(
                title: "FT3",
                sub: "Free Triiodothyronine",
                valCtrl: _ft3ValCtrl,
                minCtrl: _ft3MinCtrl,
                maxCtrl: _ft3MaxCtrl,
                unitOptions: _unitOptionsFT3,
                selectedUnit: _selectedUnitFT3,
                onUnitChanged: (newUnit) => setState(() {
                  _selectedUnitFT3 = newUnit!;
                  _updateState();
                }),
                isRequired: false,
                preview: _previewFT3,
              ),
              const SizedBox(height: 16),

              // ✅ 2. FT4 di urutan kedua
              _buildHormoneSection(
                title: "FT4",
                sub: "Free Thyroxine",
                valCtrl: _ft4ValCtrl,
                minCtrl: _ft4MinCtrl,
                maxCtrl: _ft4MaxCtrl,
                unitOptions: _unitOptionsFT4,
                selectedUnit: _selectedUnitFT4,
                onUnitChanged: (newUnit) => setState(() {
                  _selectedUnitFT4 = newUnit!;
                  _updateState();
                }),
                isRequired: false,
                preview: _previewFT4,
              ),
              const SizedBox(height: 16),

              // ✅ 3. TSHs di urutan ketiga (dengan isRequired: true & validator)
              _buildHormoneSection(
                title: "TSHs",
                sub: "Thyroid Stimulating Hormone-sensitive",
                valCtrl: _tshValCtrl,
                minCtrl: _tshMinCtrl,
                maxCtrl: _tshMaxCtrl,
                unitOptions: _unitOptionsTSH,
                selectedUnit: _selectedUnitTSH,
                onUnitChanged: (newUnit) => setState(() {
                  _selectedUnitTSH = newUnit!;
                  _updateState();
                }),
                isRequired: true,
                preview: _previewTSH,
                // ✅ DITAMBAHKAN VALIDATOR KHUSUS TSHs
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nilai hasil pemeriksaan TSHs wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ✅ 4. TRAb di urutan terakhir
              _buildTrabSection(),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _simpanDataLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text("Simpan",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            "Nama Lab",
            _labController,
            "Nama Lab",
            isRequired: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama Rumah Sakit/Lab wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: _buildTextField(
                "Tanggal Pemeriksaan",
                _dateController,
                "Pilih tanggal",
                isRequired: true,
                suffixIcon: Icons.calendar_month_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Tanggal pemeriksaan wajib dipilih';
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController ctrl,
      String hint, {
        IconData? suffixIcon,
        String? Function(String?)? validator,
        bool isRequired = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.errorRed),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          validator: validator,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primaryBlue)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.errorRed)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.errorRed)),
            suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.grey.shade400, size: 20)
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHormoneSection({
    required String title,
    required String sub,
    required TextEditingController valCtrl,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required List<String> unitOptions,
    required String selectedUnit,
    required ValueChanged<String?> onUnitChanged,
    bool isRequired = false,
    String? preview,
    String? Function(String?)? validator, // ✅ DITAMBAHKAN PARAMETER VALIDATOR
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark),
                  children: [
                    if (isRequired)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: AppColors.errorRed),
                      ),
                  ],
                ),
              ),
              Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("HASIL PEMERIKSAAN",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: valCtrl,
            validator: validator, // ✅ VALIDATOR DITERAPKAN DI SINI
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.replaceAll(',', '.'));
              }),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "0.00",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFFEEF3F6),
              // ✅ BORDER DIUBAH AGAR MENDUKUNG TAMPILAN ERROR MERAH
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primaryBlue)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.errorRed)),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    value: selectedUnit,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
                    alignment: Alignment.centerRight,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    items: unitOptions.map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(val),
                      );
                    }).toList(),
                    onChanged: onUnitChanged,
                  ),
                ),
              ),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF856404)),
                  const SizedBox(width: 8),
                  Text(
                    'Akan disimpan sebagai $preview',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF856404),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildRangeInput("BATAS BAWAH", minCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildRangeInput("BATAS ATAS", maxCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrabSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TRAb",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              Text("Thyrotropin Receptor Antibodies",
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("HASIL PEMERIKSAAN",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _trabValCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              TextInputFormatter.withFunction((oldValue, newValue) {
                return newValue.copyWith(text: newValue.text.replaceAll(',', '.'));
              }),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "0.00",
              hintStyle: TextStyle(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: const Color(0xFFEEF3F6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  "IU/L",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildRangeInput("BATAS NEGATIF", _trabMinCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildRangeInput("BATAS POSITIF", _trabMaxCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              return newValue.copyWith(text: newValue.text.replaceAll(',', '.'));
            }),
          ],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: "0.00",
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFEEF3F6),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}