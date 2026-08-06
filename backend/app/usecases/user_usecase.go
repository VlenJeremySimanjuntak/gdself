package usecases

import (
	"context"
	"fmt"
	"log"
	"net/mail"
	"os"
	"path/filepath"
	"strings"
	"time"

	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
	"monitoring-service/app/services"

	"google.golang.org/api/idtoken"
)

type UserUsecase interface {
	CreateUser(user models.User) (models.User, error)
	Authenticate(email, password string) (models.User, error)
	GoogleLogin(idToken string) (models.User, error)
	GetUserByID(id uint) (models.User, error)
	GetUserByEmail(email string) (models.User, error)
	GetAllUsers() ([]models.User, error)
	UpdateUser(id uint, input models.UpdateUserRequest) (models.User, error)
	DeleteUser(id uint) error
	UploadAvatar(id uint, avatarURL string) (models.User, error)

	RequestDeleteAccountOTP(id uint) error
	DeleteAccount(id uint, code, confirmation string) error
	WebDeleteAccount(email, password string) error
}

type userUsecase struct {
	repo    repositories.UserRepository
	otpRepo repositories.OTPRepository
	email   *services.EmailService
}

func NewUserUsecase(repo repositories.UserRepository, otpRepo repositories.OTPRepository) UserUsecase {
	return &userUsecase{
		repo:    repo,
		otpRepo: otpRepo,
		email:   services.NewEmailService(),
	}
}

func (u *userUsecase) CreateUser(user models.User) (models.User, error) {
	if user.Email == "" || user.Nama == "" || user.Password == "" {
		return models.User{}, fmt.Errorf("email, nama, dan password tidak boleh kosong")
	}

	if _, err := mail.ParseAddress(user.Email); err != nil {
		return models.User{}, fmt.Errorf("format email tidak valid")
	}

	existingUser, err := u.repo.GetByEmail(user.Email)
	if err == nil && existingUser.IDUser != 0 {
		return models.User{}, fmt.Errorf("email sudah terdaftar")
	}

	hashedPassword, err := helpers.HashPassword(user.Password)
	if err != nil {
		return models.User{}, fmt.Errorf("gagal mengenkripsi password: %w", err)
	}
	user.Password = string(hashedPassword)

	user.Provider = "local"

	return u.repo.Create(user)
}

func (u *userUsecase) Authenticate(email, password string) (models.User, error) {
	if email == "" || password == "" {
		return models.User{}, fmt.Errorf("email dan password wajib diisi")
	}

	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("email atau password salah")
	}

	if user.Password == "" {
		return models.User{}, fmt.Errorf("akun ini terdaftar menggunakan Google. Silakan masuk dengan tombol 'Masuk dengan Google'")
	}

	if err := helpers.VerifyPassword(user.Password, password); err == nil {
		return user, nil
	}

	return models.User{}, fmt.Errorf("email atau password salah")
}

func (u *userUsecase) GoogleLogin(idToken string) (models.User, error) {
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

	var picture string
	if picClaim, ok := payload.Claims["picture"]; ok {
		picture = picClaim.(string)
	}

	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		newUser := models.User{
			Nama:         name,
			Email:        email,
			Password:     "",
			JenisKelamin: "L",
			FotoProfil:   picture,
			Provider:     "google",
		}

		createdUser, createErr := u.repo.Create(newUser)
		if createErr != nil {
			return models.User{}, fmt.Errorf("gagal membuat user baru: %w", createErr)
		}
		return createdUser, nil
	}

	needsUpdate := false
	if user.Provider != "google" {
		if user.Password == "" {
			user.Provider = "google"
			needsUpdate = true
		}
	}

	if user.FotoProfil == "" && picture != "" {
		user.FotoProfil = picture
		needsUpdate = true
	}
	if needsUpdate {
		u.repo.Update(user.IDUser, user)
	}

	return user, nil
}

func (u *userUsecase) GetUserByID(id uint) (models.User, error) {
	if id == 0 {
		return models.User{}, fmt.Errorf("id tidak valid")
	}

	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("user tidak ditemukan")
	}

	return user, nil
}

func (u *userUsecase) GetUserByEmail(email string) (models.User, error) {
	if email == "" {
		return models.User{}, fmt.Errorf("email tidak boleh kosong")
	}

	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("user tidak ditemukan")
	}

	return user, nil
}

func (u *userUsecase) GetAllUsers() ([]models.User, error) {
	return u.repo.GetAllSimple()
}

func (u *userUsecase) UpdateUser(id uint, input models.UpdateUserRequest) (models.User, error) {
	if id == 0 {
		return models.User{}, fmt.Errorf("id tidak valid")
	}

	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("user tidak ditemukan")
	}

	if input.Nama != "" {
		user.Nama = input.Nama
	}
	if input.Email != "" {
		user.Email = input.Email
	}
	if input.TglLahir != nil {
		user.TglLahir = input.TglLahir
	}
	if input.JenisKelamin != "" {
		user.JenisKelamin = input.JenisKelamin
	}
	if input.TglTerdiagnosis != nil {
		user.TglTerdiagnosis = input.TglTerdiagnosis
	}

	return u.repo.Update(id, user)
}

func (u *userUsecase) DeleteUser(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("user tidak ditemukan")
	}

	return u.hardDelete(user)
}

func (u *userUsecase) UploadAvatar(id uint, avatarURL string) (models.User, error) {
	if id == 0 {
		return models.User{}, fmt.Errorf("id tidak valid")
	}

	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("user tidak ditemukan")
	}

	user.FotoProfil = avatarURL

	return u.repo.Update(id, user)
}

func (u *userUsecase) RequestDeleteAccountOTP(id uint) error {
	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("user tidak ditemukan")
	}

	u.otpRepo.DeleteByEmail(user.Email, "delete_account")

	code, err := services.GenerateOTP()
	if err != nil {
		return fmt.Errorf("gagal generate OTP")
	}

	otp := models.OTPCode{
		Email:     user.Email,
		Code:      code,
		Type:      "delete_account",
		Used:      false,
		ExpiredAt: time.Now().Add(10 * time.Minute),
	}
	if _, err := u.otpRepo.Create(otp); err != nil {
		return fmt.Errorf("gagal menyimpan OTP: %w", err)
	}

	return u.email.SendOTPEmail(user.Email, code, "delete_account")
}

func (u *userUsecase) DeleteAccount(id uint, code, confirmation string) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}
	if confirmation != "HAPUS" {
		return fmt.Errorf(`konfirmasi tidak valid: ketik "HAPUS" untuk melanjutkan`)
	}

	user, err := u.repo.GetByIDSimple(id)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("user tidak ditemukan")
	}

	otp, err := u.otpRepo.GetByEmailAndType(user.Email, "delete_account")
	if err != nil {
		return fmt.Errorf("kode OTP tidak valid atau sudah kedaluwarsa")
	}
	if otp.Code != code {
		return fmt.Errorf("kode OTP salah")
	}
	if time.Now().After(otp.ExpiredAt) {
		return fmt.Errorf("kode OTP sudah kedaluwarsa")
	}

	return u.hardDelete(user)
}

func (u *userUsecase) WebDeleteAccount(email, password string) error {
	if email == "" || password == "" {
		return fmt.Errorf("email dan password wajib diisi")
	}

	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("email atau password salah")
	}
	if user.Password == "" {
		return fmt.Errorf("akun ini terdaftar via Google. Silakan hapus melalui aplikasi setelah login Google")
	}
	if err := helpers.VerifyPassword(user.Password, password); err != nil {
		return fmt.Errorf("email atau password salah")
	}

	return u.hardDelete(user)
}

func (u *userUsecase) hardDelete(user models.User) error {
	files, err := u.repo.CollectAccountFiles(user.IDUser)
	if err != nil {
		return fmt.Errorf("gagal mengumpulkan data file: %w", err)
	}

	if err := u.repo.HardDeleteAccountCascade(user.IDUser, user.Email); err != nil {
		return fmt.Errorf("gagal menghapus data akun: %w", err)
	}

	u.removePhysicalFiles(files)

	log.Printf("[AUDIT][HAPUS-AKUN] user_id=%d email=%s waktu_utc=%s jumlah_file_usg=%d avatar_dihapus=%t",
		user.IDUser,
		maskEmailForAudit(user.Email),
		time.Now().UTC().Format(time.RFC3339),
		len(files.UsgPaths),
		files.AvatarPath != "",
	)

	return nil
}

func (u *userUsecase) removePhysicalFiles(files repositories.AccountFiles) {
	if files.AvatarPath != "" && !strings.HasPrefix(files.AvatarPath, "http") {
		if p, err := helpers.SafeUploadPath(filepath.Join("uploads", "avatars"), files.AvatarPath); err == nil {
			if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
				log.Printf("[HAPUS-AKUN] gagal hapus avatar: %v", err)
			}
		}
	}

	for _, fp := range files.UsgPaths {
		if fp == "" {
			continue
		}
		if p, err := helpers.SafeUploadPath(filepath.Join("uploads", "usg"), fp); err == nil {
			if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
				log.Printf("[HAPUS-AKUN] gagal hapus foto usg: %v", err)
			}
		}
		thumb := "thumb_" + filepath.Base(fp)
		if p, err := helpers.SafeUploadPath(filepath.Join("uploads", "usg"), thumb); err == nil {
			if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
				log.Printf("[HAPUS-AKUN] gagal hapus thumbnail usg: %v", err)
			}
		}
	}
}

func maskEmailForAudit(email string) string {
	at := strings.Index(email, "@")
	if at <= 1 {
		return "***"
	}
	return email[:1] + "***" + email[at:]
}