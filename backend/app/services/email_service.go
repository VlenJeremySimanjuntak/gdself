package services

import (
    "crypto/tls"
    "fmt"
    "math/big"
    "crypto/rand"
    "net"
    "net/smtp"
    "os"
    "time"
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
    if s.SMTPUser == "" || s.SMTPPassword == "" {
        return fmt.Errorf("konfigurasi email belum diatur di server")
    }

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

    // ✅ Gunakan port 465 (SSL) bukan 587 (STARTTLS)
    // Railway sering blokir 587 tapi tidak 465
    tlsConfig := &tls.Config{
        ServerName: "smtp.gmail.com",
    }

    // ✅ Dial dengan timeout 10 detik
    dialer := &net.Dialer{Timeout: 10 * time.Second}
    conn, err := tls.DialWithDialer(dialer, "tcp", "smtp.gmail.com:465", tlsConfig)
    if err != nil {
        return fmt.Errorf("gagal konek ke server email: %v", err)
    }
    defer conn.Close()

    client, err := smtp.NewClient(conn, "smtp.gmail.com")
    if err != nil {
        return fmt.Errorf("gagal membuat SMTP client: %v", err)
    }
    defer client.Close()

    // Auth
    auth := smtp.PlainAuth("", s.SMTPUser, s.SMTPPassword, "smtp.gmail.com")
    if err = client.Auth(auth); err != nil {
        return fmt.Errorf("autentikasi email gagal: %v", err)
    }

    // Set sender
    if err = client.Mail(s.FromEmail); err != nil {
        return fmt.Errorf("gagal set pengirim: %v", err)
    }

    // Set recipient
    if err = client.Rcpt(toEmail); err != nil {
        return fmt.Errorf("gagal set penerima: %v", err)
    }

    // Tulis pesan
    w, err := client.Data()
    if err != nil {
        return fmt.Errorf("gagal membuka data writer: %v", err)
    }

    headers := fmt.Sprintf(
        "From: %s <%s>\r\nTo: %s\r\nSubject: %s\r\nMIME-Version: 1.0\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n",
        s.FromName, s.FromEmail, toEmail, subject,
    )

    _, err = fmt.Fprint(w, headers+body)
    if err != nil {
        return fmt.Errorf("gagal menulis pesan: %v", err)
    }

    return w.Close()
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