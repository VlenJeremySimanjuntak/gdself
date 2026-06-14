package usecases

import (
	"context"
	"fmt"
	"os"

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

	// Check if email already exists
	existingUser, err := u.repo.GetByEmail(user.Email)
	if err == nil && existingUser.IDUser != 0 {
		return models.User{}, fmt.Errorf("email sudah terdaftar")
	}

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

	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("email atau password salah")
	}

	if user.Password == "" {
		return models.User{}, fmt.Errorf("akun ini terdaftar menggunakan Google. Silakan klik 'Masuk dengan Google'")
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

	// 1. Verifikasi token ke Google
	payload, err := idtoken.Validate(context.Background(), idToken, clientID)
	if err != nil {
		return models.User{}, fmt.Errorf("token google tidak valid: %w", err)
	}

	// 2. Ambil data email dan nama dari payload Google
	email := payload.Claims["email"].(string)
	name := payload.Claims["name"].(string)

	// 3. Cek apakah user sudah ada di database
	user, err := u.repo.GetByEmail(email)
	if err != nil || user.IDUser == 0 {
		// 4. Jika belum ada, buatkan user baru secara otomatis
		newUser := models.User{
			Nama:         name,
			Email:        email,
			Password:     "",  // Dikosongkan karena login via Google
			JenisKelamin: "L", // Default
		}
		
		createdUser, createErr := u.repo.Create(newUser)
		if createErr != nil {
			return models.User{}, fmt.Errorf("gagal membuat user baru: %w", createErr)
		}
		return createdUser, nil
	}

	// Jika user sudah ada, kembalikan user tersebut
	return user, nil
}

func (u *userUsecase) GetUserByID(id uint) (models.User, error) {
	if id == 0 {
		return models.User{}, fmt.Errorf("id tidak valid")
	}

	user, err := u.repo.GetByID(id)
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
	return u.repo.GetAll()
}

func (u *userUsecase) UpdateUser(id uint, input models.UpdateUserRequest) (models.User, error) {
	if id == 0 {
		return models.User{}, fmt.Errorf("id tidak valid")
	}

	// Get existing user
	user, err := u.repo.GetByID(id)
	if err != nil || user.IDUser == 0 {
		return models.User{}, fmt.Errorf("user tidak ditemukan")
	}

	// Update only non-empty fields
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

	// Check if user exists
	user, err := u.repo.GetByID(id)
	if err != nil || user.IDUser == 0 {
		return fmt.Errorf("user tidak ditemukan")
	}

	return u.repo.Delete(id)
}