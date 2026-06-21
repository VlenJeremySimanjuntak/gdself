import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/user_provider.dart'; // sesuaikan path
import '../../../../../utils/design_system.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// ✅ IMPORT BARU DITAMBAHKAN DI SINI
import 'forgot_password_screen.dart';
import 'google_complete_register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validate() {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty) return 'Email tidak boleh kosong.';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Format email tidak valid.';
    }
    if (password.isEmpty) return 'Password tidak boleh kosong.';
    if (password.length < 6) return 'Password minimal 6 karakter.';
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      ref.read(userProvider.notifier).clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    final success = await ref.read(userProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch → rebuild otomatis saat state berubah
    final authState   = ref.watch(userProvider);
    final screenWidth = MediaQuery.of(context).size.width;

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
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false, // Penting agar Spacer tetap berfungsi
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // 1. HEADER
                      Row(
                        children: [
                          Image.asset('assets/images/graves-logo.png',
                              width: 28, height: 28, fit: BoxFit.contain),
                          const SizedBox(width: 10),
                          const Text("Graves disease",
                              style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ],
                      ),

                      const Spacer(flex: 1),

                      // 2. JUDUL
                      const Text(
                        "Selamat Datang\nKembali",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.2,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Silakan masuk untuk melanjutkan\npemantauan kesehatan anda.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textGrey, fontSize: 14, height: 1.5),
                      ),

                      const Spacer(flex: 1),

                      // 3. FORM CARD
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
                            const Text("EMAIL",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textGrey,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hint: "nama@email.com",
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) =>
                                  ref.read(userProvider.notifier).clearError(),
                            ),
                            const SizedBox(height: 20),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("KATA SANDI",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textGrey,
                                        letterSpacing: 0.5)),
                                GestureDetector(
                                  // ✅ PERBAIKAN 1: Navigasi Lupa Kata Sandi
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())
                                  ),
                                  child: const Text("Lupa Kata Sandi?",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primaryBlue,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hint: "********",
                              icon: Icons.lock_outline,
                              isPassword: true,
                              onChanged: (_) =>
                                  ref.read(userProvider.notifier).clearError(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black26,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _obscureText = !_obscureText),
                              ),
                            ),

                            // Error dari BE
                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppColors.errorRed, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage!,
                                      style: const TextStyle(
                                          color: AppColors.errorRed, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 24),

                            // TOMBOL MASUK
                            ElevatedButton(
                              onPressed:
                              authState.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                disabledBackgroundColor:
                                AppColors.primaryBlue.withOpacity(0.6),
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
                                  : const Text("Masuk",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),

                            const SizedBox(height: 16),

                            // TOMBOL MASUK DENGAN GOOGLE
                            OutlinedButton.icon(
                              // ✅ PERBAIKAN 2: Logika Google Sign-In New User
                              onPressed: authState.isLoading ? null : () async {
                                final result = await ref.read(userProvider.notifier).loginWithGoogle();
                                if (!mounted) return;

                                final status = result['status'];

                                if (status == 'success') {
                                  Navigator.pushReplacementNamed(context, '/home');

                                } else if (status == 'new_user') {
                                  // User belum terdaftar → buka form lengkapi data
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GoogleCompleteRegisterScreen(
                                        idToken:      result['id_token'] ?? '',
                                        googleEmail:  result['google_email'] ?? '',
                                        googleName:   result['google_name'] ?? '',
                                        googlePhoto:  result['google_photo'] ?? '',
                                      ),
                                    ),
                                  );

                                } else if (status == 'error') {
                                  // Error sudah di-set ke authState.errorMessage
                                  // tidak perlu lakukan apa-apa, UI sudah menampilkan error
                                }
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.google,
                                size: 20,
                              ),
                              label: const Text(
                                "Masuk dengan Google",
                                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                                shape: const StadiumBorder(),
                                side: const BorderSide(color: Colors.black12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // 4. FOOTER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Belum punya akun? ",
                              style:
                              TextStyle(color: AppColors.textGrey, fontSize: 14)),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/register'),
                            child: const Text("Daftar",
                                style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscureText : false,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.black26, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}