import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';

class InputLabScreen extends ConsumerStatefulWidget {
  const InputLabScreen({super.key});

  @override
  ConsumerState<InputLabScreen> createState() => _InputLabScreenState();
}

class _InputLabScreenState extends ConsumerState<InputLabScreen> {
  final _formKey = GlobalKey<FormState>();

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

  // ✅ TRAb Controllers
  final _trabValCtrl = TextEditingController();
  final _trabMinCtrl = TextEditingController(); // Batas Negatif
  final _trabMaxCtrl = TextEditingController(); // Batas Positif

  final List<String> _unitOptions = ['mIU/L', 'μIU/mL', 'pmol/L', 'ng/dL', 'pg/mL'];
  String _selectedUnitTSH = 'μIU/mL';
  String _selectedUnitFT4 = 'ng/dL';
  String _selectedUnitFT3 = 'pg/mL';

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime tempSelectedDate = _dateController.text.isNotEmpty
        ? (DateTime.tryParse(_dateController.text) ?? DateTime.now())
        : DateTime.now();

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
                    const Text("Kalender", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: Colors.grey, size: 24),
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
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempSelectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
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
                          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Batal", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, tempSelectedDate),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text("Simpan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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

  void _simpanDataLab() async {
    // 1. Cek validasi form bawaan (untuk tanggal periksa)
    if (!_formKey.currentState!.validate()) return;

    // 2. VALIDASI WAJIB: Hanya TSHs yang wajib diisi!
    if (_tshValCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal disimpan! Parameter TSHs wajib diisi."),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // Hentikan proses simpan
    }

    final user = ref.read(userProvider).user;
    if (user == null) return;

    List<Map<String, dynamic>> parameters = [];

    // ✅ TSH - menggunakan nilai_batas_bawah & nilai_batas_atas
    if (_tshValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "TSH",
        "nilai_hasil": _parseSafeDouble(_tshValCtrl.text, 0.0),
        "satuan": _selectedUnitTSH,
        "kategori": "Thyroid",
        "nilai_batas_bawah": _parseSafeDouble(_tshMinCtrl.text, 0.35),
        "nilai_batas_atas": _parseSafeDouble(_tshMaxCtrl.text, 4.94),
      });
    }

    // ✅ FT4 (Sekarang Opsional)
    if (_ft4ValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "FT4",
        "nilai_hasil": _parseSafeDouble(_ft4ValCtrl.text, 0.0),
        "satuan": _selectedUnitFT4,
        "kategori": "Thyroid",
        "nilai_batas_bawah": _parseSafeDouble(_ft4MinCtrl.text, 0.70),
        "nilai_batas_atas": _parseSafeDouble(_ft4MaxCtrl.text, 1.48),
      });
    }

    // ✅ FT3
    if (_ft3ValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "FT3",
        "nilai_hasil": _parseSafeDouble(_ft3ValCtrl.text, 0.0),
        "satuan": _selectedUnitFT3,
        "kategori": "Thyroid",
        "nilai_batas_bawah": _parseSafeDouble(_ft3MinCtrl.text, 1.71),
        "nilai_batas_atas": _parseSafeDouble(_ft3MaxCtrl.text, 3.71),
      });
    }

    // ✅ TRAb
    if (_trabValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "TRAb",
        "nilai_hasil": _parseSafeDouble(_trabValCtrl.text, 0.0),
        "satuan": "IU/L",
        "kategori": "Thyroid",
        "nilai_batas_bawah": _parseSafeDouble(_trabMinCtrl.text, 0.0),
        "nilai_batas_atas": _parseSafeDouble(_trabMaxCtrl.text, 2.0),
      });
    }

    final payload = {
      "id_user": user.idUser,
      "tgl_periksa": _dateController.text,
      "nama_lab": _labController.text.isNotEmpty ? _labController.text : "Laboratorium Klinik",
      "parameters": parameters,
    };

    final success = await ref.read(monitoringProvider.notifier).simpanHasilLab(payload);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hasil lab berhasil disimpan!"), backgroundColor: AppColors.normalGreen),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(monitoringProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FB),
      appBar: AppBar(
        title: const Text("Tambah Data Hormon", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: monitorState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Tambah Data Hormon", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                "Masukkan hasil laboratorium terbaru Anda. (Data parameter TSHs wajib diisi)",
                style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 24),

              _buildMainCard(),
              const SizedBox(height: 16),
              _buildHormoneSection(
                title: "TSHs",
                sub: "Thyroid Stimulating Hormone-sensitive",
                valCtrl: _tshValCtrl,
                minCtrl: _tshMinCtrl,
                maxCtrl: _tshMaxCtrl,
                selectedUnit: _selectedUnitTSH,
                onUnitChanged: (newUnit) => setState(() => _selectedUnitTSH = newUnit!),
                isRequired: true, // 👈 Tandai sebagai wajib
              ),
              const SizedBox(height: 16),
              _buildHormoneSection(
                title: "FT4",
                sub: "Free Thyroxine",
                valCtrl: _ft4ValCtrl,
                minCtrl: _ft4MinCtrl,
                maxCtrl: _ft4MaxCtrl,
                selectedUnit: _selectedUnitFT4,
                onUnitChanged: (newUnit) => setState(() => _selectedUnitFT4 = newUnit!),
                isRequired: false, // 👈 Ubah menjadi false
              ),
              const SizedBox(height: 16),
              _buildHormoneSection(
                title: "FT3",
                sub: "Free Triiodothyronine",
                valCtrl: _ft3ValCtrl,
                minCtrl: _ft3MinCtrl,
                maxCtrl: _ft3MaxCtrl,
                selectedUnit: _selectedUnitFT3,
                onUnitChanged: (newUnit) => setState(() => _selectedUnitFT3 = newUnit!),
                isRequired: false,
              ),
              const SizedBox(height: 16),
              _buildTrabSection(),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _simpanDataLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: const Text("Simpan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget Main Card ────────────────────────────────────────────────
  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          _buildTextField("Nama Lab (Opsional)", _labController, "Contoh: Prodia Pematang Siantar"),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: _buildTextField(
                "Tanggal Pemeriksaan *",
                _dateController,
                "Pilih tanggal",
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

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {IconData? suffixIcon, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryBlue)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.errorRed)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.errorRed)),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey.shade400, size: 20) : null,
          ),
        ),
      ],
    );
  }

  // ── Section TSH/FT4/FT3 ─────────────────────────────────────────────
  Widget _buildHormoneSection({
    required String title,
    required String sub,
    required TextEditingController valCtrl,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required String selectedUnit,
    required ValueChanged<String?> onUnitChanged,
    bool isRequired = false, // 👈 Parameter baru untuk bintang merah
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👈 Tampilkan bintang merah jika wajib diisi
              RichText(
                text: TextSpan(
                  text: title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
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
          const Text("HASIL PEMERIKSAAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 8),
          TextFormField(
            controller: valCtrl,
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                    items: _unitOptions.map((String val) {
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

  // ── Section TRAb ────────────────────────────────────────────────────
  Widget _buildTrabSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TRAb", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text("Thyroid Hormone Receptor Antibody", style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
            ],
          ),
          const SizedBox(height: 20),
          const Text("HASIL PEMERIKSAAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}