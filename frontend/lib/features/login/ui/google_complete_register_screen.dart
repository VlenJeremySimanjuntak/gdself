import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';

class GoogleCompleteRegisterScreen extends ConsumerStatefulWidget {
  final String idToken;
  final String googleEmail;
  final String googleName;
  final String googlePhoto;

  const GoogleCompleteRegisterScreen({
    super.key,
    required this.idToken,
    required this.googleEmail,
    required this.googleName,
    required this.googlePhoto,
  });

  @override
  ConsumerState<GoogleCompleteRegisterScreen> createState() =>
      _GoogleCompleteRegisterScreenState();
}

class _GoogleCompleteRegisterScreenState
    extends ConsumerState<GoogleCompleteRegisterScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _jenisKelamin;
  DateTime? _selectedBirthday;
  DateTime? _selectedDiagnosisDate;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showDatePicker(bool isBirthday) async {
    DateTime tempDate =
        (isBirthday ? _selectedBirthday : _selectedDiagnosisDate) ??
            DateTime.now();

    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8F8F8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal',
                        style: TextStyle(color: AppColors.errorRed)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (isBirthday) {
                          _selectedBirthday = tempDate;
                        } else {
                          _selectedDiagnosisDate = tempDate;
                        }
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Selesai',
                        style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (d) => tempDate = d,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validate() {
    if (_passwordController.text.length < 6) {
      return 'Password minimal 6 karakter.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Password tidak cocok.';
    }
    if (_jenisKelamin == null) return 'Jenis kelamin harus dipilih.';
    if (_selectedBirthday == null) return 'Tanggal lahir harus diisi.';
    if (_selectedDiagnosisDate == null) {
      return 'Tanggal terdiagnosis harus diisi.';
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.errorRed),
      );
      return;
    }

    final success = await ref
        .read(userProvider.notifier)
        .completeGoogleRegister(
      idToken: widget.idToken,
      password: _passwordController.text,
      jenisKelamin: _jenisKelamin!,
      tglLahir:
      _selectedBirthday!.toIso8601String().split('T')[0],
      tglTerdiagnosis:
      _selectedDiagnosisDate!.toIso8601String().split('T')[0],
    );

    if (success && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(userProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3],
            colors: [AppColors.bgGradientTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Image.asset('assets/images/graves-logo.png',
                        width: 28, height: 28, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    const Text('Graves disease',
                        style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 32),

                const Text(
                  'Lengkapi Data Anda',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Akun Google Anda terdeteksi sebagai pengguna baru. Lengkapi data berikut untuk melanjutkan.',
                  style: TextStyle(
                      color: AppColors.textGrey, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),

                // Info dari Google (readonly)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: widget.googlePhoto.isNotEmpty
                            ? NetworkImage(widget.googlePhoto)
                            : null,
                        backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                        child: widget.googlePhoto.isEmpty
                            ? Text(
                            widget.googleName.isNotEmpty
                                ? widget.googleName[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.googleName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                    fontSize: 14)),
                            Text(widget.googleEmail,
                                style: const TextStyle(
                                    color: AppColors.textGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified,
                          color: AppColors.primaryBlue, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Form card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Jenis Kelamin
                      _label('Jenis Kelamin'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.inputBg,
                            borderRadius: BorderRadius.circular(16)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _jenisKelamin,
                            isExpanded: true,
                            hint: const Text('Pilih jenis kelamin',
                                style: TextStyle(
                                    color: Colors.black26, fontSize: 14)),
                            items: const [
                              DropdownMenuItem(
                                  value: 'L', child: Text('Laki-laki')),
                              DropdownMenuItem(
                                  value: 'P', child: Text('Perempuan')),
                            ],
                            onChanged: (v) =>
                                setState(() => _jenisKelamin = v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tanggal Lahir
                      _label('Tanggal Lahir'),
                      _dateTrigger(
                        _selectedBirthday == null
                            ? 'dd/mm/yyyy'
                            : DateFormat('dd/MM/yyyy')
                            .format(_selectedBirthday!),
                            () => _showDatePicker(true),
                      ),
                      const SizedBox(height: 20),

                      // Tanggal Terdiagnosis
                      _label('Tanggal Terdiagnosis'),
                      _dateTrigger(
                        _selectedDiagnosisDate == null
                            ? 'dd/mm/yyyy'
                            : DateFormat('dd/MM/yyyy')
                            .format(_selectedDiagnosisDate!),
                            () => _showDatePicker(false),
                      ),
                      const SizedBox(height: 20),

                      // Password
                      _label('Buat Password'),
                      _passwordField(
                        controller: _passwordController,
                        hint: '********',
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Password digunakan agar Anda bisa login dengan email & password di kemudian hari.',
                        style:
                        TextStyle(color: AppColors.textGrey, fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      // Konfirmasi Password
                      _label('Konfirmasi Password'),
                      _passwordField(
                        controller: _confirmPasswordController,
                        hint: '********',
                        obscure: _obscureConfirm,
                        onToggle: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                      ),

                      // Error
                      if (authState.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.errorRed, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(authState.errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.errorRed,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 28),

                      ElevatedButton(
                        onPressed:
                        authState.isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          minimumSize: const Size(double.infinity, 54),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: authState.isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                            : const Text('Selesai & Masuk',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textGrey)),
  );

  Widget _dateTrigger(String value, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value,
              style: TextStyle(
                  color: value == 'dd/mm/yyyy'
                      ? Colors.black26
                      : AppColors.textDark,
                  fontSize: 14)),
          const Icon(Icons.calendar_month_outlined,
              color: Colors.black26, size: 20),
        ],
      ),
    ),
  );

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(16)),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: Colors.black26, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline,
                color: Colors.black26, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.black26,
                  size: 18),
              onPressed: onToggle,
            ),
            border: InputBorder.none,
            contentPadding:
            const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}