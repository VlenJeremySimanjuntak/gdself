package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/smtp"
	"os"
	"strings"
)

type EmailService struct {
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	FromEmail    string
	FromName     string
}

func NewEmailService() *EmailService {
	return &EmailService{
		SMTPHost:     "smtp.gmail.com",
		SMTPPort:     "587",
		SMTPUser:     os.Getenv("GMAIL_USER"),     // email Gmail mas
		SMTPPassword: os.Getenv("GMAIL_APP_PASS"), // App Password Gmail
		FromEmail:    os.Getenv("GMAIL_USER"),
		FromName:     "GdSelf App",
	}
}

// GenerateOTP membuat kode OTP 6 digit acak
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

// SendOTPEmail mengirim email OTP ke user
func (s *EmailService) SendOTPEmail(toEmail, otpCode, emailType string) error {
	var subject, body string

	switch emailType {
	case "register":
		subject = "Kode Verifikasi Pendaftaran GdSelf"
		body = s.buildRegisterEmailBody(otpCode)
	case "reset_password":
		subject = "Kode Reset Password GdSelf"
		body = s.buildResetPasswordEmailBody(otpCode)
	default:
		subject = "Kode Verifikasi GdSelf"
		body = s.buildRegisterEmailBody(otpCode)
	}

	auth := smtp.PlainAuth("", s.SMTPUser, s.SMTPPassword, s.SMTPHost)

	// Header email
	headers := make(map[string]string)
	headers["From"] = fmt.Sprintf("%s <%s>", s.FromName, s.FromEmail)
	headers["To"] = toEmail
	headers["Subject"] = subject
	headers["MIME-Version"] = "1.0"
	headers["Content-Type"] = "text/html; charset=UTF-8"

	var message strings.Builder
	for k, v := range headers {
		message.WriteString(fmt.Sprintf("%s: %s\r\n", k, v))
	}
	message.WriteString("\r\n")
	message.WriteString(body)

	addr := fmt.Sprintf("%s:%s", s.SMTPHost, s.SMTPPort)
	return smtp.SendMail(addr, auth, s.FromEmail, []string{toEmail}, []byte(message.String()))
}

func (s *EmailService) buildRegisterEmailBody(otp string) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
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
    <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
    <p style="color: #aaa; font-size: 12px; text-align: center;">
      Jika Anda tidak merasa mendaftar di GdSelf, abaikan email ini.
    </p>
  </div>
</body>
</html>`, otp)
}

func (s *EmailService) buildResetPasswordEmailBody(otp string) string {
	return fmt.Sprintf(`
<!DOCTYPE html>
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
    <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
    <p style="color: #aaa; font-size: 12px; text-align: center;">
      Jika Anda tidak meminta reset password, abaikan email ini. Password Anda tidak akan berubah.
    </p>
  </div>
</body>
</html>`, otp)
}