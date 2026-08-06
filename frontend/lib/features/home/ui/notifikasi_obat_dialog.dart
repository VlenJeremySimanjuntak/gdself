import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../models/obat_model.dart';
import '../providers/obat_provider.dart';
import '../../home/providers/home_provider.dart';
import '../providers/user_provider.dart';
import '../../../services/notification_service.dart';

class NotifikasiObatDialog extends ConsumerStatefulWidget {
  final String payload;
  const NotifikasiObatDialog({super.key, required this.payload});

  @override
  ConsumerState<NotifikasiObatDialog> createState() => _NotifikasiObatDialogState();
}

class _NotifikasiObatDialogState extends ConsumerState<NotifikasiObatDialog> {
  bool _isLoading = false;
  bool _isCheckingStatus = true;

  List<JadwalObatModel> _listJadwalAktif = [];
  final Map<int, bool> _checkedObatMap = {};

  int _snoozeId = 0;
  bool _isSnooze = false;
  String _targetWaktuDisplay = "";

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initDialogKolektif());
  }

  Future<void> _initDialogKolektif() async {
    final parts = widget.payload.split('|');
    if (parts.length < 4) {
      setState(() => _isCheckingStatus = false);
      return;
    }

    final String penandaUtama = parts[0].toLowerCase();
    final String waktuPayload = parts[1].trim();

    if (waktuPayload.length >= 5) {
      _targetWaktuDisplay = waktuPayload.substring(0, 5).replaceAll(':', '.');
    } else {
      _targetWaktuDisplay = waktuPayload;
    }

    // ✅ PERBAIKAN 1: Prioritaskan membaca data dari OBAT PROVIDER
    // karena datanya sudah utuh & disuntik nama obat (Bebas dari bug "-")
    int retryCount = 0;
    while (ref.read(obatProvider).semuaJadwalList.isEmpty && retryCount < 15) {
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }

    try {
      List<JadwalObatModel> semuaJadwal = ref.read(obatProvider).semuaJadwalList;
      // Fallback jika kosong baru ke homeProvider
      if (semuaJadwal.isEmpty) {
        semuaJadwal = ref.read(homeProvider).jadwalObat;
      }

      if (penandaUtama == 'snooze_parsial') {
        _snoozeId = int.tryParse(parts[2]) ?? 0;
        _isSnooze = true;

        List<String> listIdSisa = parts[3].split(',');
        _listJadwalAktif = semuaJadwal.where((j) => listIdSisa.contains(j.idJadwalObat.toString())).toList();
      }
      else {
        _snoozeId = int.tryParse(parts[2]) ?? 0;
        final String jenisNotifikasi = parts[3];
        _isSnooze = jenisNotifikasi == 'snooze';

        _listJadwalAktif = semuaJadwal.where((j) {
          final jHari = j.hari?.toLowerCase().trim() ?? "";
          final jWaktu = j.waktuMinumObat?.trim() ?? "";

          bool matchHari = jHari.contains(penandaUtama) || jHari.contains('setiap hari') || jHari.contains('tiap hari');

          final listWaktu = jWaktu.split(',');
          bool matchWaktu = listWaktu.any((w) {
            String wClean = w.trim();
            if (wClean.length >= 5) wClean = wClean.substring(0, 5);
            String pClean = waktuPayload.length >= 5 ? waktuPayload.substring(0, 5) : waktuPayload;
            return wClean == pClean;
          });

          return matchHari && matchWaktu;
        }).toList();
      }

      for (var j in _listJadwalAktif) {
        _checkedObatMap[j.idJadwalObat ?? 0] = false;
        debugPrint("🎯 [Dialog Init] Obat dimuat -> Nama: ${j.obat.namaObat}, ID Jadwal: ${j.idJadwalObat}");
      }
    } catch (e) {
      debugPrint("❌ Error filtering collective medicines: $e");
    }

    if (mounted) setState(() => _isCheckingStatus = false);
  }

  Future<void> _handleSnooze() async {
    if (_isLoading) return;
    if (_snoozeId != 0) await NotificationService().flutterLocalNotificationsPlugin.cancel(id: _snoozeId);
    await NotificationService().buatSnoozeKhusus(_listJadwalAktif, _targetWaktuDisplay);

    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Alarm ditunda 10 menit.'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _handleAksiKolektif() async {
    if (_isLoading || _listJadwalAktif.isEmpty) return;
    setState(() => _isLoading = true);

    List<JadwalObatModel> obatDiminum = [];
    List<JadwalObatModel> obatBelumDiminum = [];

    for (var jadwal in _listJadwalAktif) {
      bool isChecked = _checkedObatMap[jadwal.idJadwalObat] ?? false;
      if (isChecked) {
        obatDiminum.add(jadwal);
      } else {
        obatBelumDiminum.add(jadwal);
      }
    }

    debugPrint("=== 🚀 MULAI KIRIM DATA KONSUMSI ===");
    debugPrint("Total obat yang dicentang: ${obatDiminum.length}");

    if (_snoozeId != 0) {
      await NotificationService().flutterLocalNotificationsPlugin.cancel(id: _snoozeId);
    }

    int totalSukses = 0;
    String pesanErrorServer = "";

    for (var obat in obatDiminum) {
      int id = obat.idJadwalObat ?? 0;
      debugPrint("📦 Data Obat -> ID Jadwal: $id | Nama: ${obat.obat.namaObat}");

      if (id == 0) {
        pesanErrorServer = "ID Jadwal masih 0 (Data Tidak Valid)";
        debugPrint("❌ GAGAL: ID Jadwal masih 0, pengiriman dibatalkan!");
        continue;
      }

      try {
        debugPrint("⏳ Mengirim ke backend (API)...");
        String? errorMsg = await ref.read(obatProvider.notifier).catatKonsumsi(jadwalId: id, status: 'Diminum');

        if (errorMsg == null) {
          totalSukses++;
          debugPrint("✅ BERHASIL mencatat ID: $id");
        } else {
          pesanErrorServer = errorMsg;
          debugPrint("❌ SERVER MENOLAK ID $id: $errorMsg");
        }
      } catch (e) {
        pesanErrorServer = e.toString();
        debugPrint("❌ ERROR SISTEM ID $id: $e");
      }
    }

    debugPrint("=== 🏁 SELESAI KIRIM DATA ===");
    debugPrint("Total Sukses: $totalSukses");

    if (obatBelumDiminum.isNotEmpty) {
      await NotificationService().buatSnoozeKhusus(obatBelumDiminum, _targetWaktuDisplay);
    }

    setState(() => _isLoading = false);

    if (context.mounted) {
      // 1. Tutup pop-up dialog daftar obat terlebih dahulu
      if (Navigator.canPop(context)) Navigator.pop(context);

      final user = ref.read(userProvider).user;
      if (user != null && user.idUser != 0) {
        ref.read(homeProvider.notifier).fetchAll(user.idUser);
      }

      bool isGagalTotal = (totalSukses == 0 && obatDiminum.isNotEmpty);

      // 2. Tampilkan Pop-Up Dialog Custom sesuai desain UI
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32), // Jarak ke layar kiri-kanan
            child: Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- IKON ATAS ---
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isGagalTotal ? const Color(0xFFFFEBEE) : const Color(0xFFE6F2F0),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isGagalTotal ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                        color: isGagalTotal ? Colors.red.shade700 : const Color(0xFF0C7D6A), // Hijau khas aplikasi
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- TEKS JUDUL ---
                  Text(
                    isGagalTotal ? "Gagal Menyimpan\nData Obat" : "Obat Berhasil\nDiperbarui",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B), // Abu-abu gelap kehitaman
                      height: 1.3,
                    ),
                  ),

                  // --- TEKS ERROR (Hanya muncul jika gagal) ---
                  if (isGagalTotal) ...[
                    const SizedBox(height: 12),
                    Text(
                      pesanErrorServer,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // --- TOMBOL BAWAH ---
                  SizedBox(
                    width: double.infinity, // Buat tombol memenuhi lebar pop-up
                    child: ElevatedButton(
                      onPressed: () {
                        // Tutup pop-up. Karena dialog awal sudah ditutup,
                        // ini akan mengembalikan user ke halaman Beranda di baliknya.
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005F82), // Warna biru gelap sesuai gambar
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Radius besar agar berbentuk kapsul
                        ),
                      ),
                      child: Text(
                        isGagalTotal ? "Tutup" : "Masuk ke Beranda",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  bool get _isSemuaTercentang {
    if (_listJadwalAktif.isEmpty) return false;
    return _listJadwalAktif.every((j) => _checkedObatMap[j.idJadwalObat] == true);
  }

  void _togglePilihSemua(bool? val) {
    if (val == null) return;
    setState(() {
      for (var j in _listJadwalAktif) { _checkedObatMap[j.idJadwalObat ?? 0] = val; }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), backgroundColor: Colors.white, elevation: 5, insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: _isCheckingStatus
          ? const SizedBox(height: 180, child: Center(child: CircularProgressIndicator(color: Color(0xFF00695C))))
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _listJadwalAktif.isEmpty ? _buildEmptyView() : _buildKolektifView(),
        ),
      ),
    );
  }

  Widget _buildKolektifView() {
    final now = DateTime.now();
    final dateFormatted = "${DateFormat('EEEE, d MMMM yyyy', 'id').format(now)} • $_targetWaktuDisplay WIB";

    // Cek apakah sisa obat yang harus diminum hanya 1
    final bool isSingleObat = _listJadwalAktif.length == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // --- Indikator "Drag Handle" (Garis abu-abu di atas) ---
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        // --- Ikon Header (Waktu) ---
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
              color: Color(0xFFEAF5F3), // Hijau mint pudar
              shape: BoxShape.circle
          ),
          child: Icon(
            _isSnooze ? Icons.snooze : Icons.access_time,
            color: const Color(0xFF00695C), // Teal gelap
            size: 28,
          ),
        ),
        const SizedBox(height: 16),

        // --- Judul ---
        Text(
          _isSnooze ? 'Peringatan Susulan!' : 'Waktunya Minum Obat!',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF131F33)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // --- Tanggal & Waktu (Pill) ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20)
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF475569)),
              const SizedBox(width: 8),
              Text(
                  dateFormatted,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600)
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // --- Teks Pertanyaan ---
        const Align(
            alignment: Alignment.centerLeft,
            child: Text(
                "Apakah obat sudah diminum?",
                style: TextStyle(fontSize: 14, color: Color(0xFF475569), fontWeight: FontWeight.w500)
            )
        ),
        const SizedBox(height: 12),

        // --- List Obat ---
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _listJadwalAktif.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final jadwal = _listJadwalAktif[index];

            final namaObatDisplay = (jadwal.obat.namaObat.isEmpty || jadwal.obat.namaObat == '-')
                ? 'Obat ${index + 1}'
                : jadwal.obat.namaObat;

            final cleanDosis = (jadwal.obat.dosis == null || jadwal.obat.dosis!.isEmpty || jadwal.obat.dosis == '-')
                ? '-'
                : jadwal.obat.dosis!.replaceAll('(', '').replaceAll(')', '');

            final bool isChecked = _checkedObatMap[jadwal.idJadwalObat] ?? false;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)
              ),
              child: Row(
                children: [
                  // Ikon Pil Obat
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                          color: Color(0xFFEAF5F3),
                          shape: BoxShape.circle
                      ),
                      child: const Icon(PhosphorIconsRegular.pill, color: Color(0xFF00695C), size: 24)
                  ),
                  const SizedBox(width: 14),

                  // Info Obat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            namaObatDisplay,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF131F33))
                        ),
                        const SizedBox(height: 4),
                        Text(
                            "Dosis: $cleanDosis",
                            style: const TextStyle(color: Color(0xFF475569), fontSize: 12)
                        ),
                      ],
                    ),
                  ),

                  // Tampilkan Checkbox HANYA jika obat lebih dari 1
                  if (!isSingleObat)
                    Checkbox(
                      value: isChecked,
                      activeColor: const Color(0xFF005F82),
                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (bool? value) {
                        setState(() { _checkedObatMap[jadwal.idJadwalObat] = value ?? false; });
                      },
                    ),
                ],
              ),
            );
          },
        ),

        // --- Pilih Semua (Sembunyikan jika obat cuma 1) ---
        if (!isSingleObat) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                    value: _isSemuaTercentang,
                    activeColor: const Color(0xFF005F82),
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: _togglePilihSemua
                ),
                const Text(
                    "Pilih Semua",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF005F82))
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),

        // --- Tombol Aksi ---
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C7D6A)))
            : Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _handleSnooze,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Ingatkan Nanti', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Jika obat cuma 1, otomatis anggap tercentang saat tombol "Sudah" ditekan
                  if (isSingleObat && _listJadwalAktif.isNotEmpty) {
                    _checkedObatMap[_listJadwalAktif.first.idJadwalObat ?? 0] = true;
                  }
                  _handleAksiKolektif();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005F82),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Sudah', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 40), const SizedBox(height: 12),
        const Text("Tidak ada jadwal aktif ditemukan untuk jam ini.", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
      ],
    );
  }
}