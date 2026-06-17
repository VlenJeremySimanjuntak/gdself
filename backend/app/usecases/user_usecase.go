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

	// ✅ Cek existing user dengan GetByEmail (tanpa Preload)
	existingUser, err := u.repo.GetByEmail(user.Email)
	if err == nil && existingUser.IDUser != 0 {
		return models.User{}, fmt.Errorf("email sudah terdaftar")
	}

	// Hash password dengan timeout
	hashedPassword, err := helpers.HashPassword(user.Password)
	if err != nil {
		return models.User{}, fmt.Errorf("gagal mengenkripsi password: %w", err)
	}
	user.Password = string(hashedPassword)

	return u.repo.Create(user)
}

func (u *userUsecase) Authenticate(email, password string) (models.User, error) {
	if email == "" || password == "" {
		return models.User{}, fmt.Errorf("email dan password wajib diisi")
	}

	// ✅ GetByEmail tanpa Preload
	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("email atau password salah")
	}

	if user.Password == "" {
		return models.User{}, fmt.Errorf("akun ini terdaftar menggunakan Google")
	}

	// Verify password dengan timeout
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

	// ✅ Tambahkan timeout context
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

	// ✅ GetByEmail tanpa Preload
	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		newUser := models.User{
			Nama:         name,
			Email:        email,
			Password:     "",
			JenisKelamin: "L",
			FotoProfil:   picture,
		}

		createdUser, createErr := u.repo.Create(newUser)
		if createErr != nil {
			return models.User{}, fmt.Errorf("gagal membuat user baru: %w", createErr)
		}
		return createdUser, nil
	}

	if user.FotoProfil == "" && picture != "" {
		user.FotoProfil = picture
		u.repo.Update(user.IDUser, user)
	}

	return user, nil
}

// ✅ GUNAKAN GetByIDSimple
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

// ✅ GUNAKAN GetAllSimple (CEPAT)
func (u *userUsecase) GetAllUsers() ([]models.User, error) {
	return u.repo.GetAllSimple()
}

// ✅ GUNAKAN GetByIDSimple
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

// ✅ GUNAKAN GetByIDSimple
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