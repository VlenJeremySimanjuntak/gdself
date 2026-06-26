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
    Password  string
}

func NewEmailService() *EmailService {
    return &EmailService{
        FromEmail: os.Getenv("SMTP_EMAIL"),
        FromName:  "GdSelf App",
        SMTPHost:  "smtp.gmail.com",
        SMTPPort:  "587",
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

    msg := "From: " + s.FromName + " <" + s.FromEmail + ">\r\n" +
        "To: " + toEmail + "\r\n" +
        "Subject: " + subject + "\r\n" +
        "MIME-Version: 1.0\r\n" +
        "Content-Type: text/html; charset=UTF-8\r\n" +
        "\r\n" +
        body

    err := smtp.SendMail(
        s.SMTPHost+":"+s.SMTPPort,
        auth,
        s.FromEmail,
        []string{toEmail},
        []byte(msg),
    )
    if err != nil {
        return fmt.Errorf("gagal mengirim email: %v", err)
    }

    return nil
}