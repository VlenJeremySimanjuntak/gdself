package services

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"os"
	"time"
)

type EmailService struct {
	FromEmail string
	FromName  string
	APIKey    string
}

func NewEmailService() *EmailService {
	return &EmailService{
		FromEmail: "onboarding@resend.dev",
		FromName:  "GdSelf App",
		APIKey:    os.Getenv("RESEND_API_KEY"),
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
	if s.APIKey == "" {
		return fmt.Errorf("RESEND_API_KEY belum diset di environment variable")
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

	payload := map[string]interface{}{
		"from":    fmt.Sprintf("%s <%s>", s.FromName, s.FromEmail),
		"to":      []string{toEmail},
		"subject": subject,
		"html":    htmlBody,
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("gagal membuat payload email: %v", err)
	}

	req, err := http.NewRequest("POST", "https://api.resend.com/emails",
		bytes.NewReader(payloadBytes))
	if err != nil {
		return fmt.Errorf("gagal membuat request: %v", err)
	}

	req.Header.Set("Authorization", "Bearer "+s.APIKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("gagal mengirim email: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 && resp.StatusCode != 201 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Resend API error %d: %s", resp.StatusCode, string(body))
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