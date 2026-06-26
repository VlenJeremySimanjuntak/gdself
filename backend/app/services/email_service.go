package services

import (
    "crypto/rand"
    "fmt"
    "math/big"
    "net/smtp"
    "os"
    "crypto/tls"
)

type EmailService struct {
    FromEmail string
    FromName  string
    SMTPHost  string
    SMTPPort  string
    Password  string
}

func NewEmailService() *EmailService {
    return &EmailService{
        FromEmail: os.Getenv("SMTP_EMAIL"),
        FromName:  "GdSelf App",
        SMTPHost:  "smtp.gmail.com",
        SMTPPort:  "465",
        Password:  os.Getenv("SMTP_PASSWORD"),
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
    if s.FromEmail == "" || s.Password == "" {
        return fmt.Errorf("SMTP_EMAIL atau SMTP_PASSWORD belum diset")
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

    auth := smtp.PlainAuth("", s.FromEmail, s.Password, s.SMTPHost)

    // Port 465 pakai SSL
    tlsConfig := &tls.Config{
        InsecureSkipVerify: false,
        ServerName:         s.SMTPHost,
    }

    conn, err := tls.Dial("tcp", s.SMTPHost+":"+s.SMTPPort, tlsConfig)
    if err != nil {
        return fmt.Errorf("gagal koneksi SMTP: %v", err)
    }

    client, err := smtp.NewClient(conn, s.SMTPHost)
    if err != nil {
        return fmt.Errorf("gagal buat SMTP client: %v", err)
    }
    defer client.Close()

    if err = client.Auth(auth); err != nil {
        return fmt.Errorf("gagal autentikasi SMTP: %v", err)
    }

    if err = client.Mail(s.FromEmail); err != nil {
        return fmt.Errorf("gagal set sender: %v", err)
    }

    if err = client.Rcpt(toEmail); err != nil {
        return fmt.Errorf("gagal set recipient: %v", err)
    }

    wc, err := client.Data()
    if err != nil {
        return fmt.Errorf("gagal buka data writer: %v", err)
    }

    msg := "From: " + s.FromName + " <" + s.FromEmail + ">\r\n" +
        "To: " + toEmail + "\r\n" +
        "Subject: " + subject + "\r\n" +
        "MIME-Version: 1.0\r\n" +
        "Content-Type: text/html; charset=UTF-8\r\n" +
        "\r\n" +
        body

    _, err = fmt.Fprint(wc, msg)
    if err != nil {
        return fmt.Errorf("gagal tulis pesan: %v", err)
    }

    wc.Close()
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