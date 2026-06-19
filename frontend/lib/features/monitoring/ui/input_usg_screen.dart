import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Sesuaikan path import di bawah dengan struktur folder kamu
import '../../../services/api_service.dart';
import '../../home/providers/user_provider.dart';
import '../providers/usg_provider.dart';
import '../../../utils/design_system.dart';

class InputUsgScreen extends ConsumerStatefulWidget {
  const InputUsgScreen({super.key});

  @override
  ConsumerState<InputUsgScreen> createState() => _InputUsgScreenState();
}

class _InputUsgScreenState extends ConsumerState<InputUsgScreen> {
  final TextEditingController _rsController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();
  DateTime? _selectedDate;
  File? _imageFile;

  // --- Warna Kustom Berdasarkan Desain ---
  final Color _primaryBlue = const Color(0xFF00618A); // Warna biru tua tombol/header
  final Color _inputBgColor = const Color(0xFFE6EFEA); // Warna abu-abu kehijauan input
  final Color _textColor = const Color(0xFF2D3748); // Warna teks dark

  // Fungsi untuk simpan data
  Future<void> _simpan() async {
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
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto USG harus diunggah')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyimpan data...'), duration: Duration(seconds: 1)),
    );

    // 1. BUAT RIWAYAT DULU
    final userId = ref.read(userProvider).user?.idUser;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Data User tidak ditemukan')),
      );
      return;
    }

    try {
      final riwayatRes = await ApiService().post('/riwayat', data: {
        'id_user': userId,
        'tanggal': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      final riwayatId = riwayatRes.data['data']['id_riwayat'] ?? 0;
      if (riwayatId == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membuat sesi riwayat')),
          );
        }
        return;
      }

      // 2. SIMPAN USG DENGAN ID RIWAYAT BARU
      final success = await ref.read(usgProvider.notifier).createUsgData(
        idRiwayat: riwayatId,
        namaRs: _rsController.text.trim(),
        tglPemeriksaan: _selectedDate!,
        catatanDokter: _catatanController.text.trim(),
        imageFile: _imageFile!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data USG berhasil disimpan!'),
            backgroundColor: Color(0xFF00695C),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorMsg = ref.read(usgProvider).errorMessage ?? 'Gagal menyimpan data USG';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _rsController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  // --- Komponen Builder untuk Input Field agar rapi ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFA), // Base background color
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          'Unggah USG Tiroid',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryBlue),
      ),
      extendBodyBehindAppBar: true, // Agar gradient full ke atas
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFE0F2F1), // Hijau/cyan muda di pojok kanan atas
              Color(0xFFF8FBFA), // Menyatu ke background bawah
            ],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Section
                const Text(
                  'USG Tiroid',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pastikan Anda mengisi dengan\nbenar.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Card Putih Utama
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
                        'Unggah USG Tiroid',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nama Rumah Sakit
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

                      // Tanggal Pemeriksaan
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

                      // Unggah Foto
                      _buildLabel('Unggah Foto'),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _imageFile != null ? Colors.transparent : const Color(0xFFF1F6F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _imageFile != null ? Colors.transparent : Colors.grey.shade300,
                            ),
                          ),
                          child: _imageFile != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
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
                                child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF00796B), size: 20),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Klik untuk pilih dari Galeri atau Kamera',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Catatan Dokter
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

                // Tombol Simpan (Fixed typo di UI aslinya "Hail" -> "Hasil")
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
                    onPressed: _simpan,
                    icon: const Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Simpan Hasil USG',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
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