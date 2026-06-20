package usecases

import (
	"context"
	"fmt"
	"os"
	"time"

	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
	"monitoring-service/app/services"

	"google.golang.org/api/idtoken"
)

type AuthUsecase interface {
	// OTP
	SendOTP(email, otpType string) error
	VerifyOTP(email, code, otpType string) error

	// Google flow baru
	GoogleCheck(idToken string) (models.GoogleLoginResponse, error)
	GoogleComplete(idToken, password, jenisKelamin string, tglLahir, tglTerdiagnosis *models.CustomDate) (models.User, error)

	// Reset password
	ForgotPassword(email string) error
	ResetPassword(email, code, newPassword string) error
}

type authUsecase struct {
	userRepo repositories.UserRepository
	otpRepo  repositories.OTPRepository
	email    *services.EmailService
}

func NewAuthUsecase(
	userRepo repositories.UserRepository,
	otpRepo repositories.OTPRepository,
) AuthUsecase {
	return &authUsecase{
		userRepo: userRepo,
		otpRepo:  otpRepo,
		email:    services.NewEmailService(),
	}
}

// ── SendOTP ──────────────────────────────────────────────────────────────────
func (u *authUsecase) SendOTP(email, otpType string) error {
	// Untuk register: cek email belum terdaftar
	if otpType == "register" {
		existing, err := u.userRepo.GetByEmail(email)
		if err == nil && existing.IDUser != 0 {
			return fmt.Errorf("email sudah terdaftar")
		}
	}

	// Untuk reset_password: cek email sudah terdaftar dan bukan Google
	if otpType == "reset_password" {
		existing, err := u.userRepo.GetByEmail(email)
		if err != nil || existing.IDUser == 0 {
			return fmt.Errorf("email tidak terdaftar")
		}
		if existing.Provider == "google" {
			return fmt.Errorf("akun ini menggunakan Google Sign-In, tidak dapat reset password")
		}
	}

	// Hapus OTP lama untuk email ini
	u.otpRepo.DeleteByEmail(email, otpType)

	// Generate OTP baru
	code, err := services.GenerateOTP()
	if err != nil {
		return fmt.Errorf("gagal generate OTP")
	}

	// Simpan ke DB
	otp := models.OTPCode{
		Email:     email,
		Code:      code,
		Type:      otpType,
		Used:      false,
		ExpiredAt: time.Now().Add(10 * time.Minute),
	}
	_, err = u.otpRepo.Create(otp)
	if err != nil {
		return fmt.Errorf("gagal menyimpan OTP")
	}

	// Kirim email
	return u.email.SendOTPEmail(email, code, otpType)
}

// ── VerifyOTP ─────────────────────────────────────────────────────────────────
func (u *authUsecase) VerifyOTP(email, code, otpType string) error {
	otp, err := u.otpRepo.GetByEmailAndType(email, otpType)
	if err != nil {
		return fmt.Errorf("kode OTP tidak valid atau sudah kedaluwarsa")
	}

	if otp.Code != code {
		return fmt.Errorf("kode OTP salah")
	}

	if time.Now().After(otp.ExpiredAt) {
		return fmt.Errorf("kode OTP sudah kedaluwarsa")
	}

	// Tandai sudah dipakai
	return u.otpRepo.MarkAsUsed(otp.ID)
}

// ── GoogleCheck ───────────────────────────────────────────────────────────────
// Cek apakah user Google sudah ada di sistem atau belum
func (u *authUsecase) GoogleCheck(idToken string) (models.GoogleLoginResponse, error) {
	clientID := os.Getenv("GOOGLE_CLIENT_ID")
	if clientID == "" {
		return models.GoogleLoginResponse{}, fmt.Errorf("server error: GOOGLE_CLIENT_ID tidak disetting")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	payload, err := idtoken.Validate(ctx, idToken, clientID)
	if err != nil {
		return models.GoogleLoginResponse{}, fmt.Errorf("token google tidak valid: %w", err)
	}

	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	picture, _ := payload.Claims["picture"].(string)

	// Cek apakah user sudah ada
	user, err := u.userRepo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		// User belum ada → return new_user flag
		return models.GoogleLoginResponse{
			IsNewUser:   true,
			GoogleEmail: email,
			GoogleName:  name,
			GooglePhoto: picture,
		}, nil
	}

	// User sudah ada → update foto kalau perlu, return token
	if user.FotoProfil == "" && picture != "" {
		user.FotoProfil = picture
		u.userRepo.Update(user.IDUser, user)
	}

	return models.GoogleLoginResponse{
		IsNewUser: false,
	}, nil
}

// ── GoogleComplete ────────────────────────────────────────────────────────────
// Selesaikan registrasi Google user baru dengan data tambahan
func (u *authUsecase) GoogleComplete(
	idToken, password, jenisKelamin string,
	tglLahir, tglTerdiagnosis *models.CustomDate,
) (models.User, error) {
	clientID := os.Getenv("GOOGLE_CLIENT_ID")
	if clientID == "" {
		return models.User{}, fmt.Errorf("server error: GOOGLE_CLIENT_ID tidak disetting")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	payload, err := idtoken.Validate(ctx, idToken, clientID)
	if err != nil {
		return models.User{}, fmt.Errorf("token google tidak valid: %w", err)
	}

	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	picture, _ := payload.Claims["picture"].(string)

	// Pastikan belum ada akun dengan email ini
	existing, err := u.userRepo.GetByEmail(email)
	if err == nil && existing.IDUser != 0 {
		return models.User{}, fmt.Errorf("email sudah terdaftar")
	}

	// Hash password yang diberikan user
	hashedPassword, err := helpers.HashPassword(password)
	if err != nil {
		return models.User{}, fmt.Errorf("gagal mengenkripsi password")
	}

	// Buat user baru — provider tetap "google" tapi sekarang punya password
	newUser := models.User{
		Nama:            name,
		Email:           email,
		Password:        string(hashedPassword),
		Provider:        "google",
		JenisKelamin:    jenisKelamin,
		FotoProfil:      picture,
		TglLahir:        tglLahir,
		TglTerdiagnosis: tglTerdiagnosis,
	}

	return u.userRepo.Create(newUser)
}

// ── ForgotPassword ────────────────────────────────────────────────────────────
func (u *authUsecase) ForgotPassword(email string) error {
	return u.SendOTP(email, "reset_password")
}

// ── ResetPassword ─────────────────────────────────────────────────────────────
func (u *authUsecase) ResetPassword(email, code, newPassword string) error {
	// Verifikasi OTP
	if err := u.VerifyOTP(email, code, "reset_password"); err != nil {
		return err
	}

	// Ambil user
	user, err := u.userRepo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("user tidak ditemukan")
	}

	// Hash password baru
	hashedPassword, err := helpers.HashPassword(newPassword)
	if err != nil {
		return fmt.Errorf("gagal mengenkripsi password")
	}

	// Update password
	user.Password = string(hashedPassword)
	_, err = u.userRepo.Update(user.IDUser, user)
	return err
}