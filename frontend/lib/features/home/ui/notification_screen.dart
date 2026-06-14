import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // Warna background abu-abu khas iOS
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(), // Efek kenyal khas iOS
        slivers: [
          // Navigasi Atas bergaya iOS
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Notifikasi',
              style: TextStyle(fontFamily: 'Poppins', letterSpacing: -1),
            ),
            backgroundColor: const Color(0xFFF2F2F7).withOpacity(0.8),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text('Bersihkan', style: TextStyle(fontSize: 15)),
              onPressed: () {},
            ),
          ),

          // Konten Notifikasi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Terbaru'),
                  const SizedBox(height: 10),
                  _buildNotificationItem(
                    title: 'Jadwal Minum Obat',
                    desc: 'Sekarang waktunya minum Methimazole (1 tablet). Jangan lupa ya!',
                    time: 'Sekarang',
                    icon: CupertinoIcons.capsule_fill,
                    iconColor: Colors.blue,
                    isUnread: true,
                  ),
                  _buildNotificationItem(
                    title: 'Kondisi Tiroid',
                    desc: 'Berdasarkan input lab kemarin, kondisi Anda tetap Stabil.',
                    time: '10 mnt lalu',
                    icon: CupertinoIcons.waveform_path_ecg,
                    iconColor: Colors.redAccent,
                    isUnread: true,
                  ),

                  const SizedBox(height: 25),
                  _buildSectionHeader('Sebelumnya'),
                  const SizedBox(height: 10),
                  _buildNotificationItem(
                    title: 'Edukasi Baru',
                    desc: 'Baca artikel baru: "Menjaga Pola Makan untuk Pasien Graves Disease".',
                    time: '2 jam lalu',
                    icon: CupertinoIcons.book_fill,
                    iconColor: Colors.orange,
                    isUnread: false,
                  ),
                  _buildNotificationItem(
                    title: 'Update Sistem',
                    desc: 'Versi aplikasi terbaru sudah tersedia untuk kenyamanan Anda.',
                    time: 'Kemarin',
                    icon: CupertinoIcons.arrow_up_circle_fill,
                    iconColor: Colors.green,
                    isUnread: false,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header per bagian (Terbaru / Sebelumnya)
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

  // Item Notifikasi bergaya Kartu iPhone
  Widget _buildNotificationItem({
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color iconColor,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18), // Sangat membulat
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Garis biru tipis jika belum dibaca
              if (isUnread)
                Container(width: 4, color: Colors.blueAccent)
              else
                const SizedBox(width: 4),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ikon Aplikasi/Kategori
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),

                      // Teks Notifikasi
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
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
      ),
    );
  }
}