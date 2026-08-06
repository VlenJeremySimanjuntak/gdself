import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ Import disk cache
import '../../home/providers/user_provider.dart';
import '../providers/profile_provider.dart';
import '../../../core/widgets/app_status_dialog.dart';

class EditProfileColors {
  static const Color background = Color(0xFFF8FAFF);
  static const Color primaryBlue = Color(0xFF005F82);
  static const Color textDark = Color(0xFF263238);
  static const Color inputBg = Color(0xFFE9F0F2);
  static const Color greyText = Color(0xFF546E7A);
}

class EditProfileScreen extends ConsumerStatefulWidget {
  final String currentName;
  final String currentEmail;
  final String currentBirthday;
  final String? currentDiagnosisDate;
  final List<String> currentHealthFocus;
  final String? currentAvatarUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
    required this.currentBirthday,
    this.currentDiagnosisDate,
    required this.currentHealthFocus,
    this.currentAvatarUrl,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late DateTime _selectedBirthday;
  late DateTime _selectedDiagnosisDate;

  bool _isSaving = false;

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(text: widget.currentEmail);

    // Parsing Tanggal Lahir
    try {
      _selectedBirthday = DateFormat('dd MMMM yyyy', 'id_ID').parse(widget.currentBirthday);
    } catch (e) {
      try {
        _selectedBirthday = DateTime.parse(widget.currentBirthday);
      } catch (_) {
        _selectedBirthday = DateTime(2000, 1, 1);
      }
    }

    // Parsing Tanggal Terdiagnosis
    try {
      if (widget.currentDiagnosisDate != null) {
        _selectedDiagnosisDate = DateFormat('dd MMMM yyyy', 'id_ID').parse(widget.currentDiagnosisDate!);
      } else {
        _selectedDiagnosisDate = DateTime(2024, 1, 1);
      }
    } catch (e) {
      try {
        _selectedDiagnosisDate = DateTime.parse(widget.currentDiagnosisDate!);
      } catch (_) {
        _selectedDiagnosisDate = DateTime.now();
      }
    }
  }

  // ✅ LANGKAH C: Precache/warm-up gambar saat layar pertama kali dibentuk
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = widget.currentAvatarUrl;
    // Hanya precache jika URL ada dan user belum memilih gambar baru lokal
    if (url != null && url.isNotEmpty && _selectedImage == null) {
      final headers = ref.read(userProvider).authHeaders;
      final key = ref.read(userProvider).avatarCacheKey;
      precacheImage(
        CachedNetworkImageProvider(
          url,
          headers: headers,
          cacheKey: (key != null && key.isNotEmpty) ? key : null,
        ),
        context,
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 65,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mengambil foto")),
      );
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Ubah Foto Profil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditProfileColors.textDark)),
        message: const Text('Pilih sumber foto Anda', style: TextStyle(fontSize: 12)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Pilih dari Galeri', style: TextStyle(color: EditProfileColors.primaryBlue, fontSize: 16)),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Ambil Foto', style: TextStyle(color: EditProfileColors.primaryBlue, fontSize: 16)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context, DateTime initialDate, Function(DateTime) onChanged) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8F8F8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Selesai")),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simpanProfil() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama tidak boleh kosong")),
      );
      return;
    }

    final userId = ref.read(userProvider).user?.idUser;
    if (userId == null) return;

    setState(() => _isSaving = true);

    final payload = {
      "nama": _nameController.text.trim(),
      "tgl_lahir": DateFormat('yyyy-MM-dd').format(_selectedBirthday),
      "tgl_terdiagnosis": DateFormat('yyyy-MM-dd').format(_selectedDiagnosisDate),
    };

    bool updateSuccess = await ref.read(profileProvider.notifier).updateProfile(userId, payload);

    if (_selectedImage != null && updateSuccess) {
      updateSuccess = await ref.read(profileProvider.notifier).uploadAvatar(userId, _selectedImage!.path);
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (updateSuccess) {
      ref.read(userProvider.notifier).refreshUser(userId);
    }

    final errorMsg = ref.read(profileProvider).errorMessage;

    AppStatusDialog.show(
      context,
      isSuccess: updateSuccess,
      title: updateSuccess ? "Berhasil!" : "Gagal!",
      message: updateSuccess
          ? "Profil berhasil diperbarui."
          : (errorMsg ?? "Terjadi kesalahan saat menyimpan data."),
      onOk: () {
        Navigator.pop(context);
        if (updateSuccess) {
          Navigator.pop(context, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String initial = widget.currentName.isNotEmpty ? widget.currentName[0].toUpperCase() : '?';

    final authHeaders = ref.watch(userProvider).authHeaders;
    final avatarCacheKey = ref.watch(userProvider).avatarCacheKey;

    return Scaffold(
      backgroundColor: EditProfileColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EditProfileColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Profil", style: TextStyle(color: EditProfileColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3],
            colors: [Color(0xFFE3F4F4), EditProfileColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      _buildAvatarSection(initial, authHeaders, avatarCacheKey),

                      const SizedBox(height: 40),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel("Nama Lengkap"),
                            _buildTextField(_nameController, "Masukkan Nama Lengkap"),

                            const SizedBox(height: 20),
                            _buildInputLabel("Email"),
                            _buildTextField(_emailController, "Email", isReadOnly: true),

                            const SizedBox(height: 20),
                            _buildInputLabel("Tanggal Lahir"),
                            _buildDateTrigger(
                              DateFormat('dd/MM/yyyy').format(_selectedBirthday),
                                  () => _showDatePicker(context, _selectedBirthday, (date) => setState(() => _selectedBirthday = date)),
                            ),

                            const SizedBox(height: 20),
                            _buildInputLabel("Tanggal Terdiagnosis"),
                            _buildDateTrigger(
                              DateFormat('dd/MM/yyyy').format(_selectedDiagnosisDate),
                                  () => _showDatePicker(context, _selectedDiagnosisDate, (date) => setState(() => _selectedDiagnosisDate = date)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionButton("Batal", const Color(0xFFE1EEF2), EditProfileColors.primaryBlue, () {
                        Navigator.pop(context);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _simpanProfil,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EditProfileColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Simpan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ LANGKAH B: Sinkronisasi dengan Disk Cache ProfileScreen
  Widget _buildAvatarSection(String initial, Map<String, String>? headers, String? cacheKey) {
    ImageProvider? imageProvider;

    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (widget.currentAvatarUrl != null && widget.currentAvatarUrl!.isNotEmpty) {
      // 🔧 GANTI: pakai disk cache persis seperti ProfileScreen.
      // URL dibiarkan bersih (tanpa ?v=...) agar matching dengan cache di lemari.
      imageProvider = CachedNetworkImageProvider(
        widget.currentAvatarUrl!,
        headers: headers,
        cacheKey: (cacheKey != null && cacheKey.isNotEmpty) ? cacheKey : null,
      );
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 65,
            backgroundColor: const Color(0xFFE3ECF7),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Text(initial, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF334155)))
                : null,
          ),
        ),
        GestureDetector(
          onTap: () => _showImagePickerOptions(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF42637D),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditProfileColors.greyText)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isReadOnly = false}) {
    return Container(
      decoration: BoxDecoration(color: EditProfileColors.inputBg, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        style: TextStyle(color: isReadOnly ? Colors.black45 : EditProfileColors.textDark, fontSize: 15),
      ),
    );
  }

  Widget _buildDateTrigger(String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: EditProfileColors.inputBg, borderRadius: BorderRadius.circular(16)),
        child: Text(value, style: const TextStyle(color: EditProfileColors.textDark, fontSize: 15)),
      ),
    );
  }

  Widget _buildActionButton(String label, Color bg, Color textColor, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: textColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}