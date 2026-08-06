import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../utils/design_system.dart';
import '../../../../../services/api_service.dart';
import 'otp_verify_screen.dart';
import '../../../core/widgets/app_status_dialog.dart';


class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // Step 1: input email
  // Step 2: OTP (delegasi ke OTPVerifyScreen)
  // Step 3: input password baru
  int _step = 1;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  String? _verifiedEmail; // email yang sudah diverifikasi OTP-nya
  String? _verifiedCode;  // ✅ TAMBAHAN: menyimpan kode OTP yang sudah divalidasi

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Step 1: kirim OTP ke email
  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty ||
        !RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _errorMessage = 'Masukkan email yang valid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService().forgotPassword(email);

      if (!mounted) return;

      // ✅ PERBAIKAN: Mengambil Map dari Navigator.push
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => OTPVerifyScreen(
            email: email,
            type: 'reset_password',
            title: 'Verifikasi Email',
            subtitle: 'Masukkan kode OTP yang telah dikirim ke',
          ),
        ),
      );

      // ✅ PERBAIKAN: Ekstrak status 'verified' dan 'code'
      if (result != null && result['verified'] == true && mounted) {
        setState(() {
          _verifiedEmail = email;
          _verifiedCode = result['code'] as String; // Simpan kode OTP untuk dikirim saat reset password
          _step = 3;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // Step 3: reset password
  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Password tidak cocok.');
      return;
    }

    if (_verifiedEmail == null || _verifiedCode == null) {
      setState(() => _errorMessage = 'Sesi verifikasi tidak valid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService().resetPassword(
        email: _verifiedEmail!,
        code: _verifiedCode!,
        newPassword: password,
      );

      if (mounted) {
        // ✅ Ganti dialog manual dengan AppStatusDialog
        AppStatusDialog.show(
          context,
          isSuccess: true,
          title: "Berhasil!",
          message: "Password berhasil diubah. Silakan masuk dengan password baru.",
          onOk: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
            Navigator.pushReplacementNamed(context, '/login');
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppStatusDialog.show(
          context,
          isSuccess: false,
          title: "Gagal",
          message: e.toString().replaceAll('Exception: ', ''),
          onOk: () => Navigator.pop(context),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Color(0xFFD9EBDC), shape: BoxShape.circle),
              child: const Icon(Icons.check,
                  color: Color(0xFF157F4B), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Password Berhasil Diubah!',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
                'Silakan masuk dengan password baru Anda.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Masuk Sekarang',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: AppColors.primaryBlue),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: 24),

                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _step == 3
                        ? Icons.lock_reset
                        : Icons.lock_open_outlined,
                    color: AppColors.primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  _step == 3 ? 'Password Baru' : 'Lupa Password',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: -0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  _step == 3
                      ? 'Masukkan password baru untuk akun $_verifiedEmail'
                      : 'Masukkan email akun Anda. Kami akan mengirimkan kode verifikasi.',
                  style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 14,
                      height: 1.5),
                ),
                const SizedBox(height: 36),

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
                      if (_step == 1) ...[
                        const Text('EMAIL',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _emailField(),
                      ],

                      if (_step == 3) ...[
                        const Text('PASSWORD BARU',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _passwordInputField(
                          controller: _passwordController,
                          hint: '********',
                          obscure: _obscurePassword,
                          onToggle: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                        const SizedBox(height: 20),
                        const Text('KONFIRMASI PASSWORD',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textGrey,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        _passwordInputField(
                          controller: _confirmController,
                          hint: '********',
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.errorRed, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: AppColors.errorRed,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_step == 1 ? _sendOTP : _resetPassword),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          disabledBackgroundColor:
                          AppColors.primaryBlue.withOpacity(0.6),
                          minimumSize: const Size(double.infinity, 54),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                            : Text(
                          _step == 1
                              ? 'Kirim Kode Verifikasi'
                              : 'Ubah Password',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
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

  Widget _emailField() => Container(
    decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(16)),
    child: TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        hintText: 'nama@email.com',
        hintStyle:
        TextStyle(color: Colors.black26, fontSize: 14),
        prefixIcon: Icon(Icons.mail_outline,
            color: Colors.black26, size: 20),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  Widget _passwordInputField({
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
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}