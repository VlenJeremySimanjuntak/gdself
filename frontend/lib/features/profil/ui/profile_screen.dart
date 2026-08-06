import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../login/ui/login_screen.dart';
import 'edit_profile_screen.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/profile_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/app_status_dialog.dart';
import '../../../services/notification_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // State untuk mengontrol tampilan Pengaturan Akun Lanjutan
  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(
            () => ref.read(profileProvider.notifier).fetchProfile(userId),
      );
    }
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return "-";
    try {
      DateTime parsed = DateTime.parse(rawDate);
      return DateFormat('dd MMMM yyyy', 'id_ID').format(parsed);
    } catch (e) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final authState = ref.watch(userProvider);
    final user = authState.user;

    final profileData = profileState.profileData ?? {};

    String dynamicName = profileData['nama'] ?? user?.nama ?? "Pengguna";
    String dynamicEmail =
        profileData['email'] ?? user?.email ?? "email@domain.com";
    String dynamicBirthday = _formatDate(profileData['tgl_lahir']);
    String dynamicDiagnosisDate = _formatDate(profileData['tgl_terdiagnosis']);

    String? secureAvatarUrl = authState.avatarUrl;

    String initial =
    dynamicName.isNotEmpty ? dynamicName[0].toUpperCase() : '?';

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
          child: profileState.isLoading && profileData.isEmpty
              ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
            ),
          )
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildTopHeader(),
                const SizedBox(height: 40),
                _buildProfileHeader(
                  dynamicName,
                  dynamicEmail,
                  dynamicBirthday,
                  initial,
                  secureAvatarUrl,
                  authState.authHeaders,
                ),
                const SizedBox(height: 40),
                _buildInfoCard(
                  title: "Profil",
                  icon: Icons.badge_outlined,
                  content: Column(
                    children: [
                      _infoRow("Email", dynamicEmail),
                      _infoRow("Tanggal Lahir", dynamicBirthday),
                      _infoRow("Tanggal Diagnosis", dynamicDiagnosisDate),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  title: "Fokus Kesehatan",
                  icon: Icons.analytics_outlined,
                  content: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCF1E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Graves Disease",
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildAdvancedSettingsSection(),
                const SizedBox(height: 32),
                _buildLogoutButton(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/graves-logo.png',
              width: 28,
              height: 28,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.medical_services,
                  color: AppColors.primaryBlue,
                  size: 28,
                );
              },
            ),
            const SizedBox(width: 10),
            const Text(
              "Graves disease",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileHeader(
      String name,
      String email,
      String birthday,
      String initial,
      String? avatarUrl,
      Map<String, String>? authHeaders,
      ) {
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: const Color(0xFFE3ECF7),
                backgroundImage: hasAvatar
                    ? CachedNetworkImageProvider(
                  avatarUrl,
                  headers: authHeaders,
                  cacheKey: ref.watch(userProvider).avatarCacheKey,
                )
                    : null,
                onBackgroundImageError:
                hasAvatar ? (exception, stackTrace) {} : null,
                child: !hasAvatar
                    ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                )
                    : null,
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => EditProfileScreen(
                      currentName: name,
                      currentEmail: email,
                      currentBirthday: birthday,
                      currentHealthFocus: const ["Graves Disease"],
                      currentAvatarUrl: avatarUrl,
                    ),
                  ),
                );

                final userId = ref.read(userProvider).user?.idUser;
                if (userId != null && mounted) {
                  ref.read(profileProvider.notifier).fetchProfile(userId);
                  ref.read(userProvider.notifier).refreshUser(userId);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42637D),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF263238),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF546E7A), size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF455A64),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textGrey, fontSize: 15),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          await ref.read(userProvider.notifier).logout();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
            );
          }
        },
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.logoutText,
          size: 20,
        ),
        label: const Text(
          "Keluar",
          style: TextStyle(
            color: AppColors.logoutText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Colors.white.withOpacity(0.5),
          side: const BorderSide(color: Color(0xFFFFEAEA), width: 2),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsSection() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        children: [
          // Pembatas atas
          const Divider(color: Color(0xFFE2EAE9), thickness: 1),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () {
              setState(() {
                _showAdvancedSettings = !_showAdvancedSettings;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF8A98A8),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  "Pengaturan Akun Lanjutan",
                  style: TextStyle(
                    color: Color(0xFF8A98A8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_showAdvancedSettings) ...[
            // Pembatas tengah (antara judul dan deskripsi saat diexpand)
            const Divider(color: Color(0xFFE2EAE9), thickness: 1),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Tindakan ini tidak dapat dibatalkan. Menghapus akun akan\nmenghapus seluruh data riwayat kesehatan Anda.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8A98A8),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _handleDeleteAccount,
              child: const Text(
                "Hapus Akun Permanen",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            // Memberi sedikit jarak tambahan sebelum garis bawah
            const SizedBox(height: 24),
          ],

          // ✅ Pembatas bawah (Akan selalu muncul)
          // Menjadi pemisah yang tegas antara blok pengaturan dan tombol Keluar
          const Divider(color: Color(0xFFE2EAE9), thickness: 1),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF00897B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF455A64),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final userId = ref.read(userProvider).user?.idUser;
    final String email = ref.read(userProvider).user?.email ?? "email Anda";
    if (userId == null) return;

    final bool? lanjut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info,
                  color: Color(0xFFD32F2F),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Konfirmasi Penghapusan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "Kami ingin memastikan Anda memahami bahwa data ini akan dihapus secara permanen jika Anda memilih untuk melanjutkan.",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DATA YANG AKAN DIHAPUS:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildChecklistItem("Riwayat & tanggal diagnosis"),
                    _buildChecklistItem("Hasil lab & foto USG"),
                    _buildChecklistItem("Jadwal & log konsumsi obat"),
                    _buildChecklistItem("Data wearable & hasil analisis AI"),
                    _buildChecklistItem("Foto profil"),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Harap diingat bahwa data yang dihapus tidak dapat dipulihkan kembali.",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Batal",
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Lanjutkan",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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

    if (lanjut != true) return;

    _showBlockingLoader("Mengirim kode konfirmasi...");
    final bool otpSent =
    await ref.read(profileProvider.notifier).requestDeleteOtp(userId);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!otpSent) {
      _showStatus(
        false,
        "Gagal",
        ref.read(profileProvider).errorMessage ??
            "Gagal mengirim kode konfirmasi.",
      );
      return;
    }

    if (mounted) _showOtpConfirmDialog(userId, email);
  }

  // ✅ PERBAIKAN: Menjalankan Custom Widget OTP yang persis dengan image_d35f99.png
  void _showOtpConfirmDialog(int userId, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _OtpVerificationDialog(
          email: email,
          onResend: () async {
            final bool otpSent = await ref.read(profileProvider.notifier).requestDeleteOtp(userId);
            if (mounted && otpSent) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text("Kode OTP berhasil dikirim ulang ke email Anda."),
                    backgroundColor: Color(0xFF00897B),
                    behavior: SnackBarBehavior.floating,
                  )
              );
            }
          },
          onConfirm: (code) {
            Navigator.pop(ctx);
            // Otomatis men-passing konfirmasi "HAPUS" ke backend agar API Anda tidak gagal
            _confirmDelete(userId, code, "HAPUS");
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
      int userId, String code, String confirmation) async {
    _showBlockingLoader("Menghapus akun...");

    final bool ok = await ref.read(profileProvider.notifier).deleteAccount(
      userId,
      code: code,
      confirmation: confirmation,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!ok) {
      _showStatus(
        false,
        "Gagal Menghapus",
        ref.read(profileProvider).errorMessage ??
            "Terjadi kesalahan. Silakan coba lagi.",
      );
      return;
    }

    try {
      await NotificationService().flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('⚠️ Gagal cancel alarm lokal saat hapus akun: $e');
    }

    final String? avatarUrl = ref.read(userProvider).avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await CachedNetworkImage.evictFromCache(avatarUrl);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    await ref.read(userProvider.notifier).logout();

    if (!mounted) return;
    AppStatusDialog.show(
      context,
      isSuccess: true,
      title: "Akun Dihapus",
      message:
      "Akun dan seluruh data Anda telah dihapus permanen. Terima kasih telah menggunakan GdSelf.",
      onOk: () {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
        );
      },
    );
  }

  void _showBlockingLoader(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFFC62828)),
                const SizedBox(width: 20),
                Flexible(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStatus(bool isSuccess, String title, String message) {
    AppStatusDialog.show(
      context,
      isSuccess: isSuccess,
      title: title,
      message: message,
      onOk: () => Navigator.of(context, rootNavigator: true).pop(),
    );
  }
}


// ============================================================================
// ✅ CUSTOM WIDGET: DIALOG VERIFIKASI OTP SESUAI DESAIN BARU
// ============================================================================
class _OtpVerificationDialog extends StatefulWidget {
  final String email;
  final Future<void> Function() onResend;
  final Function(String) onConfirm;

  const _OtpVerificationDialog({
    required this.email,
    required this.onResend,
    required this.onConfirm,
  });

  @override
  State<_OtpVerificationDialog> createState() => _OtpVerificationDialogState();
}

class _OtpVerificationDialogState extends State<_OtpVerificationDialog> {
  String _otpCode = "";
  final FocusNode _focusNode = FocusNode();
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Otomatis men-trigger keyboard untuk muncul setelah dialog terbuka
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header (Icon + Title)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_outlined,
                    color: Color(0xFFB71C1C), // Merah gelap
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Verifikasi Keamanan",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. Deskripsi
            const Text(
              "Masukkan 6 digit kode OTP yang telah dikirimkan ke email Anda untuk melanjutkan penghapusan akun.",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // 3. Custom Input 6 Kotak OTP
            Stack(
              alignment: Alignment.center,
              children: [
                // TextField tak terlihat (Hanya untuk logic & memanggil keyboard HP)
                SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: "",
                    ),
                    onChanged: (val) {
                      setState(() {
                        _otpCode = val;
                      });
                    },
                  ),
                ),
                // Tampilan Visual 6 Kotak (UI)
                GestureDetector(
                  onTap: () => _focusNode.requestFocus(),
                  child: Container(
                    color: Colors.transparent, // Biar seluruh baris bisa ditap
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        // Logika untuk mengetahui kotak mana yang sedang aktif (Focused)
                        bool isFocused = _focusNode.hasFocus &&
                            (index == _otpCode.length || (index == 5 && _otpCode.length == 6));
                        bool hasText = index < _otpCode.length;

                        return Container(
                          width: 42,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              // Jika aktif pinggirannya Hijau/Teal, kalau tidak abu-abu muda
                              color: isFocused ? const Color(0xFF00897B) : const Color(0xFFE2EAE9),
                              width: isFocused ? 2.0 : 1.0,
                            ),
                          ),
                          child: Text(
                            hasText ? _otpCode[index] : "",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // 4. Tombol Kirim Ulang
            Center(
              child: GestureDetector(
                onTap: () async {
                  if (_isResending) return;
                  setState(() => _isResending = true);
                  await widget.onResend();
                  if (mounted) setState(() => _isResending = false);
                },
                child: Text(
                  _isResending ? "Mengirim ulang..." : "Kirim ulang kode OTP",
                  style: const TextStyle(
                    color: Color(0xFF00897B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 5. Tombol Batal & Hapus
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF94A3B8), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Batal",
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    // Tombol Hapus hanya bisa ditekan jika kode sudah 6 digit
                    onPressed: _otpCode.length == 6
                        ? () => widget.onConfirm(_otpCode)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C), // Merah gelap
                      disabledBackgroundColor: const Color(0xFFEF9A9A), // Merah pudar jika disable
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Hapus",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}