import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../login/ui/login_screen.dart';
import 'edit_profile_screen.dart';
import '../../../utils/design_system.dart';
import '../../home/providers/user_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {

  @override
  void initState() {
    super.initState();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile(userId));
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
    final user = ref.watch(userProvider).user;

    final profileData = profileState.profileData ?? {};

    String dynamicName = profileData['nama'] ?? user?.nama ?? "Pengguna";
    String dynamicEmail = profileData['email'] ?? user?.email ?? "email@domain.com";
    String dynamicBirthday = _formatDate(profileData['tgl_lahir']);
    String dynamicDiagnosisDate = _formatDate(profileData['tgl_terdiagnosis']);

    // ✅ Ambil URL Foto Profil secara dinamis dari backend/state
    String? dynamicAvatarUrl = profileData['foto_profil'] ?? user?.fotoProfil;

    String initial = dynamicName.isNotEmpty ? dynamicName[0].toUpperCase() : '?';

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
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
              : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // ✅ GANTI: Gunakan _buildTopHeader dengan logo & foto profil
                _buildTopHeader(user),
                const SizedBox(height: 40),

                // --- AVATAR & NAMA (Kini menerima parameter URL foto) ---
                _buildProfileHeader(dynamicName, dynamicEmail, dynamicBirthday, initial, dynamicAvatarUrl),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

                const SizedBox(height: 60),

                _buildLogoutButton(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ TAMBAHKAN: Widget Logo & Foto Profil (sama seperti screen lain)
  Widget _buildTopHeader(dynamic user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo dan teks
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

  // ✅ HAPUS: _buildHeader yang lama (sudah digantikan oleh _buildTopHeader)

  // ✅ PERBAIKAN: Menampilkan Foto Riil dari URL atau Inisial jika Null
  Widget _buildProfileHeader(String name, String email, String birthday, String initial, String? avatarUrl) {
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
                      offset: const Offset(0, 10)
                  )
                ],
              ),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: const Color(0xFFE3ECF7),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(initial, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF334155)))
                    : null,
              ),
            ),
            GestureDetector(
              onTap: () async {
                // Navigasi ke EditProfileScreen dengan melempar currentAvatarUrl
                await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => EditProfileScreen(
                      currentName: name,
                      currentEmail: email,
                      currentBirthday: birthday,
                      currentHealthFocus: const ["Graves Disease"],
                      currentAvatarUrl: avatarUrl, // ✅ OPER URL FOTO KE HALAMAN EDIT
                    ),
                  ),
                );

                // Re-fetch data profil saat kembali dari halaman edit agar foto langsung terupdate
                final userId = ref.read(userProvider).user?.idUser;
                if (userId != null && mounted) {
                  ref.read(profileProvider.notifier).fetchProfile(userId);
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

  Widget _buildInfoCard({required String title, required IconData icon, required Widget content}) {
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
        icon: const Icon(Icons.logout_rounded, color: AppColors.logoutText, size: 20),
        label: const Text(
          "Keluar",
          style: TextStyle(color: AppColors.logoutText, fontWeight: FontWeight.bold, fontSize: 16),
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
}