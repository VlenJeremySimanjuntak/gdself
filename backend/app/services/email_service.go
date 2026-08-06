package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/smtp"
	"os"
	"strings"
	"time"
)

type EmailService struct {
	FromEmail string
	FromName  string
	SMTPHost  string
	SMTPPort  string
	SMTPUser  string
	SMTPPass  string
}

func NewEmailService() *EmailService {
	// Cukup 2 variabel (gaya sederhana): SMTP_EMAIL + SMTP_PASSWORD
	email := os.Getenv("SMTP_EMAIL")       // email Gmail pengirim
	password := os.Getenv("SMTP_PASSWORD") // App Password 16 digit dari Google

	return &EmailService{
		FromEmail: email,
		FromName:  "GdSelf",
		SMTPHost:  "smtp.gmail.com",
		SMTPPort:  "587",
		SMTPUser:  email, // Gmail: user login = email pengirim itu sendiri
		SMTPPass:  password,
	}
}

func GenerateOTP() (string, error) {
	digits := "0123456789"
	otp := make([]byte, 6)
	for i := range otp {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(digits))))
		if err != nil {
			return "", err
		}
		otp[i] = digits[n.Int64()]
	}
	return string(otp), nil
}

func (s *EmailService) SendOTPEmail(toEmail, otpCode, emailType string) error {
	if s.FromEmail == "" || s.SMTPPass == "" {
		return fmt.Errorf("SMTP_EMAIL atau SMTP_PASSWORD belum diset di .env")
	}

	var subject, htmlBody, textBody string
	switch emailType {
	case "register":
		subject = "Kode Verifikasi Pendaftaran GdSelf"
		htmlBody = s.buildRegisterEmailBody(otpCode)
		textBody = s.buildTextBody("menyelesaikan pendaftaran akun", otpCode)
	case "reset_password":
		subject = "Kode Reset Password GdSelf"
		htmlBody = s.buildResetPasswordEmailBody(otpCode)
		textBody = s.buildTextBody("mereset password akun", otpCode)
	case "delete_account":
		subject = "Kode Konfirmasi Hapus Akun GdSelf"
		htmlBody = s.buildDeleteAccountEmailBody(otpCode)
		textBody = s.buildTextBody("mengonfirmasi PENGHAPUSAN PERMANEN akun", otpCode)
	default:
		subject = "Kode Verifikasi GdSelf"
		htmlBody = s.buildRegisterEmailBody(otpCode)
		textBody = s.buildTextBody("verifikasi akun", otpCode)
	}

	msg := s.buildMessage(toEmail, subject, textBody, htmlBody)

	// ✅ SMTP Gmail biasa — pakai smtp.SendMail (otomatis STARTTLS + Auth), gaya sederhana
	auth := smtp.PlainAuth("", s.SMTPUser, s.SMTPPass, s.SMTPHost)
	addr := s.SMTPHost + ":" + s.SMTPPort

	if err := smtp.SendMail(addr, auth, s.FromEmail, []string{toEmail}, msg); err != nil {
		// Print error asli dari Gmail ke terminal biar gampang debug
		fmt.Printf("SMTP Error: %v\n", err)
		return fmt.Errorf("gagal kirim email: %v", err)
	}

	return nil
}

// ✅ Susun email multipart (text/plain + text/html) + header Date & Message-ID.
// Ini trik GRATIS anti-spam tanpa ganti provider — tetap Gmail biasa.
func (s *EmailService) buildMessage(toEmail, subject, textBody, htmlBody string) []byte {
	fromHeader := fmt.Sprintf("%s <%s>", s.FromName, s.FromEmail)
	boundary := "GDSELF_" + s.randomToken()
	date := time.Now().Format(time.RFC1123Z)
	messageID := fmt.Sprintf("<%d.%s@%s>", time.Now().UnixNano(), s.randomToken(), s.senderDomain())

	var b strings.Builder
	b.WriteString("From: " + fromHeader + "\r\n")
	b.WriteString("Reply-To: " + s.FromEmail + "\r\n")
	b.WriteString("To: " + toEmail + "\r\n")
	b.WriteString("Subject: " + subject + "\r\n")
	b.WriteString("Date: " + date + "\r\n")
	b.WriteString("Message-ID: " + messageID + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: multipart/alternative; boundary=\"" + boundary + "\"\r\n")
	b.WriteString("\r\n")

	// Versi teks (wajib ada supaya tidak dinilai "HTML-only" oleh filter spam)
	b.WriteString("--" + boundary + "\r\n")
	b.WriteString("Content-Type: text/plain; charset=\"UTF-8\"\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n")
	b.WriteString("\r\n")
	b.WriteString(textBody + "\r\n")

	// Versi HTML
	b.WriteString("--" + boundary + "\r\n")
	b.WriteString("Content-Type: text/html; charset=\"UTF-8\"\r\n")
	b.WriteString("Content-Transfer-Encoding: 8bit\r\n")
	b.WriteString("\r\n")
	b.WriteString(htmlBody + "\r\n")

	b.WriteString("--" + boundary + "--\r\n")
	return []byte(b.String())
}

// ---- Helpers ----

func (s *EmailService) senderDomain() string {
	at := strings.LastIndex(s.FromEmail, "@")
	if at >= 0 && at < len(s.FromEmail)-1 {
		return s.FromEmail[at+1:]
	}
	return "gmail.com"
}

func (s *EmailService) randomToken() string {
	const chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 16)
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		if err != nil {
			return fmt.Sprintf("%d", time.Now().UnixNano())
		}
		b[i] = chars[n.Int64()]
	}
	return string(b)
}

func (s *EmailService) buildTextBody(purpose, otp string) string {
	return fmt.Sprintf(
		"GdSelf - Aplikasi Pemantau Kesehatan Tiroid\r\n\r\n"+
			"Kode OTP Anda untuk %s adalah: %s\r\n\r\n"+
			"Kode ini berlaku selama 10 menit. Jangan bagikan kode ini kepada siapa pun.\r\n\r\n"+
			"Jika Anda tidak meminta kode ini, abaikan email ini.\r\n\r\n"+
			"— Tim GdSelf\r\n",
		purpose, otp,
	)
}

func (s *EmailService) buildRegisterEmailBody(otp string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
  <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
    <div style="text-align: center; margin-bottom: 24px;">
      <h2 style="color: #005F82; margin: 0;">GdSelf</h2>
      <p style="color: #666; margin-top: 4px;">Aplikasi Pemantau Kesehatan Tiroid</p>
    </div>
    <h3 style="color: #2D4052;">Verifikasi Email Anda</h3>
    <p style="color: #555; line-height: 1.6;">
      Terima kasih telah mendaftar di GdSelf. Gunakan kode OTP berikut untuk menyelesaikan pendaftaran Anda:
    </p>
    <div style="background: #E3F4F4; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
      <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #005F82;">%s</span>
    </div>
    <p style="color: #888; font-size: 13px;">
      Kode ini berlaku selama <strong>10 menit</strong>. Jangan bagikan kode ini kepada siapapun.
    </p>
    <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
    <p style="color:#aaa;font-size:11px;text-align:center;">GdSelf &middot; Email ini dikirim otomatis, mohon tidak membalas.</p>
  </div>
</body>
</html>`, otp)
}

func (s *EmailService) buildResetPasswordEmailBody(otp string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
  <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
    <div style="text-align: center; margin-bottom: 24px;">
      <h2 style="color: #005F82; margin: 0;">GdSelf</h2>
      <p style="color: #666; margin-top: 4px;">Aplikasi Pemantau Kesehatan Tiroid</p>
    </div>
    <h3 style="color: #2D4052;">Reset Password</h3>
    <p style="color: #555; line-height: 1.6;">
      Kami menerima permintaan reset password untuk akun Anda. Gunakan kode OTP berikut:
    </p>
    <div style="background: #FFF3E0; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
      <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #E65100;">%s</span>
    </div>
    <p style="color: #888; font-size: 13px;">
      Kode ini berlaku selama <strong>10 menit</strong>. Jangan bagikan kode ini kepada siapapun.
    </p>
    <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
    <p style="color:#aaa;font-size:11px;text-align:center;">GdSelf &middot; Email ini dikirim otomatis, mohon tidak membalas.</p>
  </div>
</body>
</html>`, otp)
}

func (s *EmailService) buildDeleteAccountEmailBody(otp string) string {
	return fmt.Sprintf(`<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; padding: 20px;">
  <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); border-top: 5px solid #C62828;">
    <div style="text-align: center; margin-bottom: 24px;">
      <h2 style="color: #005F82; margin: 0;">GdSelf</h2>
      <p style="color: #666; margin-top: 4px;">Aplikasi Pemantau Kesehatan Tiroid</p>
    </div>
    <h3 style="color: #C62828;">⚠️ Konfirmasi Hapus Akun Permanen</h3>
    <p style="color: #555; line-height: 1.6;">
      Kami menerima permintaan untuk <strong>menghapus akun Anda secara permanen</strong>, termasuk seluruh data medis (riwayat, hasil lab, foto USG, jadwal obat). Tindakan ini <strong>tidak dapat dibatalkan</strong>.
    </p>
    <p style="color: #555; line-height: 1.6;">Gunakan kode konfirmasi berikut untuk melanjutkan:</p>
    <div style="background: #FFF5F5; border: 1px solid #F5C6C6; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
      <span style="font-size: 36px; font-weight: bold; letter-spacing: 8px; color: #C62828;">%s</span>
    </div>
    <p style="color: #888; font-size: 13px;">
      Kode ini berlaku selama <strong>10 menit</strong>. Jika Anda <strong>tidak</strong> meminta penghapusan akun, <strong>abaikan email ini</strong> dan segera ganti password Anda.
    </p>
    <hr style="border:none;border-top:1px solid #eee;margin:24px 0;">
    <p style="color:#aaa;font-size:11px;text-align:center;">GdSelf &middot; Email ini dikirim otomatis, mohon tidak membalas.</p>
  </div>
</body>
</html>`, otp)
}