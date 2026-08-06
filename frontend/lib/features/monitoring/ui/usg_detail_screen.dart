import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/usg_tiroid_model.dart';
import '../../../services/api_service.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import 'edit_usg_screen.dart';

class UsgDetailScreen extends ConsumerWidget {
  final int usgId;
  // usgData masih kita terima buat jaga-jaga kalau monitoringProvider kosong
  final UsgTiroidModel? usgData;

  const UsgDetailScreen({
    super.key,
    required this.usgId,
    this.usgData,
  });

  // 🔧 DIUBAH: Detail view = ORIGINAL (full-res) via endpoint ber-JWT.
  String _getFotoUrl(int usgId, String? fotoPath) {
    if (fotoPath == null || fotoPath.isEmpty) return '';
    String baseUrl = ApiService().sendRequest.options.baseUrl; // sudah termasuk ".../api"
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/usg-tiroid/$usgId/foto';
  }

  void _showFullScreenImage(BuildContext context, String imageUrl, Map<String, String>? authHeaders) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0, // Zoom maksimal 4x
                child: Image.network(
                  imageUrl,
                  headers: authHeaders,
                  fit: BoxFit.contain, // Pastikan gambar tidak terpotong (contain)
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pantau state monitoring
    final monitorState = ref.watch(monitoringProvider);

    // 🔧 DITAMBAH: header JWT + ngrok-skip untuk gambar.
    final authHeaders = ref.watch(userProvider).authHeaders;

    // ✅ PERBAIKAN: Cari dulu data TERBARU di monitorState.
    // Kalau tidak ketemu, baru pakai usgData bawaan.
    final usg = monitorState.usgList.firstWhere(
          (item) => item.idUsg == usgId,
      orElse: () => usgData ?? (throw Exception('Data USG tidak ditemukan')),
    );

    final String tanggal = usg.tglPemeriksaan != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(usg.tglPemeriksaan!)
        : '-';

    final String imageUrl = _getFotoUrl(usgId, usg.fotoPath);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Rekapan Hasil USG",
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usg.namaRs, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF1E293B))),
                  const SizedBox(height: 8),
                  Text(tanggal, style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  const Text("Hasil USG Tiroid", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 16),
                  if (imageUrl.isNotEmpty) ...[
                    GestureDetector( // ✅ BUNGKUS DENGAN GESTURE DETECTOR
                      onTap: () => _showFullScreenImage(context, imageUrl, authHeaders),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          headers: authHeaders,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover, // Di halaman UI tetap cover agar rapi
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: const Color(0xFFE2E8F0),
                              child: const Center(child: CircularProgressIndicator(color: Color(0xFF006699))),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 48, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text('Gambar tidak tersedia', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text('Catatan/ Deskripsi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Text(
                    usg.catatanDokter?.isNotEmpty == true ? usg.catatanDokter! : '-',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.6, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tombol Edit – di kanan, ukuran menyesuaikan
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Await Navigator untuk menangkap hasil kembalian dari EditScreen
                  final isEdited = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditUsgScreen(usg: usg)),
                  );
                  // Jika isEdited bernilai true, kita refresh datanya
                  if (isEdited == true) {
                    final userId = ref.read(userProvider).user?.idUser;
                    if (userId != null) {
                      ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
                    }
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006699),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}