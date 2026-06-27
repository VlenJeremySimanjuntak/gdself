package services

import (
	"crypto/rand"
	"crypto/tls"
	"fmt"
	"math/big"
	"net"
	"net/smtp"
	"os"
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
	return &EmailService{
		FromEmail: os.Getenv("SMTP_FROM_EMAIL"), // email yang terverifikasi di SendGrid
		FromName:  "GdSelf App",
		SMTPHost:  "smtp.sendgrid.net",
		SMTPPort:  "587",
		SMTPUser:  "apikey", // ✅ WAJIB literal string "apikey", bukan email — ini standar SendGrid
		SMTPPass:  os.Getenv("SENDGRID_API_KEY"), // API Key dari SendGrid, bukan password
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
	if s.SMTPPass == "" {
		return fmt.Errorf("SENDGRID_API_KEY belum diset di environment variable")
	}

	var subject, htmlBody string
	switch emailType {
	case "register":
		subject = "Kode Verifikasi Pendaftaran GdSelf"
		htmlBody = s.buildRegisterEmailBody(otpCode)
	case "reset_password":
		subject = "Kode Reset Password GdSelf"
		htmlBody = s.buildResetPasswordEmailBody(otpCode)
	default:
		subject = "Kode Verifikasi GdSelf"
		htmlBody = s.buildRegisterEmailBody(otpCode)
	}

	from := fmt.Sprintf("%s <%s>", s.FromName, s.FromEmail)
	msg := []byte(
		"From: " + from + "\r\n" +
			"To: " + toEmail + "\r\n" +
			"Subject: " + subject + "\r\n" +
			"MIME-Version: 1.0\r\n" +
			"Content-Type: text/html; charset=\"UTF-8\"\r\n" +
			"\r\n" +
			htmlBody + "\r\n")

	return s.sendWithTimeout(toEmail, msg, 8*time.Second)
}

// ✅ Kirim dengan timeout manual, supaya kalau port diblokir, gagal CEPAT (8s)
// bukannya nunggu sampai 30s digantung Railway gateway.
func (s *EmailService) sendWithTimeout(toEmail string, msg []byte, timeout time.Duration) error {
	addr := s.SMTPHost + ":" + s.SMTPPort

	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return fmt.Errorf("gagal konek ke %s (kemungkinan port diblokir): %v", addr, err)
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, s.SMTPHost)
	if err != nil {
		return fmt.Errorf("gagal membuat SMTP client: %v", err)
	}
	defer client.Close()

	if err = client.StartTLS(&tls.Config{ServerName: s.SMTPHost}); err != nil {
		return fmt.Errorf("gagal StartTLS: %v", err)
	}

	auth := smtp.PlainAuth("", s.SMTPUser, s.SMTPPass, s.SMTPHost)
	if err = client.Auth(auth); err != nil {
		return fmt.Errorf("gagal autentikasi SMTP (cek API Key/App Password): %v", err)
	}

	if err = client.Mail(s.FromEmail); err != nil {
		return fmt.Errorf("gagal set From: %v", err)
	}
	if err = client.Rcpt(toEmail); err != nil {
		return fmt.Errorf("gagal set To: %v", err)
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("gagal membuka data writer: %v", err)
	}
	_, err = w.Write(msg)
	if err != nil {
		return fmt.Errorf("gagal menulis pesan: %v", err)
	}
	if err = w.Close(); err != nil {
		return fmt.Errorf("gagal menutup data writer: %v", err)
	}

	return client.Quit()
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
  </div>
</body>
</html>`, otp)
}