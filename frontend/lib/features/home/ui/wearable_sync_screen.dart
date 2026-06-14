import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/user_provider.dart';
import '../providers/wearable_provider.dart';

class WearableSyncScreen extends ConsumerStatefulWidget {
  const WearableSyncScreen({super.key});

  @override
  ConsumerState<WearableSyncScreen> createState() => _WearableSyncScreenState();
}

class _WearableSyncScreenState extends ConsumerState<WearableSyncScreen> {
  bool _isLoading = false;

  // =========================================================
  // FUNGSI PEMBANTU: Menangani Hasil Sinkronisasi dari Provider
  // =========================================================
  void _handleSyncResult(bool success) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi Berhasil! Data aktivitas harian telah ditarik.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      final errorMsg = ref.read(wearableProvider).errorMessage ?? 'Gagal menyambungkan aplikasi.';
      _showFeedbackDialog(context, errorMsg);
    }
  }

  // =========================================================
  // POP-UP CUSTOM JIKA ERROR / GAGAL
  // =========================================================
  void _showFeedbackDialog(BuildContext context, String message) {
    final bool isWarning = message.toLowerCase().contains('tidak ditemukan data') ||
        message.toLowerCase().contains('izin aktif');

    final Color primaryColor = isWarning ? Colors.orange : Colors.red;
    final Color bgColor = isWarning ? Colors.orange.withOpacity(0.1) : Colors.red.withOpacity(0.1);
    final IconData icon = isWarning ? Icons.info_outline_rounded : Icons.close_rounded;
    final String title = isWarning ? 'Data Belum Tersedia' : 'Sinkronisasi Gagal!';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: primaryColor, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005B82),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // 👇 TAMBAHAN: POP-UP PERMINTAAN IZIN SINKRONISASI
  // =========================================================
  void _showIzinDialog(BuildContext context, String providerName, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Izin Akses $providerName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GdSelf memerlukan izin untuk membaca data aktivitas harian Anda (seperti Detak Jantung dan Durasi Tidur) dari $providerName.',
                style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan Anda mencentang semua izin yang diperlukan pada layar berikutnya.',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005680),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                onConfirm(); // Eksekusi fungsi sinkronisasi
              },
              child: const Text('Berikan Izin', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // WIDGET ROW ITEM CUSTOM
  // =========================================================
  Widget _buildThirdPartyItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF101828)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085), height: 1.3),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).user;
    final String initial = (user?.nama != null && (user!.nama as String).isNotEmpty)
        ? (user.nama as String)[0].toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FAFF), Color(0xFFF4F8FF), Color(0xFFF8FBFF)],
        ),
      ),
      child: Stack(
        children: [
          // Efek Elemen Glow Latar Belakang
          Positioned(
            left: -90,
            top: 250,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8AD7FF).withOpacity(0.24),
                    const Color(0xFF8AD7FF).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            top: 60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB5F0DA).withOpacity(0.34),
                    const Color(0xFFB5F0DA).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Scaffold Utama Halaman
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF005680)),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Hubungkan Perangkat',
                style: TextStyle(color: Color(0xFF005680), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFE3ECF7),
                    child: Text(
                      initial,
                      style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                )
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF005680)),
                    SizedBox(height: 16),
                    Text(
                      'Sedang menyinkronkan data...',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ],
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Aplikasi Pihak Ketiga',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF263238),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pilih sumber atau aplikasi kesehatan eksternal yang ingin Anda satukan datanya ke dalam sistem GdSelf.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 34),

                  // LAYOUT LIST UTAMA PIHAK KETIGA
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        // 1. HEALTH CONNECT
                        _buildThirdPartyItem(
                          icon: Icons.apps_outage_rounded,
                          iconColor: Colors.blueAccent,
                          title: 'Health Connect',
                          subtitle: 'Koneksi universal untuk ekosistem Android',
                          onTap: () {
                            _showIzinDialog(context, 'Health Connect', () async {
                              setState(() => _isLoading = true);
                              final userId = ref.read(userProvider).user?.idUser;
                              if (userId != null) {
                                final bool success = await ref
                                    .read(wearableProvider.notifier)
                                    .syncRealWearableData(userId);
                                if (mounted) _handleSyncResult(success);
                              } else {
                                if (mounted) _handleSyncResult(false);
                              }
                            });
                          },
                        ),

                        // 2. SAMSUNG HEALTH
                        _buildThirdPartyItem(
                          icon: Icons.watch_rounded,
                          iconColor: Colors.teal,
                          title: 'Samsung Health',
                          subtitle: 'Koneksi native khusus untuk Galaxy Watch',
                          onTap: () {
                            _showIzinDialog(context, 'Samsung Health', () async {
                              setState(() => _isLoading = true);
                              final userId = ref.read(userProvider).user?.idUser;
                              if (userId != null) {
                                final bool success = await ref
                                    .read(wearableProvider.notifier)
                                    .syncSamsungHealthData(userId);
                                if (mounted) _handleSyncResult(success);
                              } else {
                                if (mounted) _handleSyncResult(false);
                              }
                            });
                          },
                        ),

                        // 3. HUAWEI HEALTH
                        _buildThirdPartyItem(
                          icon: Icons.donut_large_rounded,
                          iconColor: Colors.redAccent,
                          title: 'Huawei Health',
                          subtitle: 'Koneksi native khusus ekosistem HMS/Huawei',
                          onTap: () {
                            _showIzinDialog(context, 'Huawei Health', () async {
                              setState(() => _isLoading = true);
                              final userId = ref.read(userProvider).user?.idUser;
                              if (userId != null) {
                                final bool success = await ref
                                    .read(wearableProvider.notifier)
                                    .syncHuaweiHealthData(userId);
                                if (mounted) _handleSyncResult(success);
                              } else {
                                if (mounted) _handleSyncResult(false);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}