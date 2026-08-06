import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import '../../home/providers/user_provider.dart';
import '../providers/wearable_provider.dart';
import '../../../core/widgets/app_status_dialog.dart';


class WearableSyncScreen extends ConsumerStatefulWidget {
  const WearableSyncScreen({super.key});

  @override
  ConsumerState<WearableSyncScreen> createState() => _WearableSyncScreenState();
}

class _WearableSyncScreenState extends ConsumerState<WearableSyncScreen> {
  bool _isLoading = false;

  // =========================================================
  // LOGIKA HASIL SINKRONISASI (DIUBAH AGAR "KOSONG" = SUKSES)
  // =========================================================
  void _handleSyncResult(bool success, String message) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    // ✅ Jika sinkronisasi berhasil atau tidak ada data baru (tetap dianggap sukses/terhubung)
    if (success || message.toLowerCase().contains('tidak ditemukan data') || message.toLowerCase().contains('izin aktif')) {
      AppStatusDialog.show(
        context,
        isSuccess: true,
        title: "Terhubung!",
        message: "Akses berhasil terhubung. Data akan muncul saat aktivitas tersedia.",
        onOk: () {
          Navigator.pop(context); // Tutup dialog
          Navigator.pop(context, true); // Kembali ke Home dengan status sukses
        },
      );
    } else {
      // ✅ Ganti _showFeedbackDialog dengan AppStatusDialog untuk error
      AppStatusDialog.show(
        context,
        isSuccess: false,
        title: "Sinkronisasi Gagal!",
        message: message,
        onOk: () => Navigator.pop(context),
      );
    }
  }

  void _showFeedbackDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 20),
                const Text('Sinkronisasi Gagal!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006699),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  // DIALOG IZIN (MENGIKUTI DESAIN GAMBAR BARU)
  // =========================================================
  void _showIzinDialog(BuildContext context, String providerName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon HP Biru (Sesuai Desain)
                Container(
                  width: 32,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF006699),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 12,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Judul
                Text(
                  'Izin Akses\n$providerName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),

                // Tombol Batal & Berikan Izin (Pill style)
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF94A3B8).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006699),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          onConfirm();
                        },
                        child: const Text('Berikan Izin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // FUNGSI UTAMA SINKRONISASI
  // =========================================================
  Future<void> _processSync() async {
    setState(() => _isLoading = true);

    final userId = ref.read(userProvider).user?.idUser;
    if (userId == null) {
      _handleSyncResult(false, "User ID tidak ditemukan. Silakan login ulang.");
      return;
    }

    try {
      final health = Health();

      final sdkStatus = await health.getHealthConnectSdkStatus();

      if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
        await health.installHealthConnect();
        _handleSyncResult(false, "Health Connect belum tersedia. Silakan install dari Play Store.");
        return;
      }

      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,   // ✅ Tambahkan
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,  // ✅ Tambahkan
      ];
      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      bool hasPermissions = await health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (!hasPermissions) {
        _handleSyncResult(false, "Izin akses kesehatan ditolak. Mohon aktifkan izin di pengaturan perangkat Anda.");
        return;
      }

      final bool success = await ref.read(wearableProvider.notifier).syncRealWearableData(userId);
      final errorMsg = ref.read(wearableProvider).errorMessage ?? 'Gagal menarik data.';

      _handleSyncResult(success, errorMsg);

    } catch (e) {
      _handleSyncResult(false, "Terjadi kesalahan sistem: $e");
    }
  }

  // =========================================================
  // KARTU APLIKASI PIHAK KETIGA (MENGIKUTI DESAIN BARU)
  // =========================================================
  Widget _buildThirdPartyItem({required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Ikon HP Biru Kecil (Sesuai gambar)
            Container(
              width: 20,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF006699),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 8,
                  height: 3,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
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
      backgroundColor: const Color(0xFFF8FBFF), // Latar belakang sangat muda kebiruan
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Aktivitas',
          style: TextStyle(
              color: Color(0xFF006699),
              fontWeight: FontWeight.bold,
              fontSize: 18
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF006699)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: _isLoading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF006699)),
              SizedBox(height: 16),
              Text('Menghubungkan & Membaca Data...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Aplikasi Pihak\nKetiga',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih sumber atau aplikasi\nkesehatan eksternal yang ingin\nAnda satukan datanya ke dalam\nsistem GdSelf.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            if (Platform.isIOS)
              _buildThirdPartyItem(
                title: 'Apple Health',
                onTap: () => _showIzinDialog(context, 'Apple Health', _processSync),
              ),
            if (Platform.isAndroid)
              _buildThirdPartyItem(
                title: 'Health Connect',
                onTap: () => _showIzinDialog(context, 'Health Connect', _processSync),
              ),
          ],
        ),
      ),
    );
  }
}