package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/smtp"
	"os"
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
		FromEmail: os.Getenv("SMTP_FROM_EMAIL"), // Pastikan sama dengan SMTP_USER
		FromName:  "GdSelf App",
		SMTPHost:  "smtp.gmail.com",
		SMTPPort:  "587",
		SMTPUser:  os.Getenv("SMTP_USER"),     // Email Gmail kamu
		SMTPPass:  os.Getenv("SMTP_APP_PASS"), // App Password 16 digit
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
	if s.SMTPUser == "" || s.SMTPPass == "" {
		return fmt.Errorf("SMTP_USER atau SMTP_APP_PASS belum diset di environment variable")
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

	// Format Header yang bersih disesuaikan
	headers := "From: " + from + "\r\n" +
		"To: " + toEmail + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"MIME-Version: 1.0;\r\n" +
		"Content-Type: text/html; charset=\"UTF-8\";\r\n\r\n"

	msg := []byte(headers + htmlBody)

	// Menggunakan smtp.SendMail bawaan seperti kode temanmu
	addr := s.SMTPHost + ":" + s.SMTPPort
	auth := smtp.PlainAuth("", s.SMTPUser, s.SMTPPass, s.SMTPHost)

	err := smtp.SendMail(addr, auth, s.FromEmail, []string{toEmail}, msg)
	if err != nil {
		fmt.Printf("SMTP Error: %v\n", err)
		return fmt.Errorf("gagal mengirim email: %v", err)
	}

	return nil
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