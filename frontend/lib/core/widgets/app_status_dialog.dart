import 'package:flutter/material.dart';

class AppStatusDialog extends StatelessWidget {
  final bool isSuccess;
  final String title;
  final String message;
  final VoidCallback onOk;

  const AppStatusDialog({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    required this.onOk,
  });

  static Future<void> show(BuildContext context, {required bool isSuccess, required String title, required String message, required VoidCallback onOk}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppStatusDialog(isSuccess: isSuccess, title: title, message: message, onOk: onOk),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? const Color(0xFF00695C) : const Color(0xFFC62828),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006699), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}