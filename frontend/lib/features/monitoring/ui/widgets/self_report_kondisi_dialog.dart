import 'package:flutter/material.dart';
import '../../../../utils/design_system.dart';

enum KondisiPengguna { baik, cukupLelah, tidakNyaman }

class SelfReportKondisiDialog extends StatelessWidget {
  const SelfReportKondisiDialog({super.key});

  static Future<KondisiPengguna?> show(BuildContext context) {
    return showDialog<KondisiPengguna>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SelfReportKondisiDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sebelum Mulai",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              "Bagaimana kondisi Anda saat ini? Ini membantu kami "
                  "menyesuaikan cara sistem membantu Anda mengisi data.",
              style: TextStyle(
                  fontSize: 13, color: AppColors.textGrey, height: 1.5),
            ),
            const SizedBox(height: 24),
            _opsiKondisi(
              context,
              emoji: "🙂",
              label: "Baik",
              sub: "Saya merasa nyaman dan siap mengisi data",
              kondisi: KondisiPengguna.baik,
            ),
            const SizedBox(height: 12),
            _opsiKondisi(
              context,
              emoji: "😐",
              label: "Cukup Lelah",
              sub: "Saya sedikit lelah, tapi bisa lanjut",
              kondisi: KondisiPengguna.cukupLelah,
            ),
            const SizedBox(height: 12),
            _opsiKondisi(
              context,
              emoji: "😣",
              label: "Tremor / Tidak Nyaman",
              sub: "Tangan gemetar atau sulit fokus saat ini",
              kondisi: KondisiPengguna.tidakNyaman,
            ),
          ],
        ),
      ),
    );
  }

  Widget _opsiKondisi(
      BuildContext context, {
        required String emoji,
        required String label,
        required String sub,
        required KondisiPengguna kondisi,
      }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(context, kondisi),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textGrey, size: 20),
          ],
        ),
      ),
    );
  }
}