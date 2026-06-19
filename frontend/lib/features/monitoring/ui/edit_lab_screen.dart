import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';

class EditLabScreen extends ConsumerStatefulWidget {
  final int idLaporanLab;
  final String tanggal;
  final String namaLab;
  final Map<String, dynamic>? tshData;
  final Map<String, dynamic>? ft4Data;
  final Map<String, dynamic>? ft3Data;
  final Map<String, dynamic>? trabData;

  const EditLabScreen({
    super.key,
    required this.idLaporanLab,
    required this.tanggal,
    required this.namaLab,
    this.tshData,
    this.ft4Data,
    this.ft3Data,
    this.trabData,
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

  final _trabValCtrl = TextEditingController();
  final _trabMinCtrl = TextEditingController();
  final _trabMaxCtrl = TextEditingController();

  int? _tshId;
  int? _ft4Id;
  int? _ft3Id;
  int? _trabId;

  final List<String> _unitOptions = ['mIU/L', 'μIU/mL', 'pmol/L', 'ng/dL', 'pg/mL'];
  String _selectedUnitTSH = 'μIU/mL';
  String _selectedUnitFT4 = 'ng/dL';
  String _selectedUnitFT3 = 'pg/mL';

  // Simpan nilai awal untuk deteksi perubahan (dalam bentuk double)
  Map<String, Map<String, double>> _initialValues = {};

  @override
  void initState() {
    super.initState();
    _dateController.text = widget.tanggal;
    _labController.text = widget.namaLab;

    // Fungsi helper untuk inisialisasi
    void initParam(String key, Map<String, dynamic>? data,
        TextEditingController valCtrl, TextEditingController minCtrl,
        TextEditingController maxCtrl, String defaultUnit) {
      if (data != null) {
        final id = data['id'] as int?;
        final val = data['value']?.toString() ?? '';
        final min = data['min']?.toString() ?? '';
        final max = data['max']?.toString() ?? '';
        final unit = data['satuan']?.toString() ?? defaultUnit;

        if (key == 'tsh') _tshId = id;
        else if (key == 'ft4') _ft4Id = id;
        else if (key == 'ft3') _ft3Id = id;
        else if (key == 'trab') _trabId = id;

        valCtrl.text = val;
        minCtrl.text = min;
        maxCtrl.text = max;

        // Simpan nilai awal sebagai double
        _initialValues[key] = {
          'value': double.tryParse(val) ?? 0.0,
          'min': double.tryParse(min) ?? 0.0,
          'max': double.tryParse(max) ?? 0.0,
        };

        // Set unit jika sesuai
        if (key == 'tsh') _selectedUnitTSH = unit;
        else if (key == 'ft4') _selectedUnitFT4 = unit;
        else if (key == 'ft3') _selectedUnitFT3 = unit;
      }
    }

    initParam('tsh', widget.tshData, _tshValCtrl, _tshMinCtrl, _tshMaxCtrl, 'μIU/mL');
    initParam('ft4', widget.ft4Data, _ft4ValCtrl, _ft4MinCtrl, _ft4MaxCtrl, 'ng/dL');
    initParam('ft3', widget.ft3Data, _ft3ValCtrl, _ft3MinCtrl, _ft3MaxCtrl, 'pg/mL');
    initParam('trab', widget.trabData, _trabValCtrl, _trabMinCtrl, _trabMaxCtrl, 'IU/L');

    _tshValCtrl.addListener(_updateState);
    _ft4ValCtrl.addListener(_updateState);
    _ft3ValCtrl.addListener(_updateState);
    _trabValCtrl.addListener(_updateState);

    // Debug: cetak data yang diterima
    print('📥 EditLabScreen diterima:');
    print('  TSH: ${widget.tshData}');
    print('  FT4: ${widget.ft4Data}');
    print('  FT3: ${widget.ft3Data}');
    print('  TRAb: ${widget.trabData}');
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

  void _updateState() {
    setState(() {});
  }

  double _parseSafeDouble(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  bool _isValueChanged(String key, double currentVal, double currentMin, double currentMax) {
    final initial = _initialValues[key];
    if (initial == null) return false;
    return (currentVal - initial['value']!).abs() > 0.0001 ||
        (currentMin - initial['min']!).abs() > 0.0001 ||
        (currentMax - initial['max']!).abs() > 0.0001;
  }

  Future<void> _simpanPerubahanLab() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(userProvider).user;
    if (user == null) return;

    List<Map<String, dynamic>> updates = [];

    // Helper untuk menambahkan update jika berubah dan nilai tidak 0 (atau sesuai kebutuhan)
    void addUpdate(String key, int? id, double val, double min, double max, double defaultMin, double defaultMax) {
      if (id == null) return;
      // Hanya tambahkan jika nilai berubah (dan jika diisi)
      if (_isValueChanged(key, val, min, max)) {
        // Jika nilai 0 dan tidak ada nilai awal, mungkin tidak perlu dikirim?
        // Tapi kita tetap kirim, backend akan menangani.
        updates.add({
          'id': id,
          'payload': {
            'nilai_hasil': val,
            'nilai_batas_bawah': min != 0 ? min : defaultMin,
            'nilai_batas_atas': max != 0 ? max : defaultMax,
          }
        });
      }
    }

    double tshVal = _parseSafeDouble(_tshValCtrl.text);
    double tshMin = _parseSafeDouble(_tshMinCtrl.text);
    double tshMax = _parseSafeDouble(_tshMaxCtrl.text);
    addUpdate('tsh', _tshId, tshVal, tshMin, tshMax, 0.35, 4.94);

    double ft4Val = _parseSafeDouble(_ft4ValCtrl.text);
    double ft4Min = _parseSafeDouble(_ft4MinCtrl.text);
    double ft4Max = _parseSafeDouble(_ft4MaxCtrl.text);
    addUpdate('ft4', _ft4Id, ft4Val, ft4Min, ft4Max, 0.70, 1.48);

    double ft3Val = _parseSafeDouble(_ft3ValCtrl.text);
    double ft3Min = _parseSafeDouble(_ft3MinCtrl.text);
    double ft3Max = _parseSafeDouble(_ft3MaxCtrl.text);
    addUpdate('ft3', _ft3Id, ft3Val, ft3Min, ft3Max, 1.71, 3.71);

    double trabVal = _parseSafeDouble(_trabValCtrl.text);
    double trabMin = _parseSafeDouble(_trabMinCtrl.text);
    double trabMax = _parseSafeDouble(_trabMaxCtrl.text);
    addUpdate('trab', _trabId, trabVal, trabMin, trabMax, 0.0, 2.0);

    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada perubahan yang disimpan.")),
      );
      return;
    }

    // Debug: cetak payload yang akan dikirim
    print('📤 Payload update: $updates');

    setState(() {});
    bool allSuccess = true;
    final notifier = ref.read(monitoringProvider.notifier);

    try {
      for (var update in updates) {
        print('📤 Mengirim PUT /hasil-lab/${update['id']} dengan payload: ${update['payload']}');
        final success = await notifier.editHasilLab(
          update['id'],
          update['payload'],
          user.idUser,
        );
        if (!success) {
          allSuccess = false;
          break;
        }
      }

      if (allSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil diperbarui!"), backgroundColor: AppColors.normalGreen),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Gagal memperbarui beberapa data."), backgroundColor: AppColors.errorRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(monitoringProvider);
    final bool isLoading = monitorState.isLoading;

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
      body: isLoading
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
                "Perbarui hasil laboratorium Anda untuk memantau perkembangan kesehatan tiroid secara berkala.",
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
              ),
              const SizedBox(height: 16),
              _buildTrabSection(),
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
          _buildTextField("Nama Lab", _labController, "Contoh: Prodia Pematang Siantar", readOnly: true),
          const SizedBox(height: 16),
          _buildTextField(
            "Tanggal Pemeriksaan *",
            _dateController,
            "Pilih tanggal",
            suffixIcon: Icons.calendar_month_rounded,
            readOnly: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Tanggal pemeriksaan wajib dipilih';
              }
              return null;
            },
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
        bool readOnly = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          validator: validator,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primaryBlue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
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
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
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