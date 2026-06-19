package usecases

import (
	"context"
	"fmt"
	"os"
	"time"

	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

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
}

type userUsecase struct {
	repo repositories.UserRepository
}

func NewUserUsecase(repo repositories.UserRepository) UserUsecase {
	return &userUsecase{repo: repo}
}

func (u *userUsecase) CreateUser(user models.User) (models.User, error) {
	if user.Email == "" || user.Nama == "" || user.Password == "" {
		return models.User{}, fmt.Errorf("email, nama, dan password tidak boleh kosong")
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

	// ✅ Pastikan user biasa selalu Provider = "local"
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

	// ✅ Cek Provider — lebih eksplisit dari cek password kosong
	if user.Provider == "google" {
		return models.User{}, fmt.Errorf("akun ini terdaftar menggunakan Google. Silakan masuk dengan tombol 'Masuk dengan Google'")
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
		// User belum ada → buat baru dengan Provider = "google"
		newUser := models.User{
			Nama:         name,
			Email:        email,
			Password:     "",
			JenisKelamin: "L",
			FotoProfil:   picture,
			Provider:     "google", // ✅ set Provider saat buat user baru via Google
		}

		createdUser, createErr := u.repo.Create(newUser)
		if createErr != nil {
			return models.User{}, fmt.Errorf("gagal membuat user baru: %w", createErr)
		}
		return createdUser, nil
	}

	// User sudah ada → update Provider ke "google" kalau belum, dan foto kalau kosong
	needsUpdate := false
	if user.Provider != "google" {
		user.Provider = "google" // ✅ update Provider untuk akun lama yang belum punya provider
		needsUpdate = true
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

	return u.repo.Delete(id)
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