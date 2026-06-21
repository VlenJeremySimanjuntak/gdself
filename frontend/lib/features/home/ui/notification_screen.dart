import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  List<PendingNotificationRequest> _pendingNotifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoading = true);

    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final pending = await flutterLocalNotificationsPlugin.pendingNotificationRequests();

      // ✅ Filter hanya notifikasi obat (bukan test)
      final obatNotifications = pending.where((n) =>
      n.id != 999 && // Bukan test notification
          (n.title?.contains('Minum') ?? false) // Hanya notifikasi obat
      ).toList();

      if (mounted) {
        setState(() {
          _pendingNotifications = obatNotifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat notifikasi: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3],
            colors: [Color(0xFFEAF5FF), Color(0xFFF2F2F7)],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text(
                'Notifikasi Obat',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              backgroundColor: Colors.transparent,
              border: null,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.chevron_back, color: Color(0xFF006699)),
                onPressed: () => Navigator.pop(context),
              ),
              trailing: _pendingNotifications.isNotEmpty
                  ? CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Refresh', style: TextStyle(fontSize: 15, color: Color(0xFF006699))),
                onPressed: _loadPendingNotifications,
              )
                  : null,
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isLoading
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: CupertinoActivityIndicator(),
                  ),
                )
                    : _pendingNotifications.isEmpty
                    ? _buildEmptyState()
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Jadwal Obat Aktif'),
                    const SizedBox(height: 10),
                    ..._pendingNotifications.map((n) => _buildNotificationItem(
                      title: n.title ?? 'Minum Obat',
                      desc: n.body ?? 'Waktunya minum obat sesuai jadwal.',
                      time: _formatTime(n.id),
                      icon: CupertinoIcons.capsule_fill,
                      iconColor: const Color(0xFF006699),
                    )),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.info_circle_fill, color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Notifikasi akan muncul sesuai jadwal yang telah diatur. Pastikan izin notifikasi aktif.',
                              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                            ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.bell_slash,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Notifikasi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jadwal notifikasi obat belum tersedia.\nTambahkan jadwal obat terlebih dahulu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              child: const Text('Refresh'),
              onPressed: _loadPendingNotifications,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF00695C), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00695C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(CupertinoIcons.bell_fill, size: 12, color: Color(0xFF006699)),
                      SizedBox(width: 4),
                      Text(
                        'Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF006699),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Format ID menjadi jam (karena ID mengandung weekday dan slot)
  String _formatTime(int id) {
    // ID format: (idObat * 1000) + (weekday * 100) + slot
    final weekday = ((id % 1000) / 100).floor();
    final hari = _getHariFromWeekday(weekday);
    return hari;
  }

  String _getHariFromWeekday(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return 'Setiap Hari';
    }
  }
}