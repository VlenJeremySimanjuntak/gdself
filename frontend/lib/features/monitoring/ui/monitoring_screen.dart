import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../../../models/usg_tiroid_model.dart';
import '../../../utils/design_system.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../riwayat/provider/riwayat_provider.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../providers/monitoring_provider.dart';
import '../../../services/api_service.dart';
import 'widgets/self_report_kondisi_dialog.dart';
import 'input_lab_screen.dart';
import 'lab_detail_screen.dart';
import 'input_usg_screen.dart';
import 'usg_detail_screen.dart';

class MonitoringScreen extends ConsumerStatefulWidget {
  const MonitoringScreen({super.key});

  @override
  ConsumerState<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends ConsumerState<MonitoringScreen> {
  String _selectedTab = "FT3";
  int? _visibleTooltipIndex;
  final Set<int> _expandedUsgIds = {};

  @override
  void initState() {
    super.initState();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() {
        ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
        ref.read(riwayatProvider.notifier).fetchRiwayatData(userId);
      });
    }
  }

  // 🔧 Thumbnail via endpoint ber-JWT
  String _getFotoThumbnailUrl(int? usgId, String? fotoPath) {
    if (usgId == null || fotoPath == null || fotoPath.isEmpty) return '';
    String baseUrl = ApiService().sendRequest.options.baseUrl;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/usg-tiroid/$usgId/foto/thumbnail';
  }

  // 🔧 Foto Original via endpoint ber-JWT
  String _getFotoOriginalUrl(int? usgId, String? fotoPath) {
    if (usgId == null || fotoPath == null || fotoPath.isEmpty) return '';
    String baseUrl = ApiService().sendRequest.options.baseUrl;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase/usg-tiroid/$usgId/foto';
  }

  // 🛠️ Pengecekan data untuk card alert
  bool _checkHasAlertData(HasilAIGabunganModel? aiResult, String selectedTab) {
    if (aiResult == null) return false;
    String status = "";

    switch (selectedTab) {
      case "FT3":
        status = aiResult.statusFt3;
        break;
      case "FT4":
        status = aiResult.statusFt4;
        break;
      case "TSHs":
        status = aiResult.statusTsh;
        break;
      case "TRAb":
        status = aiResult.statusTrab;
        break;
    }

    String cleanStatus = status.trim().toLowerCase();
    return cleanStatus.isNotEmpty && cleanStatus != "-" && cleanStatus != "null";
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final monitorState = ref.watch(monitoringProvider);
    final user = ref.watch(userProvider).user;

    final authHeaders = ref.watch(userProvider).authHeaders;

    List<Map<String, dynamic>> currentData = List.from(monitorState.history[_selectedTab] ?? []);
    currentData.sort((a, b) {
      try {
        DateTime dateA = DateFormat('dd MMM yyyy', 'id_ID').parse(a['date'] ?? '');
        DateTime dateB = DateFormat('dd MMM yyyy', 'id_ID').parse(b['date'] ?? '');
        return dateA.compareTo(dateB);
      } catch (e) {
        return 0;
      }
    });

    bool hasLabDataForTab = currentData.isNotEmpty;
    bool hasUsgData = monitorState.usgList.isNotEmpty;
    final aiResult = monitorState.latestAiResult;
    final bool showAlertCard = _checkHasAlertData(aiResult, _selectedTab);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: monitorState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(user),
            const SizedBox(height: 24),
            _buildHeaderTitle(),
            const SizedBox(height: 24),
            if (showAlertCard && aiResult != null) ...[
              _buildAlertCard(aiResult, _selectedTab),
              const SizedBox(height: 32),
            ],
            _buildChartCard(screenWidth, hasLabDataForTab, currentData),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _buildActionButton(
                icon: Icons.add_circle_outline,
                label: "Tambah Data Laboratorium",
                onPressed: () => _mulaiInputLab(context),
              ),
            ),
            const SizedBox(height: 40),
            _buildSectionHeaderWithoutMenu("Hasil USG Tiroid"),
            const SizedBox(height: 16),
            if (hasUsgData)
              _buildFilledUsgCard(monitorState.usgList.first, authHeaders)
            else
              _buildUsgEmptyStateCard(),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _buildActionButton(
                icon: Icons.add_circle_outline,
                label: "Unggah Hasil USG",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InputUsgScreen()),
                  ).then((_) => _refresh());
                },
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _refresh() {
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      ref.read(monitoringProvider.notifier).fetchMonitoringData(userId);
      ref.read(homeProvider.notifier).fetchAll(userId);
      ref.read(riwayatProvider.notifier).fetchRiwayatData(userId);
    }
  }

  Future<void> _mulaiInputLab(BuildContext context) async {
    final kondisi = await SelfReportKondisiDialog.show(context);
    if (kondisi == null || !context.mounted) return;

    bool lanjut = true;
    if (kondisi == KondisiPengguna.tidakNyaman) {
      lanjut = await _tampilkanSaranJeda(context);
    }

    if (!lanjut || !context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InputLabScreen(kondisiSaatIni: kondisi),
      ),
    ).then((_) => _refresh());
  }

  Future<bool> _tampilkanSaranJeda(BuildContext context) async {
    final lanjut = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: AppColors.primaryBlue,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Sebelum Melanjutkan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Kondisi tremor atau kurang nyaman bisa memengaruhi ketepatan Anda saat mengetik angka hasil lab. Ambil napas sejenak dulu, atau lanjutkan jika Anda sudah siap sistem akan membantu memeriksa ulang data yang tampak tidak wajar.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF475569),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        "Nanti Dulu",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Lanjutkan",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
    return lanjut ?? false;
  }

  Widget _buildTopHeader(dynamic user) {
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

  Widget _buildHeaderTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("MONITOR LAB",
            style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2)),
        SizedBox(height: 8),
        Text("Tren Kesehatan Anda",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildSectionHeaderWithoutMenu(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildChartCard(double width, bool hasData, List<Map<String, dynamic>> currentData) {
    String latestDate = '';
    if (currentData.isNotEmpty) {
      final last = currentData.last;
      latestDate = last['date'] ?? '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Grafik Level\nHormon",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        height: 1.2,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  if (latestDate.isNotEmpty)
                    Text(
                      latestDate,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTabSelector(width),
          const SizedBox(height: 32),
          if (hasData)
            _buildChartContent(width, currentData)
          else
            _buildChartEmptyContent(),
        ],
      ),
    );
  }

  Widget _buildChartEmptyContent() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.insights_rounded, size: 70, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Belum ada data untuk\nditampilkan",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF1E293B),
                height: 1.4,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            "Catat hasil laboratorium Anda secara\nberkala untuk memantau perkembangan\nkesehatan tiroid Anda.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent(double width, List<Map<String, dynamic>> currentData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            void navigateToDetail(String shortDate) {
              try {
                DateTime parsed = DateFormat('dd MMM yyyy', 'id_ID').parse(shortDate);
                final arsipList = ref.read(riwayatProvider).laporanList;
                int reportIndex = arsipList.indexWhere((r) {
                  DateTime rDate = DateTime.tryParse(r['raw_date'] ?? "") ?? DateTime.now();
                  return rDate.year == parsed.year &&
                      rDate.month == parsed.month &&
                      rDate.day == parsed.day;
                });
                if (reportIndex != -1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LabDetailScreen(reportData: arsipList[reportIndex]),
                    ),
                  ).then((_) => _refresh());
                }
              } catch (e) {}
            }

            if (currentData.isEmpty) return;
            final double chartWidth = constraints.maxWidth;
            final double leftPadding = 30;
            final double rightPadding = 10;
            final double usableWidth = chartWidth - leftPadding - rightPadding;

            if (currentData.length == 1) {
              if (_visibleTooltipIndex == 0) {
                navigateToDetail(currentData[0]['date']);
              } else {
                setState(() => _visibleTooltipIndex = 0);
              }
              return;
            }

            final double step = usableWidth / (currentData.length - 1);
            double tapX = details.localPosition.dx;
            int closestIndex = 0;
            double minDist = double.infinity;
            for (int i = 0; i < currentData.length; i++) {
              double pointX = leftPadding + i * step;
              double dist = (tapX - pointX).abs();
              if (dist < minDist) {
                minDist = dist;
                closestIndex = i;
              }
            }

            if (minDist > step / 2) return;

            if (_visibleTooltipIndex == closestIndex) {
              navigateToDetail(currentData[closestIndex]['date']);
            } else {
              setState(() {
                _visibleTooltipIndex = closestIndex;
              });
            }
          },
          child: SizedBox(
            height: 240,
            width: double.infinity,
            child: CustomPaint(
              painter: HormoneChartPainter(
                visibleIndex: _visibleTooltipIndex,
                points: currentData,
                paramName: _selectedTab,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSelector(double width) {
    return Row(
      children: ["FT3", "FT4", "TSHs", "TRAb"].map((tab) {
        bool isSelected = _selectedTab == tab;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedTab = tab;
            _visibleTooltipIndex = null;
          }),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF006699) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(tab,
                style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUsgEmptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt_outlined, size: 50, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text("Belum ada Foto USG\nTiroid ditampilkan",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textDark,
                  height: 1.4)),
          const SizedBox(height: 12),
          const Text(
              "Unggah hasil USG Tiroid Anda untuk mendukung pemantauan kondisi tiroid secara berkelanjutan.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildFilledUsgCard(UsgTiroidModel usg, Map<String, String>? authHeaders) {
    final String tanggal = usg.tglPemeriksaan != null
        ? DateFormat('dd MMMM yyyy', 'id_ID').format(usg.tglPemeriksaan!)
        : '-';
    final String imageUrl = _getFotoThumbnailUrl(usg.idUsg, usg.fotoPath);
    final bool isExpanded = _expandedUsgIds.contains(usg.idUsg);
    final String deskripsi = usg.catatanDokter?.isNotEmpty == true ? usg.catatanDokter! : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(usg.namaRs,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(tanggal,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageUrl.isNotEmpty
                ? GestureDetector(
              onTap: () {
                final String originalUrl = _getFotoOriginalUrl(usg.idUsg, usg.fotoPath);
                _showFullScreenImage(context, originalUrl, authHeaders);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  headers: authHeaders,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryBlue));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        size: 40, color: Colors.grey),
                  ),
                ),
              ),
            )
                : const Center(
                child: Icon(Icons.image_rounded,
                    size: 48, color: Color(0xFF94A3B8))),
          ),
          const SizedBox(height: 20),
          const Text("Catatan Dokter / Deskripsi",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F6F5),
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isExpanded) ...[
                  Text(
                    deskripsi,
                    style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _expandedUsgIds.remove(usg.idUsg);
                        });
                      },
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                            color: Color(0xFF006699),
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    deskripsi,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w500),
                  ),
                  if (deskripsi.length > 100) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UsgDetailScreen(
                                usgId: usg.idUsg!,
                                usgData: usg,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Detail',
                              style: TextStyle(
                                  color: Color(0xFF006699),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: Color(0xFF006699),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF006699),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
    );
  }

  // 🛠️ FIX TOTAL: Menghilangkan titik di awal, fallback warna tren, dan pembersihan status.
  Widget _buildAlertCard(HasilAIGabunganModel aiResult, String selectedTab) {
    const Color fixedBgColor = Color(0xFFE2EAE9);

    String status = "";
    String reminderLab = "";
    String reminderTren = "";

    switch (selectedTab) {
      case "FT3":
        status = aiResult.statusFt3;
        reminderLab = aiResult.reminderFt3;
        reminderTren = aiResult.reminderTrenFt3 ?? "-";
        break;
      case "FT4":
        status = aiResult.statusFt4;
        reminderLab = aiResult.reminderFt4;
        reminderTren = aiResult.reminderTrenFt4 ?? "-";
        break;
      case "TSHs":
        status = aiResult.statusTsh;
        reminderLab = aiResult.reminderTsh;
        reminderTren = aiResult.reminderTrenTsh ?? "-";
        break;
      case "TRAb":
        status = aiResult.statusTrab;
        reminderLab = aiResult.reminderTrab;
        reminderTren = aiResult.reminderTrenTrab ?? "-";
        break;
    }

    String cleanStatus = status.trim().toLowerCase();
    String deskripsi = reminderLab.trim();

    bool trenValid = reminderTren.isNotEmpty &&
        reminderTren != "-" &&
        reminderTren.toLowerCase() != "tidak diketahui" &&
        reminderTren.toLowerCase() != "null";

    // 1. Mencegah munculnya titik di awal kalimat jika reminderLab kosong
    if (trenValid) {
      if (deskripsi.isNotEmpty) {
        if (!deskripsi.endsWith('.')) {
          deskripsi += ". ";
        } else {
          deskripsi += " ";
        }
      }
      deskripsi += reminderTren.trim();
    }

    // 2. Tentukan Status & Warna
    bool isTidakDiketahui = cleanStatus.isEmpty ||
        cleanStatus == "-" ||
        cleanStatus == "null" ||
        cleanStatus.contains("tidak diketahui");

    String statusLabel = isTidakDiketahui ? "TIDAK DIKETAHUI" : status.trim().toUpperCase();
    Color statusColor;

    // Fallback cerdas: Jika status dari DB gagal ditarik ke string pertama, tapi teks tren menyatakan "normal"
    bool isTrendNormalFallback = isTidakDiketahui && deskripsi.toLowerCase().contains("normal");

    if (cleanStatus.contains("normal") || cleanStatus.contains("negatif") || cleanStatus.contains("tetap")) {
      statusColor = const Color(0xFF16A34A); // Hijau (Aman)
    } else if (isTrendNormalFallback) {
      statusColor = const Color(0xFF16A34A); // Hijau (Diambil dari konteks teks tren)
      statusLabel = "NORMAL"; // Override supaya tidak terlihat menakutkan
    } else if (cleanStatus.contains("verifikasi") || cleanStatus.contains("luar rentang")) {
      statusColor = const Color(0xFFD97706); // Oranye (Warning)
    } else if (isTidakDiketahui && !trenValid) {
      statusColor = const Color(0xFF64748B); // Abu-abu
      statusLabel = "BELUM ADA DATA";
    } else if (isTidakDiketahui) {
      statusColor = const Color(0xFFDC2626); // Merah untuk Tidak Diketahui (error)
    } else {
      statusColor = const Color(0xFFDC2626); // Merah untuk Tinggi/Rendah/Positif
    }

    return _buildBaseAlertCard("Status Hormon", statusLabel, statusColor, fixedBgColor, deskripsi);
  }

  Widget _buildBaseAlertCard(String title, String statusLabel, Color statusColor, Color bgColor, String deskripsi) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark),
              ),
              Text(
                statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deskripsi,
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
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
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                headers: authHeaders,
                fit: BoxFit.contain,
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

// ========== CUSTOM PAINTER ==========
class HormoneChartPainter extends CustomPainter {
  final int? visibleIndex;
  final List<Map<String, dynamic>> points;
  final String paramName;

  HormoneChartPainter({this.visibleIndex, required this.points, required this.paramName});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final latestData = points.last;
    double minRujukan = double.tryParse(latestData['min']?.toString() ?? "0") ?? 0.0;
    double maxRujukan = double.tryParse(latestData['max']?.toString() ?? "0") ?? 0.0;

    if (minRujukan == 0.0 && maxRujukan == 0.0) {
      switch (paramName) {
        case "FT3":
          minRujukan = 2.6;
          maxRujukan = 5.7;
          break;
        case "FT4":
          minRujukan = 9.0;
          maxRujukan = 19.0;
          break;
        case "TSHs":
          minRujukan = 0.35;
          maxRujukan = 4.94;
          break;
        case "TRAb":
          minRujukan = 0.0;
          maxRujukan = 2.0;
          break;
        default:
          minRujukan = 0.0;
          maxRujukan = 10.0;
      }
    }

    List<double> allValues = points.map((p) => double.tryParse(p['val']?.toString() ?? "0") ?? 0.0).toList();
    double maxValueInChart = [maxRujukan, ...allValues].reduce((a, b) => a > b ? a : b);
    double chartMax = maxValueInChart + (maxValueInChart * 0.2);
    if (chartMax == 0) chartMax = 10;
    double chartMin = 0.0;

    double chartHeight = size.height - 30;

    double calculateYPos(double value) =>
        chartHeight - ((value - chartMin) / (chartMax - chartMin)) * chartHeight;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    const int gridLines = 6;
    for (int i = 0; i < gridLines; i++) {
      double val = chartMax - (i * (chartMax / (gridLines - 1)));
      double yPos = calculateYPos(val);
      canvas.drawLine(Offset(25, yPos), Offset(size.width, yPos), gridPaint);
      String labelText = val.toStringAsFixed(1);
      if (labelText.endsWith(".0")) {
        labelText = labelText.substring(0, labelText.length - 2);
      }
      _drawText(canvas, Offset(0, yPos - 6), labelText, 10, Colors.grey.shade500, false);
    }

    final double leftPadding = 35;
    final double rightPadding = 15;
    final double usableWidth = size.width - leftPadding - rightPadding;

    if (points.length == 1) {
      double val = allValues[0];
      final Offset point = Offset(leftPadding + (usableWidth / 2), calculateYPos(val));
      _drawText(canvas, Offset(point.dx - 10, chartHeight + 10), points[0]['month'] ?? "", 11, Colors.grey.shade600, true);
      _drawPoint(canvas, point, const Color(0xFF006699));
      if (visibleIndex == 0) {
        _drawTooltip(canvas, point, points[0], paramName, minRujukan, maxRujukan);
      }
      return;
    }

    final double step = usableWidth / (points.length - 1);
    Path path = Path();
    List<Offset> positions = [];

    for (int i = 0; i < points.length; i++) {
      double x = leftPadding + i * step;
      double val = allValues[i];
      double y = calculateYPos(val);
      Offset offset = Offset(x, y);
      positions.add(offset);

      String monthLabel = points[i]['month'] ?? '';
      _drawText(canvas, Offset(x - 12, chartHeight + 10), monthLabel, 11, Colors.grey.shade600, true);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        Offset prev = positions[i - 1];
        double midX = (prev.dx + x) / 2;
        path.cubicTo(midX, prev.dy, midX, y, x, y);
      }
    }

    Path fillPath = Path.from(path);
    fillPath.lineTo(positions.last.dx, chartHeight);
    fillPath.lineTo(positions.first.dx, chartHeight);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF006699).withOpacity(0.35),
        const Color(0xFF006699).withOpacity(0.0),
      ],
    );

    canvas.drawPath(
        fillPath,
        Paint()..shader = gradient.createShader(Rect.fromLTRB(0, 0, 0, chartHeight)));

    final paintLine = Paint()
      ..color = const Color(0xFF006699)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paintLine);

    for (int i = 0; i < positions.length; i++) {
      double val = allValues[i];
      if (visibleIndex == i) {
        canvas.drawCircle(positions[i], 8, Paint()..color = Colors.white);
        canvas.drawCircle(
            positions[i],
            8,
            Paint()
              ..color = const Color(0xFFD32F2F)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        _drawTooltip(canvas, positions[i], points[i], paramName, minRujukan, maxRujukan);
      } else {
        Color pointColor = (maxRujukan > 0 && val > (maxRujukan * 10.0))
            ? const Color(0xFFD97706)
            : ((val > maxRujukan || val < minRujukan) ? AppColors.alertRed : const Color(0xFF006699));
        _drawPoint(canvas, positions[i], pointColor);
      }
    }
  }

  void _drawPoint(Canvas canvas, Offset offset, Color color) {
    canvas.drawCircle(offset, 5, Paint()..color = color);
    canvas.drawCircle(offset, 2.5, Paint()..color = Colors.white);
  }

  void _drawTooltip(Canvas canvas, Offset anchor, Map<String, dynamic> data,
      String paramName, double min, double max) {
    double val = double.tryParse(data['val']?.toString() ?? "0") ?? 0;
    String status = "Normal";
    Color statusColor = const Color(0xFF4CAF50);

    if (max > 0 && val > (max * 10.0)) {
      status = "Perlu Verifikasi";
      statusColor = const Color(0xFFD97706);
    } else if (paramName == "TRAb") {
      if (val > max) {
        status = "Positif";
        statusColor = const Color(0xFFD32F2F);
      } else {
        status = "Negatif";
        statusColor = const Color(0xFF4CAF50);
      }
    } else {
      if (val < min) {
        status = "Rendah";
        statusColor = Colors.orange;
      } else if (val > max) {
        status = "Tinggi";
        statusColor = const Color(0xFFF44336);
      }
    }

    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(anchor.dx - 60, anchor.dy - 65, 120, 50),
        const Radius.circular(8));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF111827));

    _drawText(canvas, Offset(anchor.dx - 50, anchor.dy - 55), data['date'] ?? "", 9, Colors.white, true);
    _drawText(canvas, Offset(anchor.dx - 50, anchor.dy - 40), "$paramName: ${data['val']} ${data['unit']}", 9, Colors.white, true);
    _drawText(canvas, Offset(anchor.dx - 50, anchor.dy - 25), status, 9, statusColor, true);
  }

  void _drawText(Canvas canvas, Offset offset, String text, double fontSize, Color color, bool isBold) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}