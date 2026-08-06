import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ⚠️ Sesuaikan path ini kalau struktur foldermu beda — ini asumsi dialog
// ada di lib/features/monitoring/ui/widgets/ dan home_provider.dart ada di
// lib/features/home/providers/home_provider.dart (3 folder ke atas).
import '../../../home/providers/home_provider.dart';

class PeringatanKepatuhanDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> dataObat;

  const PeringatanKepatuhanDialog({
    super.key,
    required this.dataObat,
  });

  @override
  ConsumerState<PeringatanKepatuhanDialog> createState() =>
      _PeringatanKepatuhanDialogState();
}

class _PeringatanKepatuhanDialogState
    extends ConsumerState<PeringatanKepatuhanDialog> {
  // ✅ Semua card collapsed saat popup pertama muncul (bukan halaman rekap)
  final Set<int> _expandedIndices = {};

  static const Color _primaryColor = Color(0xFF00695C);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF4B5563);
  static const Color _missedBackground = Color(0xFFFFF5F5);
  static const Color _missedBorder = Color(0xFFFFE4E6);
  static const Color _missedColor = Color(0xFFDC2626);
  // Estimasi tinggi satu card obat dalam kondisi collapsed (dipakai untuk
  // menentukan kapan list mulai di-scroll, bukan ukuran presisi pixel-perfect).
  static const double _estimatedCardHeight = 76;

  // ✅ Endpoint AI kepatuhan tidak mengirim field "dosis", jadi kita ambil
  // dari data obat yang sudah dimuat homeProvider (dicocokkan lewat nama obat).
  // Kalau backend suatu saat mengirim "dosis" sendiri, itu tetap diprioritaskan.
  String _cariDosis(Map<String, dynamic> obat) {
    final dosisDariResponse = obat['dosis']?.toString();
    if (dosisDariResponse != null && dosisDariResponse.isNotEmpty) {
      return dosisDariResponse;
    }

    final namaObat = (obat['nama_obat'] ?? '').toString().trim().toLowerCase();
    if (namaObat.isEmpty) return '';

    final semuaJadwal = ref.watch(homeProvider).jadwalObat;
    for (final jadwal in semuaJadwal) {
      if (jadwal.obat.namaObat.trim().toLowerCase() == namaObat) {
        return jadwal.obat.dosis ?? '';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final int jumlahObat = widget.dataObat.length;

    // ✅ Tidak dibungkus Center lagi — Dialog dari showDialog sudah
    // nge-center sendiri. Center() tambahan di sini memaksa widget
    // mengisi seluruh tinggi layar sebelum baru nge-center child-nya,
    // itu penyebab dialog terasa full-height dengan banyak ruang kosong.
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // tinggi mengikuti isi konten
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.sparkle,
                        color: _primaryColor,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Informasi Kepatuhan Obat",
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Mari lihat catatan minum obat anda agar hormon tetap stabil.",
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // ================= LIST OBAT =================
            // Menampilkan ±3 card collapsed dulu; kalau obatnya lebih dari itu,
            // list di-scroll (bukan bikin dialog makin tinggi).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: jumlahObat > 3
                    ? _estimatedCardHeight * 3.5
                    : double.infinity,
              ),
              child: Scrollbar(
                thumbVisibility: jumlahObat > 3,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                  shrinkWrap: true,
                  physics: jumlahObat > 3
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: jumlahObat,
                  itemBuilder: (context, index) {
                    final obat = widget.dataObat[index];
                    final namaObat = obat['nama_obat'] ?? 'Obat';
                    final dosis = _cariDosis(obat);
                    final isExpanded = _expandedIndices.contains(index);
                    // ✅ RBAI Kepatuhan 1 = early warning, bukan rekap penuh.
                    // Hanya tampilkan jadwal berstatus "Terlewat"; status lain
                    // (mis. "Diminum") tidak relevan untuk peringatan ini dan disaring di sini.
                    final List<dynamic> detailList = (obat['detail'] ?? [])
                        .where((r) =>
                    (r['status']?.toString().toLowerCase() ?? '') ==
                        'terlewat')
                        .toList();

                    return _buildExpandableObatCard(
                      index: index,
                      namaObat: namaObat.toString(),
                      dosis: dosis.toString(),
                      isExpanded: isExpanded,
                      riwayat: detailList,
                    );
                  },
                ),
              ),
            ),

            // ================= FOOTER (PESAN & TOMBOL) =================
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F9F6),
                      borderRadius: BorderRadius.circular(10),
                      border: const Border(
                        left: BorderSide(color: _primaryColor, width: 3),
                      ),
                    ),
                    //Perlu Diperbaiki disini aja kita buat
                    child: Text(
                      "Terdapat $jumlahObat jadwal konsumsi obat Anda yang belum tercatat hari ini. Yuk, luangkan waktu sejenak untuk memperbaruinya agar pemantauan kesehatan Anda tetap berjalan dengan baik.",
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42, // tombol lebih compact
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _primaryColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableObatCard({
    required int index,
    required String namaObat,
    required String dosis,
    required bool isExpanded,
    required List<dynamic> riwayat,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // jarak antar card lebih lega
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _primaryColor.withOpacity(0.05),
          highlightColor: _primaryColor.withOpacity(0.03),
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>('obat_$index'),
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                _expandedIndices.add(index);
              } else {
                _expandedIndices.remove(index);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                namaObat,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: _textPrimary,
                ),
              ),
              if (dosis.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  dosis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          iconColor: Colors.grey.shade400,
          collapsedIconColor: Colors.grey.shade400,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            const SizedBox(height: 2),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "JADWAL TERLEWAT:",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: _textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (riwayat.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 6.0),
                child: Text(
                  "Catatan jadwal belum tersedia.",
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              )
            else
              ...riwayat.map((r) => _buildRiwayatItem(
                r['tanggal']?.toString() ?? '',
                r['jam']?.toString() ?? '',
                r['status']?.toString() ?? 'Terlewat',
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatItem(String tanggal, String jam, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _missedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _missedBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tanggal,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                jam,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _missedColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}