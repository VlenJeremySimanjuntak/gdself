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
  final UsgTiroidModel? usgData; // ✅ nullable, bisa dikirim dari luar

  const UsgDetailScreen({
    super.key,
    required this.usgId,
    this.usgData,
  });

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    String normalizedPath = path.replaceAll('\\', '/');
    if (normalizedPath.startsWith('http')) return normalizedPath;
    String baseUrl = ApiService().sendRequest.options.baseUrl;
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    } else if (baseUrl.endsWith('/api/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 5);
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = normalizedPath.startsWith('/') ? normalizedPath : '/$normalizedPath';
    return '$cleanBase$cleanPath';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jika usgData dikirim, gunakan itu. Jika tidak, cari dari provider.
    final monitorState = ref.watch(monitoringProvider);
    final usg = usgData ?? monitorState.usgList.firstWhere(
          (item) => item.idUsg == usgId,
      orElse: () => throw Exception('Data USG tidak ditemukan'),
    );

    final String tanggal = usg.tglPemeriksaan != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(usg.tglPemeriksaan!)
        : '-';

    final String imageUrl = _getImageUrl(usg.fotoPath);

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
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
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditUsgScreen(usg: usg)),
                  );
                  // Refresh data USG
                  final userId = ref.read(userProvider).user?.idUser;
                  if (userId != null) {
                    ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
                  }
                },
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                label: const Text("Edit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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