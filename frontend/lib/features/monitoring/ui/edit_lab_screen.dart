import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import '../../../core/widgets/app_status_dialog.dart';

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

  // ✅ Unit options dipisah per hormon seperti di Input Screen
  final List<String> _unitOptionsTSH = ['mIU/L', 'μIU/mL'];
  final List<String> _unitOptionsFT4 = ['pmol/L', 'ng/dL'];
  final List<String> _unitOptionsFT3 = ['pmol/L', 'pg/mL'];

  bool _isSaving = false;

  // ✅ Default unit per hormon
  String _selectedUnitTSH = 'μIU/mL';
  String _selectedUnitFT4 = 'pmol/L';
  String _selectedUnitFT3 = 'pmol/L';

  // Simpan nilai awal untuk deteksi perubahan (dalam bentuk double)
  Map<String, Map<String, double>> _initialValues = {};

  // ✅ Preview nilai setelah konversi (ditampilkan di bawah input)
  String? _previewTSH;
  String? _previewFT4;
  String? _previewFT3;

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

        // Set unit jika sesuai (Pastikan format huruf besar/kecil sesuai list)
        if (key == 'tsh') {
          _selectedUnitTSH = _unitOptionsTSH.contains(unit) ? unit : _unitOptionsTSH.first;
        } else if (key == 'ft4') {
          _selectedUnitFT4 = _unitOptionsFT4.contains(unit) ? unit : _unitOptionsFT4.first;
        } else if (key == 'ft3') {
          _selectedUnitFT3 = _unitOptionsFT3.contains(unit) ? unit : _unitOptionsFT3.first;
        }
      }
    }

    // ✅ Fallback unit disesuaikan ke standar baru
    initParam('tsh', widget.tshData, _tshValCtrl, _tshMinCtrl, _tshMaxCtrl, 'μIU/mL');
    initParam('ft4', widget.ft4Data, _ft4ValCtrl, _ft4MinCtrl, _ft4MaxCtrl, 'pmol/L');
    initParam('ft3', widget.ft3Data, _ft3ValCtrl, _ft3MinCtrl, _ft3MaxCtrl, 'pmol/L');
    initParam('trab', widget.trabData, _trabValCtrl, _trabMinCtrl, _trabMaxCtrl, 'IU/L');

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
  // ✅ KONVERSI SATUAN KE INTERNASIONAL (pmol/L)
  // ============================================================
  double _konversiKeSatuanInternasional(String parameter, double nilai, String satuan) {
    switch (parameter) {
      case 'FT4':
        if (satuan == 'ng/dL') return nilai * 12.87; // ng/dL → pmol/L
        return nilai; // pmol/L sudah internasional
      case 'FT3':
        if (satuan == 'pg/mL') return nilai * 1.536; // pg/mL → pmol/L
        return nilai; // pmol/L sudah internasional
      case 'TSH':
      case 'TSHs':
        return nilai;
      default:
        return nilai;
    }
  }

  String _satuanInternasional(String parameter) {
    switch (parameter) {
      case 'TSH':
      case 'TSHs': return 'μIU/mL';
      case 'FT4':  return 'pmol/L';
      case 'FT3':  return 'pmol/L';
      case 'TRAb': return 'IU/L';
      default:     return '';
    }
  }

  bool _perluKonversi(String parameter, String satuan) {
    if (parameter == 'TSH' || parameter == 'TSHs') return false;
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

  double _parseSafeDouble(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  bool _isValueChanged(String key, double currentVal, double currentMin, double currentMax) {
    if (currentVal == 0.0 && currentMin == 0.0 && currentMax == 0.0) return false;
    final initial = _initialValues[key];
    if (initial == null) return true;
    return (currentVal - initial['value']!).abs() > 0.0001 ||
        (currentMin - initial['min']!).abs() > 0.0001 ||
        (currentMax - initial['max']!).abs() > 0.0001;
  }

  // ✨ Dialog Konfirmasi Persis Seperti Input
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

  Future<void> _simpanPerubahanLab() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mohon lengkapi data yang wajib diisi (*)."),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_tshValCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal disimpan! Parameter TSHs wajib diisi."),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // =========================================================================
    // 🌟 SINKRONISASI VALIDASI ANTI-TREMOR DI SISI FLUTTER (PRE-CHECK)
    // =========================================================================
    bool cekValiditasBatas(String namaHormon, TextEditingController minCtrl, TextEditingController maxCtrl, double defMin, double defMax) {
      final minVal = _parseSafeDouble(minCtrl.text);
      final maxVal = _parseSafeDouble(maxCtrl.text);

      final finalMin = minVal == 0.0 ? defMin : minVal;
      final finalMax = maxVal == 0.0 ? defMax : maxVal;

      if (finalMin > 0 && finalMax > 0 && finalMin >= finalMax) {
        // Dispensasi TRAb
        if (namaHormon == "TRAb" && finalMin == finalMax) {
          return true; // Loloskan!
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal! Rentang rujukan $namaHormon tidak valid (Batas Bawah tidak boleh ≥ Batas Atas)."),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
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

    List<Map<String, dynamic>> updates = [];
    List<Map<String, dynamic>> newParams = [];

    // Helper untuk menambah ke list Update atau Insert
    void addUpdate(String key, int? id, double val, double min, double max,
        double defaultMin, double defaultMax, String satuan) {
      if (val == 0.0) return;

      final double valInt = _konversiKeSatuanInternasional(key.toUpperCase(), val, satuan);
      final double minInt = min != 0 ? _konversiKeSatuanInternasional(key.toUpperCase(), min, satuan) : defaultMin;
      final double maxInt = max != 0 ? _konversiKeSatuanInternasional(key.toUpperCase(), max, satuan) : defaultMax;
      final namaParam = key.toUpperCase() == 'TSH' ? 'TSHs' : key.toUpperCase();

      if (id == null) {
        newParams.add({
          'nama_parameter': namaParam,
          'nilai_hasil': valInt,
          'nilai_batas_bawah': minInt,
          'nilai_batas_atas': maxInt,
          'satuan': _satuanInternasional(key.toUpperCase()),
        });
      } else if (_isValueChanged(key, valInt, minInt, maxInt)) {
        updates.add({
          'id': id,
          'payload': {
            'nilai_hasil': valInt,
            'satuan': _satuanInternasional(key.toUpperCase()),
            'nilai_batas_bawah': minInt,
            'nilai_batas_atas': maxInt,
          }
        });
      }
    }

    // Isi data
    addUpdate('tsh', _tshId, _parseSafeDouble(_tshValCtrl.text), _parseSafeDouble(_tshMinCtrl.text), _parseSafeDouble(_tshMaxCtrl.text), 0.35, 4.94, _selectedUnitTSH);
    addUpdate('ft4', _ft4Id, _parseSafeDouble(_ft4ValCtrl.text), _parseSafeDouble(_ft4MinCtrl.text), _parseSafeDouble(_ft4MaxCtrl.text), 9.0, 19.0, _selectedUnitFT4);
    addUpdate('ft3', _ft3Id, _parseSafeDouble(_ft3ValCtrl.text), _parseSafeDouble(_ft3MinCtrl.text), _parseSafeDouble(_ft3MaxCtrl.text), 2.6, 5.7, _selectedUnitFT3);

    // Perlakuan khusus TRAb saat insert baru
    double minTrab = _parseSafeDouble(_trabMinCtrl.text);
    double maxTrab = _parseSafeDouble(_trabMaxCtrl.text);
    if (_trabValCtrl.text.isNotEmpty && maxTrab != 0.0 && minTrab >= maxTrab) {
      minTrab = 0.0; // Otomatis reset agar lolos jika batas sama
    }
    addUpdate('trab', _trabId, _parseSafeDouble(_trabValCtrl.text), minTrab, maxTrab, 0.0, 2.0, "IU/L");

    if (updates.isEmpty && newParams.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada perubahan yang disimpan.")));
      return;
    }

    try {
      final notifier = ref.read(monitoringProvider.notifier);
      bool allSuccess = true;

      for (var update in updates) {
        if (!await notifier.editHasilLab(update['id'], update['payload'], user.idUser)) {
          allSuccess = false; break;
        }
      }

      if (allSuccess && newParams.isNotEmpty) {
        allSuccess = await notifier.simpanHasilLab({
          'id_laporan_lab': widget.idLaporanLab,
          'id_user': user.idUser,
          'nama_lab': _labController.text.trim(),
          'tgl_periksa': _dateController.text,
          'parameters': newParams,
        });
      }

      if (allSuccess) {
        final List<Map<String, dynamic>> allParams = [];
        void addParamData(String name, TextEditingController v, String u, double dMin, double dMax, TextEditingController min, TextEditingController max) {
          final val = _parseSafeDouble(v.text);
          if (val == 0.0) return;

          double finalMin = _parseSafeDouble(min.text) != 0 ? _parseSafeDouble(min.text) : dMin;
          double finalMax = _parseSafeDouble(max.text) != 0 ? _parseSafeDouble(max.text) : dMax;

          if (name == 'TRAb' && finalMin >= finalMax && finalMax > 0) {
            finalMin = 0.0;
          }

          allParams.add({
            'nama_parameter': name == 'TSH' ? 'TSHs' : name,
            'nilai_hasil': _konversiKeSatuanInternasional(name, val, u),
            'nilai_batas_bawah': _konversiKeSatuanInternasional(name, finalMin, u),
            'nilai_batas_atas': _konversiKeSatuanInternasional(name, finalMax, u),
            'satuan': _satuanInternasional(name),
          });
        }

        addParamData('TSH', _tshValCtrl, _selectedUnitTSH, 0.35, 4.94, _tshMinCtrl, _tshMaxCtrl);
        addParamData('FT4', _ft4ValCtrl, _selectedUnitFT4, 9.0, 19.0, _ft4MinCtrl, _ft4MaxCtrl);
        addParamData('FT3', _ft3ValCtrl, _selectedUnitFT3, 2.6, 5.7, _ft3MinCtrl, _ft3MaxCtrl);
        addParamData('TRAb', _trabValCtrl, 'IU/L', 0.0, 2.0, _trabMinCtrl, _trabMaxCtrl);

        notifier.reassessLab(idLaporanLab: widget.idLaporanLab, parameters: allParams);
      }

      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: allSuccess,
          title: allSuccess ? "Berhasil!" : "Gagal!",
          message: allSuccess ? "Data lab berhasil diperbarui." : "Terjadi kesalahan saat menyimpan data.",
          onOk: () {
            Navigator.pop(context);
            if (allSuccess) Navigator.pop(context, true);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppStatusDialog.show(context, isSuccess: false, title: "Kesalahan", message: "Terjadi kesalahan: $e", onOk: () => Navigator.pop(context));
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
        title: const Text("Edit Data Hormon", style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
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
              const Text("Edit Data Hormon", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text(
                "Perbarui hasil laboratorium Anda untuk memantau perkembangan kesehatan tiroid secara berkala. (Data parameter TSHs wajib diisi)",
                style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.5),
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
                onUnitChanged: (newUnit) => setState(() { _selectedUnitFT3 = newUnit!; _updateState(); }),
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
                onUnitChanged: (newUnit) => setState(() { _selectedUnitFT4 = newUnit!; _updateState(); }),
                preview: _previewFT4,
              ),
              const SizedBox(height: 16),

              // ✅ 3. TSHs di urutan ketiga
              _buildHormoneSection(
                title: "TSHs",
                sub: "Thyroid Stimulating Hormone-sensitive",
                valCtrl: _tshValCtrl,
                minCtrl: _tshMinCtrl,
                maxCtrl: _tshMaxCtrl,
                unitOptions: _unitOptionsTSH,
                selectedUnit: _selectedUnitTSH,
                onUnitChanged: (newUnit) => setState(() { _selectedUnitTSH = newUnit!; _updateState(); }),
                isRequired: true,
                preview: _previewTSH,
              ),
              const SizedBox(height: 16),

              // ✅ 4. TRAb tetap di posisi terakhir
              _buildTrabSection(),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _simpanPerubahanLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                    shadowColor: AppColors.primaryBlue.withOpacity(0.4),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Simpan Perubahan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          _buildTextField(
            "Nama Lab",
            _labController,
            "Nama Lab",
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama Lab wajib diisi';
              }
              return null;
            },
          ),
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

  Widget _buildHormoneSection({
    required String title,
    required String sub,
    required TextEditingController valCtrl,
    required TextEditingController minCtrl,
    required TextEditingController maxCtrl,
    required List<String> unitOptions, // ✅ Menerima Unit List yang sesuai
    required String selectedUnit,
    required ValueChanged<String?> onUnitChanged,
    bool isRequired = false,
    String? preview,
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
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TRAb", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text("Thyrotropin Receptor Antibodies", style: TextStyle(fontSize: 10, color: AppColors.textGrey)),
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