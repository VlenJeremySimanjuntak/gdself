import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../../features/home/providers/user_provider.dart';
import '../../../../../utils/design_system.dart';
import '../../../../../services/api_service.dart';
import 'terms_privacy_screen.dart';
import 'login_screen.dart';
import 'otp_verify_screen.dart';
import '../../../core/widgets/app_status_dialog.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isAgreed = false;
  bool _isSendingOTP = false;

  DateTime? _selectedBirthday;
  DateTime? _selectedDiagnosisDate;
  String? _jenisKelamin;

  // ✅ FIX: Membersihkan error dari provider saat halaman registrasi pertama kali dibuka
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _showDatePicker(BuildContext context, bool isBirthday) async {
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
                      if (mounted) {
                        setState(() {
                          if (isBirthday) {
                            _selectedBirthday = tempDate;
                          } else {
                            _selectedDiagnosisDate = tempDate;
                          }
                        });
                      }
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

  Future<void> _handleRegister() async {
    // 1. Validasi Form
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBirthday == null || _selectedDiagnosisDate == null) {
      AppStatusDialog.show(
        context,
        isSuccess: false,
        title: "Peringatan",
        message: "Mohon lengkapi Tanggal Lahir dan Tanggal Terdiagnosis.",
        onOk: () => Navigator.pop(context),
      );
      return;
    }

    if (!_isAgreed) {
      AppStatusDialog.show(
        context,
        isSuccess: false,
        title: "Perhatian",
        message: "Anda harus menyetujui Syarat & Kebijakan Privasi.",
        onOk: () => Navigator.pop(context),
      );
      return;
    }

    // 2. Kirim OTP
    setState(() => _isSendingOTP = true);
    String? errorOTP;
    try {
      await ApiService().sendOTP(_emailController.text.trim(), 'register');
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        errorOTP = e.response!.data['message'] ?? e.response!.data['error'];
      } else {
        errorOTP = "Gagal mengirim OTP: ${e.toString().replaceAll("Exception: ", "")}";
      }
    }
    setState(() => _isSendingOTP = false);

    if (errorOTP != null) {
      if (mounted) {
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Gagal Kirim OTP",
          message: errorOTP,
          onOk: () => Navigator.pop(context),
        );
      }
      return;
    }

    // 3. Verifikasi OTP
    if (!mounted) return;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerifyScreen(
          email: _emailController.text.trim(),
          type: 'register',
          title: 'Verifikasi Email',
          subtitle: 'Masukkan kode OTP yang telah dikirim ke',
        ),
      ),
    );

    if (result == null || result['verified'] != true) return;

    // 4. Proses Pendaftaran (Buat Akun)
    setState(() => _isSendingOTP = true); // Menggunakan flag loading yang sama
    final userNotifier = ref.read(userProvider.notifier);

    final success = await userNotifier.register(
      nama: _namaController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      jenisKelamin: _jenisKelamin!,
      tglLahir: _selectedBirthday!.toIso8601String().split('T')[0],
      tglTerdiagnosis: _selectedDiagnosisDate!.toIso8601String().split('T')[0],
    );

    setState(() => _isSendingOTP = false);

    // 5. Handle Hasil Registrasi dengan AppStatusDialog
    if (mounted) {
      if (success) {
        await _showSuccessDialog();
      } else {
        final authState = ref.read(userProvider);
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Registrasi Gagal",
          message: authState.errorMessage ?? "Terjadi kesalahan saat membuat akun.",
          onOk: () => Navigator.pop(context),
        );
      }
    }
  }

  void _navigateToLoginSmooth() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) =>
      const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: curve));
        return SlideTransition(
            position: animation.drive(tween), child: child);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final authState = ref.watch(userProvider);
    final isLoading = authState.isLoading || _isSendingOTP;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3],
            colors: [AppColors.bgGradientTop, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/graves-logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.monitor_heart,
                          size: 28,
                          color: AppColors.primaryBlue),
                    ),
                    const SizedBox(width: 10),
                    const Text('Graves Disease',
                        style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                  EdgeInsets.symmetric(horizontal: screenWidth * 0.07),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Buat Akun Baru',
                              style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.5)),
                        ),
                        const SizedBox(height: 30),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Nama Lengkap'),
                              _buildTextField(
                                controller: _namaController,
                                hint: 'Masukkan Nama Lengkap',
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Nama lengkap wajib diisi';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Nama minimal 2 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildInputLabel('Email'),
                              _buildTextField(
                                controller: _emailController,
                                hint: 'Masukkan Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Email wajib diisi';
                                  }
                                  if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              _buildInputLabel('Jenis Kelamin'),
                              _buildDropdownJenisKelamin(),
                              const SizedBox(height: 20),

                              _buildInputLabel('Tanggal Lahir'),
                              _buildDateTrigger(
                                _selectedBirthday == null
                                    ? 'dd/mm/yyyy'
                                    : DateFormat('dd/MM/yyyy')
                                    .format(_selectedBirthday!),
                                    () => _showDatePicker(context, true),
                              ),
                              const SizedBox(height: 20),

                              _buildInputLabel('Tanggal Terdiagnosis'),
                              _buildDateTrigger(
                                _selectedDiagnosisDate == null
                                    ? 'dd/mm/yyyy'
                                    : DateFormat('dd/MM/yyyy')
                                    .format(_selectedDiagnosisDate!),
                                    () => _showDatePicker(context, false),
                              ),
                              const SizedBox(height: 20),

                              _buildInputLabel('Kata Sandi'),
                              _buildTextField(
                                controller: _passwordController,
                                hint: '********',
                                isPassword: true,
                                obscureVariable: _obscureText,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password wajib diisi';
                                  }
                                  if (value.length < 6) {
                                    return 'Password minimal 6 karakter';
                                  }
                                  return null;
                                },
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.black26,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                          () => _obscureText = !_obscureText),
                                ),
                              ),
                              const SizedBox(height: 20),

                              _buildInputLabel('Konfirmasi Kata Sandi'),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                hint: '********',
                                isPassword: true,
                                obscureVariable: _obscureConfirmText,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Konfirmasi password wajib diisi';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Password tidak cocok';
                                  }
                                  if (value.length < 6) {
                                    return 'Password minimal 6 karakter';
                                  }
                                  return null;
                                },
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmText
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.black26,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() =>
                                  _obscureConfirmText =
                                  !_obscureConfirmText),
                                ),
                              ),
                              const SizedBox(height: 25),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _isAgreed,
                                      onChanged: (val) =>
                                          setState(() => _isAgreed = val!),
                                      activeColor: AppColors.primaryBlue,
                                      side: const BorderSide(
                                          color: AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                            color: AppColors.textGrey,
                                            fontSize: 13,
                                            height: 1.4),
                                        children: [
                                          const TextSpan(
                                              text: 'Saya setuju dengan '),
                                          TextSpan(
                                            text: 'Syarat & Kebijakan Privasi',
                                            style: const TextStyle(
                                                color: AppColors.primaryBlue,
                                                fontWeight: FontWeight.bold),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                        const TermsPrivacyScreen()));
                                              },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppColors.primaryBlue,
                                        size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Setelah menekan Daftar, kode verifikasi akan dikirim ke email Anda.',
                                        style: TextStyle(
                                            color: AppColors.primaryBlue,
                                            fontSize: 12,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2),
                                  )
                                      : const Text('Daftar',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        if (authState.errorMessage != null &&
                            !authState.isLoading)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.errorRed.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.errorRed, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(authState.errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.errorRed,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Sudah punya akun?',
                                style: TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 14)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                // ✅ FIX: Bersihkan error sebelum kembali ke layar Login
                                ref.read(userProvider.notifier).clearError();
                                Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                        const LoginScreen()));
                              },
                              child: const Text('Masuk',
                                  style: TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textGrey,
            letterSpacing: 0.5)),
  );

  Widget _buildTextField({
    required TextEditingController? controller,
    required String hint,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscureVariable = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) =>
      Container(
        decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(16)),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword ? obscureVariable : false,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(color: Colors.black26, fontSize: 14),
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            errorStyle: const TextStyle(
                color: AppColors.errorRed, fontSize: 12, height: 0.8),
          ),
        ),
      );

  Widget _buildDropdownJenisKelamin() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(16)),
    child: DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        value: _jenisKelamin,
        dropdownColor: Colors.white,
        style: const TextStyle(color: AppColors.textDark, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Pilih Jenis Kelamin',
          hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          errorStyle: TextStyle(
              color: AppColors.errorRed, fontSize: 12, height: 0.8),
        ),
        items: const [
          DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
          DropdownMenuItem(value: 'P', child: Text('Perempuan')),
        ],
        validator: (value) =>
        value == null ? 'Jenis kelamin wajib dipilih' : null,
        onChanged: (value) => setState(() => _jenisKelamin = value),
      ),
    ),
  );

  Widget _buildDateTrigger(String value, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 16),
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

  Future<void> _showSuccessDialog() async {
    if (!mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Pendaftaran Berhasil',
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(
                  vertical: 32, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD9EBDC)),
                    child: const Icon(Icons.check,
                        color: Color(0xFF157F4B), size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text('Pendaftaran Berhasil!',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Mari mulai perjalanan kesehatan Anda.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.black54),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToLoginSmooth();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Mulai',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(
                parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}