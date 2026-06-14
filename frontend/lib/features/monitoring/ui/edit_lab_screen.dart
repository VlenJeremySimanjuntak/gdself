import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👇 Wajib untuk TextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';

class EditLabScreen extends ConsumerStatefulWidget {
  final int idLaporanLab; // ID Laporan yang akan diedit ke Backend
  final String tanggal;
  final String namaLab;
  final Map<String, dynamic>? tshData;
  final Map<String, dynamic>? ft4Data;
  final Map<String, dynamic>? ft3Data;

  const EditLabScreen({
    super.key,
    required this.idLaporanLab,
    required this.tanggal,
    required this.namaLab,
    this.tshData,
    this.ft4Data,
    this.ft3Data,
  });

  @override
  ConsumerState<EditLabScreen> createState() => _EditLabScreenState();
}

class _EditLabScreenState extends ConsumerState<EditLabScreen> {
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

  final List<String> _unitOptions = ['mIU/L', 'μIU/mL', 'pmol/L', 'ng/dL', 'pg/mL'];
  String _selectedUnitTSH = 'μIU/mL';
  String _selectedUnitFT4 = 'ng/dL';
  String _selectedUnitFT3 = 'pg/mL';

  @override
  void initState() {
    super.initState();
    // MENGISI OTOMATIS (PRE-FILL) DATA LAMA KE DALAM FORM
    _dateController.text = widget.tanggal;
    _labController.text = widget.namaLab;

    if (widget.tshData != null) {
      _tshValCtrl.text = widget.tshData!['val']?.toString() ?? "";
      _tshMinCtrl.text = widget.tshData!['min']?.toString() ?? "";
      _tshMaxCtrl.text = widget.tshData!['max']?.toString() ?? "";
      _selectedUnitTSH = widget.tshData!['satuan'] ?? 'μIU/mL';
    }
    if (widget.ft4Data != null) {
      _ft4ValCtrl.text = widget.ft4Data!['val']?.toString() ?? "";
      _ft4MinCtrl.text = widget.ft4Data!['min']?.toString() ?? "";
      _ft4MaxCtrl.text = widget.ft4Data!['max']?.toString() ?? "";
      _selectedUnitFT4 = widget.ft4Data!['satuan'] ?? 'ng/dL';
    }
    if (widget.ft3Data != null) {
      _ft3ValCtrl.text = widget.ft3Data!['val']?.toString() ?? "";
      _ft3MinCtrl.text = widget.ft3Data!['min']?.toString() ?? "";
      _ft3MaxCtrl.text = widget.ft3Data!['max']?.toString() ?? "";
      _selectedUnitFT3 = widget.ft3Data!['satuan'] ?? 'pg/mL';
    }

    _tshValCtrl.addListener(_updateState);
    _ft4ValCtrl.addListener(_updateState);
    _ft3ValCtrl.addListener(_updateState);
  }

  @override
  void dispose() {
    _tshValCtrl.removeListener(_updateState);
    _ft4ValCtrl.removeListener(_updateState);
    _ft3ValCtrl.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    setState(() {});
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime tempSelectedDate = DateTime.tryParse(_dateController.text) ?? DateTime.now();

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

  // 👇 Fungsi kebal error koma (,)
  double _parseSafeDouble(String value, double fallback) {
    if (value.isEmpty) return fallback;
    return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
  }

  void _simpanPerubahanLab() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(userProvider).user;
    if (user == null) return;

    List<Map<String, dynamic>> parameters = [];

    if (_tshValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "TSH",
        "satuan": _selectedUnitTSH,
        "kategori": "Thyroid",
        "nilai": _parseSafeDouble(_tshValCtrl.text, 0.0),
        "rujukan_min": _parseSafeDouble(_tshMinCtrl.text, 0.35),
        "rujukan_max": _parseSafeDouble(_tshMaxCtrl.text, 4.94),
      });
    }

    if (_ft4ValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "FT4",
        "satuan": _selectedUnitFT4,
        "kategori": "Thyroid",
        "nilai": _parseSafeDouble(_ft4ValCtrl.text, 0.0),
        "rujukan_min": _parseSafeDouble(_ft4MinCtrl.text, 0.70),
        "rujukan_max": _parseSafeDouble(_ft4MaxCtrl.text, 1.48),
      });
    }

    if (_ft3ValCtrl.text.isNotEmpty) {
      parameters.add({
        "nama_parameter": "FT3",
        "satuan": _selectedUnitFT3,
        "kategori": "Thyroid",
        "nilai": _parseSafeDouble(_ft3ValCtrl.text, 0.0),
        "rujukan_min": _parseSafeDouble(_ft3MinCtrl.text, 1.71),
        "rujukan_max": _parseSafeDouble(_ft3MaxCtrl.text, 3.71),
      });
    }

    if (parameters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mohon isi minimal satu hasil lab.")),
      );
      return;
    }

    final payload = {
      "id_user": user.idUser,
      "tgl_periksa": _dateController.text,
      "nama_lab": _labController.text.isNotEmpty ? _labController.text : "Laboratorium Klinik",
      "parameters": parameters,
    };

    final success = await ref.read(monitoringProvider.notifier).editHasilLab(widget.idLaporanLab, payload, user.idUser);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perubahan berhasil disimpan!")),
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
        title: const Text("Edit Data Hormon", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
              const Text("Edit Data Hormon", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                "Perbarui hasil laboratorium yang salah untuk memastikan tren kesehatan tiroid Anda tetap akurat.",
                style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
              ),
              const SizedBox(height: 24),

              _buildMainCard(),
              const SizedBox(height: 16),
              _buildHormoneSection(
                title: "TSH",
                sub: "Thyroid Stimulating Hormone",
                valCtrl: _tshValCtrl,
                minCtrl: _tshMinCtrl,
                maxCtrl: _tshMaxCtrl,
                selectedUnit: _selectedUnitTSH,
                onUnitChanged: (newUnit) => setState(() => _selectedUnitTSH = newUnit!),
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
                isLast: true,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _simpanPerubahanLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: const Text("Simpan Perubahan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        children: [
          _buildTextField("Nama Lab", _labController, "Contoh: Prodia Balige"),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: _buildTextField("Tanggal Pemeriksaan", _dateController, "", suffixIcon: Icons.calendar_month_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {IconData? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryBlue)),
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey.shade400, size: 20) : null,
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
    required String selectedUnit,
    required ValueChanged<String?> onUnitChanged,
    bool isLast = false,
  }) {
    bool isFilled = valCtrl.text.isNotEmpty;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.normalGreen.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: isFilled ? AppColors.normalGreen : Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      isFilled ? "TERISI" : "BELUM DIISI",
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isFilled ? AppColors.normalGreen : Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),

          const Text("HASIL PEMERIKSAAN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textGrey)),
          const SizedBox(height: 8),

          TextFormField(
            controller: valCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // 👇 Ganti koma ke titik
            inputFormatters: [
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
                    dropdownColor: Colors.white, // 👇 Warna dropdown putih
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
              Expanded(child: _buildRangeInput("BATAS TERENDAH", minCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildRangeInput("BATAS TERTINGGI", maxCtrl)),
            ],
          ),

          if (isLast) ...[
            const SizedBox(height: 16),
            const Text(
              "*Pastikan nilai rujukan sudah sesuai dengan lembar hasil lab Anda.",
              style: TextStyle(fontSize: 9, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ]
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
          // 👇 Ganti koma ke titik
          inputFormatters: [
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