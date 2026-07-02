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
	SendOTP(email, otpType string) error
	VerifyOTP(email, code, otpType string) error
	GoogleCheck(idToken string) (models.GoogleLoginResponse, error)
	GoogleComplete(idToken, password, jenisKelamin string, tglLahir, tglTerdiagnosis *models.CustomDate) (models.User, error)
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
	if otpType == "register" {
		existing, err := u.userRepo.GetByEmail(email)
		if err == nil && existing.IDUser != 0 {
			return fmt.Errorf("email sudah terdaftar")
		}
	}

	if otpType == "reset_password" {
		existing, err := u.userRepo.GetByEmail(email)
		if err != nil || existing.IDUser == 0 {
			return fmt.Errorf("email tidak terdaftar")
		}
		
		// ✅ FIX BUG: Cek apakah password kosong (bukan cek provider google)
		// Jadi kalau user daftar via Google tapi sudah buat password, dia TETAP BISA reset password!
		if existing.Password == "" {
			return fmt.Errorf("akun ini terdaftar menggunakan Google dan belum memiliki password. Silakan masuk menggunakan tombol Google")
		}
	}

	u.otpRepo.DeleteByEmail(email, otpType)

	code, err := services.GenerateOTP()
	if err != nil {
		return fmt.Errorf("gagal generate OTP")
	}

	otp := models.OTPCode{
		Email:     email,
		Code:      code,
		Type:      otpType,
		Used:      false,
		ExpiredAt: time.Now().Add(10 * time.Minute),
	}
	_, err = u.otpRepo.Create(otp)
	if err != nil {
		return fmt.Errorf("gagal menyimpan OTP ke database: %v", err)
	}

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

	return u.otpRepo.MarkAsUsed(otp.ID)
}

// ── GoogleCheck ───────────────────────────────────────────────────────────────
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

	user, err := u.userRepo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return models.GoogleLoginResponse{
			IsNewUser:   true,
			GoogleEmail: email,
			GoogleName:  name,
			GooglePhoto: picture,
		}, nil
	}

	if user.FotoProfil == "" && picture != "" {
		user.FotoProfil = picture
		u.userRepo.Update(user.IDUser, user)
	}

	return models.GoogleLoginResponse{
		IsNewUser:   false,
		GoogleEmail: email,
	}, nil
}

// ── GoogleComplete ────────────────────────────────────────────────────────────
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

	existing, err := u.userRepo.GetByEmail(email)
	if err == nil && existing.IDUser != 0 {
		return models.User{}, fmt.Errorf("email sudah terdaftar")
	}

	hashedPassword, err := helpers.HashPassword(password)
	if err != nil {
		return models.User{}, fmt.Errorf("gagal mengenkripsi password")
	}

	// ✅ FIX BUG: Provider diset "local" karena user membuat password!
	// Ini membuat mereka bisa login manual seperti biasa nantinya.
	newUser := models.User{
		Nama:            name,
		Email:           email,
		Password:        string(hashedPassword),
		Provider:        "local", // <--- INI KUNCINYA
		JenisKelamin:    jenisKelamin,
		FotoProfil:      picture,
		TglLahir:        tglLahir,
		TglTerdiagnosis: tglTerdiagnosis,
	}

	return u.userRepo.Create(newUser)
}

// ── ForgotPassword & ResetPassword ────────────────────────────────────────────
func (u *authUsecase) ForgotPassword(email string) error {
	return u.SendOTP(email, "reset_password")
}

func (u *authUsecase) ResetPassword(email, code, newPassword string) error {
    otp, err := u.otpRepo.GetUsedOTPByEmail(email, "reset_password")
    if err != nil {
        return fmt.Errorf("sesi reset password tidak valid atau sudah kedaluwarsa")
    }

    if otp.Code != code {
        return fmt.Errorf("sesi reset password tidak valid")
    }

    if time.Now().After(otp.ExpiredAt) {
        return fmt.Errorf("sesi reset password sudah kedaluwarsa, silakan ulangi")
    }

    user, err := u.userRepo.GetByEmail(email)
    if err != nil || user.IDUser == 0 {
        return fmt.Errorf("user tidak ditemukan")
    }

    hashedPassword, err := helpers.HashPassword(newPassword)
    if err != nil {
        return fmt.Errorf("gagal mengenkripsi password")
    }

    // ✅ Update langsung ke kolom password saja pakai DB raw update
    // Hindari pakai u.userRepo.Update() yang mungkin skip password field
    err = repositories.DB.Model(&models.User{}).
        Where("id_user = ?", user.IDUser).
        Update("password", string(hashedPassword)).Error
    if err != nil {
        return fmt.Errorf("gagal menyimpan password baru: %v", err)
    }

    u.otpRepo.DeleteByEmail(email, "reset_password")
    return nil
}