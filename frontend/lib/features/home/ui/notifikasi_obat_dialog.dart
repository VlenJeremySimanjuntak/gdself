import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ Import Provider Obat Mas Vlen di sini
import '../providers/obat_provider.dart';

class NotifikasiObatDialog extends ConsumerStatefulWidget {
  final String namaObat; // Format Payload: "NamaObat|SnoozeID|IdJadwalObat"

  const NotifikasiObatDialog({super.key, required this.namaObat});

  @override
  ConsumerState<NotifikasiObatDialog> createState() => _NotifikasiObatDialogState();
}

class _NotifikasiObatDialogState extends ConsumerState<NotifikasiObatDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // ✅ 1. PECAH PAYLOAD
    final parts = widget.namaObat.split('|');
    final String namaObatAsli = parts.isNotEmpty ? parts[0] : "Obat Anda";
    final int snoozeId = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final int idJadwalObat = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    final bool isSnooze = widget.namaObat.contains('|') && snoozeId > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSnooze ? const Color(0xFFFFF3E0) : const Color(0xFFEAF4F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isSnooze ? Icons.warning_amber_rounded : Icons.alarm,
                    color: isSnooze ? Colors.orange : const Color(0xFF006699),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSnooze ? 'Peringatan Terakhir!' : 'Waktunya Minum Obat!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSnooze ? Colors.orange.shade800 : const Color(0xFF2F3B42),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSnooze
                            ? 'Sudah lewat 10 menit! Segera minum $namaObatAsli agar pengobatan tetap optimal.'
                            : 'Saatnya konsumsi $namaObatAsli. Jangan lupa minum air putih yang cukup.',
                        style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF006699)))
                : Row(
              children: [
                // ===========================================
                // TOMBOL SUDAH DIMINUM (KASUS 1)
                // ===========================================
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isLoading = true);

                      // 1. Matikan Snooze agar tidak berisik lagi
                      if (snoozeId != 0) {
                        await FlutterLocalNotificationsPlugin().cancel(id: snoozeId);
                      }

                      // 2. Tembak API Golang (Status: Diminum)
                      if (idJadwalObat != 0) {
                        await ref.read(obatProvider.notifier).catatKonsumsi(
                          jadwalId: idJadwalObat,
                          status: 'Diminum',
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hebat! Obat sudah diminum.'), backgroundColor: Colors.green)
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006699),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('SUDAH DIMINUM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),

                // ===========================================
                // TOMBOL LEWATI (KASUS 2)
                // ===========================================
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isLoading = true);

                      // 1. Matikan Snooze
                      if (snoozeId != 0) {
                        await FlutterLocalNotificationsPlugin().cancel(id: snoozeId);
                      }

                      // 2. Tembak API Golang (Status: Terlewat)
                      if (idJadwalObat != 0) {
                        await ref.read(obatProvider.notifier).catatKonsumsi(
                          jadwalId: idJadwalObat,
                          status: 'Terlewat', // Sesuaikan dengan validasi di UseCase Golang Mas
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Jadwal dilewati.'), backgroundColor: Colors.redAccent)
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('LEWATI', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.bold, fontSize: 12)),
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