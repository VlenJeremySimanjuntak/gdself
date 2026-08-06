import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../models/usg_tiroid_model.dart';
import '../../../services/api_service.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import '../../../core/widgets/app_status_dialog.dart';
import 'package:flutter/cupertino.dart';

class EditUsgScreen extends ConsumerStatefulWidget {
  final UsgTiroidModel usg;
  const EditUsgScreen({super.key, required this.usg});

  @override
  ConsumerState<EditUsgScreen> createState() => _EditUsgScreenState();
}

class _EditUsgScreenState extends ConsumerState<EditUsgScreen> {
  final TextEditingController _rsController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  DateTime? _selectedDate;
  File? _imageFile;
  bool _isLoading = false;
  bool _isImageChanged = false;

  final Color _primaryBlue = const Color(0xFF00618A);
  final Color _inputBgColor = const Color(0xFFE6EFEA);
  final Color _textColor = const Color(0xFF2D3748);

  @override
  void initState() {
    super.initState();
    _rsController.text = widget.usg.namaRs;
    _selectedDate = widget.usg.tglPemeriksaan;
    _catatanController.text = widget.usg.catatanDokter ?? '';
  }

  @override
  void dispose() {
    _rsController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // ✅ METHOD UPDATE (tidak diubah)
  // ------------------------------------------------------------
  Future<void> _update() async {
    // 1. Validasi
    if (_rsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama rumah sakit harus diisi')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanggal pemeriksaan harus dipilih')),
      );
      return;
    }

    // 2. Set loading lokal (tidak merusak UI global)
    setState(() => _isLoading = true);

    try {
      final usgId = widget.usg.idUsg;
      if (usgId == null) throw Exception('ID USG tidak ditemukan');

      final formData = FormData.fromMap({
        'nama_rs': _rsController.text.trim(),
        'tgl_pemeriksaan': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'catatan_dokter': _catatanController.text.trim(),
      });

      if (_imageFile != null && _isImageChanged) {
        formData.files.add(
          MapEntry(
            'foto',
            await MultipartFile.fromFile(_imageFile!.path),
          ),
        );
      }

      final response = await ApiService().sendRequest.put(
        '/usg-tiroid/$usgId',
        data: formData,
      );

      final bool success = response.statusCode == 200;

      if (success) {
        // Refresh background data
        _refreshData();
      }

      // ✅ Tampilkan AppStatusDialog sebagai pengganti SnackBar
      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: success,
          title: success ? "Berhasil!" : "Gagal!",
          message: success
              ? "Data USG berhasil diperbarui."
              : "Terjadi kesalahan saat memperbarui data.",
          onOk: () {
            Navigator.pop(context); // Tutup dialog
            if (success) Navigator.pop(context, true); // Tutup layar edit
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Kesalahan",
          message: "Terjadi kesalahan: ${e.toString()}",
          onOk: () => Navigator.pop(context),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------
  // 🔄 Refresh data background (tanpa await agar tidak memblokir UI)
  // ------------------------------------------------------------
  void _refreshData() {
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
    }
  }

  // ------------------------------------------------------------
  // Helper lain (pickDate, pickImage, build widget, dll)
  // ------------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryBlue,
              onPrimary: Colors.white,
              onSurface: _textColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ✅ FUNGSI PICK IMAGE (Pop-up Galeri / Kamera)
  void _pickImage() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
            'Unggah Foto USG',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textColor,
            )
        ),
        message: const Text(
            'Pilih sumber foto Anda',
            style: TextStyle(fontSize: 12)
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _getImage(ImageSource.gallery);
            },
            child: Text(
                'Pilih dari Galeri',
                style: TextStyle(color: _primaryBlue, fontSize: 16)
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _getImage(ImageSource.camera);
            },
            child: Text(
                'Ambil Foto',
                style: TextStyle(color: _primaryBlue, fontSize: 16)
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text(
              'Batal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        // ✅ imageQuality DIHAPUS agar detail foto USG (citra medis) tetap tajam 100%
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isImageChanged = true; // Menandai bahwa foto diganti
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildInputContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _inputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: child,
    );
  }

  // 🔧 DIUBAH: URL foto sekarang mengarah ke endpoint ber-JWT (bukan path statis /uploads).
  // Edit view = tampilkan ORIGINAL (full-res) via GET /api/usg-tiroid/:id/foto.
  String _getFotoUrl() {
    final usgId = widget.usg.idUsg;
    final fotoPath = widget.usg.fotoPath;
    if (usgId == null || fotoPath == null || fotoPath.isEmpty) return '';
    String baseUrl = ApiService().sendRequest.options.baseUrl; // sudah termasuk ".../api"
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/usg-tiroid/$usgId/foto';
  }

  @override
  Widget build(BuildContext context) {
    // 🔧 DITAMBAH: watch userProvider untuk header auth (JWT + ngrok-skip).
    final authHeaders = ref.watch(userProvider).authHeaders;
    final existingImageUrl = _getFotoUrl();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFA),
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Edit USG Tiroid',
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFE0F2F1), Color(0xFFF8FBFA)],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF006699)))
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit USG Tiroid',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Perbarui data hasil USG Anda.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Edit USG',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textColor),
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Nama Rumah Sakit'),
                      _buildInputContainer(
                        child: TextField(
                          controller: _rsController,
                          style: TextStyle(fontSize: 13, color: _textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Rumah Sakit',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Tanggal Pemeriksaan'),
                      GestureDetector(
                        onTap: _pickDate,
                        child: _buildInputContainer(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDate != null
                                      ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                                      : 'mm/dd/yyyy',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _selectedDate != null ? _textColor : Colors.grey.shade500,
                                  ),
                                ),
                                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade500),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Foto USG'),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: (_imageFile != null || existingImageUrl.isNotEmpty)
                                ? Colors.transparent
                                : const Color(0xFFF1F6F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_imageFile != null || existingImageUrl.isNotEmpty)
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                              : existingImageUrl.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              existingImageUrl,
                              // 🔧 DITAMBAH: header JWT + ngrok-skip agar tidak 401.
                              headers: authHeaders,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFFE2E8F0),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Color(0xFF006699)),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE2E8F0),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 48, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 8),
                                      Text(
                                        'Gambar tidak tersedia',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE4EFED),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Color(0xFF00796B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Klik untuk ganti foto',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Catatan Dokter / Deskripsi'),
                      _buildInputContainer(
                        child: TextField(
                          controller: _catatanController,
                          maxLines: 3,
                          style: TextStyle(fontSize: 13, color: _textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Masukkan Teks',
                            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _update,
                    icon: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    label: Text(
                      _isLoading ? 'Menyimpan...' : 'Perbarui Data USG',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}