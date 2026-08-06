import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  // Ganti dengan WEB Client ID yang Anda dapatkan di Google Cloud Console
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '951172436848-5ic7r0s1dmbege4opmavb6fqanlsoguf.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  Future<String?> signIn() async {
    try {
      // ✅ Paksa sign out dulu, supaya popup pilih akun Google SELALU muncul
      //    (mencegah otomatis pakai akun sebelumnya yang belum selesai daftar)
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;
      return auth.idToken; // Token inilah yang akan kita kirim ke backend Golang
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}