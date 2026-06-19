package controllers

import (
	"io"
	"path/filepath"
	"net/http"
	"os"
	"strconv"
	"time"

	"monitoring-service/app/constants"
	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type UserController interface {
	Create(c echo.Context) error
	Login(c echo.Context) error
	GoogleLogin(c echo.Context) error
	GetByID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
	UploadAvatar(c echo.Context) error
}

type userController struct {
	usecase usecases.UserUsecase
}

func NewUserController(u usecases.UserUsecase) UserController {
	return &userController{usecase: u}
}

type GoogleLoginRequest struct {
	IDToken string `json:"id_token"`
}

// buildUserResponse membuat response user tanpa CustomDate/struct problem
func buildUserResponse(user models.User) map[string]interface{} {
	response := map[string]interface{}{
		"id_user":       user.IDUser,
		"nama":          user.Nama,
		"email":         user.Email,
		"jenis_kelamin": user.JenisKelamin,
		"foto_profil":   user.FotoProfil,
		"update_at":     user.UpdateAt.Format("2006-01-02 15:04:05"),
	}

	// Handle tgl_lahir
	if user.TglLahir != nil {
		t := time.Time(*user.TglLahir)
		if !t.IsZero() {
			response["tgl_lahir"] = t.Format("2006-01-02")
		} else {
			response["tgl_lahir"] = nil
		}
	} else {
		response["tgl_lahir"] = nil
	}

	// Handle tgl_terdiagnosis
	if user.TglTerdiagnosis != nil {
		t := time.Time(*user.TglTerdiagnosis)
		if !t.IsZero() {
			response["tgl_terdiagnosis"] = t.Format("2006-01-02")
		} else {
			response["tgl_terdiagnosis"] = nil
		}
	} else {
		response["tgl_terdiagnosis"] = nil
	}

	return response
}

func (ctrl *userController) Create(c echo.Context) error {
	var input models.CreateUserRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.Nama == "" || input.Email == "" || input.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "nama, email, dan password harus diisi",
		})
	}

	// Mapping ke model User
	user := models.User{
		Nama:            input.Nama,
		Email:           input.Email,
		Password:        input.Password,
		TglLahir:        input.TglLahir,
		JenisKelamin:    input.JenisKelamin,
		TglTerdiagnosis: input.TglTerdiagnosis,
	}

	result, err := ctrl.usecase.CreateUser(user)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error": err.Error(),
		})
	}

	// Generate JWT token
	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 24 * time.Hour
		tokenStr, err := helpers.GenerateToken(result.IDUser, result.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// ✅ Response manual untuk hindari MarshalJSON error
	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status_code": http.StatusCreated,
		"message":     "User berhasil dibuat",
		"data": map[string]interface{}{
			"token": token,
			"user":  buildUserResponse(result),
		},
	})
}

func (ctrl *userController) Login(c echo.Context) error {
	var input models.LoginRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	if input.Email == "" || input.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "email dan password harus diisi",
		})
	}

	user, err := ctrl.usecase.Authenticate(input.Email, input.Password)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": err.Error(),
		})
	}

	if user.Provider == "google" {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": "Akun ini terdaftar menggunakan Google. Silakan masuk dengan tombol 'Masuk dengan Google'.",
		})
	}

	// Generate JWT token
	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 24 * time.Hour
		tokenStr, err := helpers.GenerateToken(user.IDUser, user.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Login berhasil",
		"data": map[string]interface{}{
			"token": token,
			"user":  buildUserResponse(user),
		},
	})
}

func (ctrl *userController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	user, err := ctrl.usecase.GetUserByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "User ditemukan",
		"data":        buildUserResponse(user),
	})
}

func (ctrl *userController) GetAll(c echo.Context) error {
	users, err := ctrl.usecase.GetAllUsers()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Build response untuk setiap user
	var usersData []map[string]interface{}
	for _, user := range users {
		usersData = append(usersData, buildUserResponse(user))
	}

	if usersData == nil {
		usersData = []map[string]interface{}{}
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Daftar user",
		"data":        usersData,
	})
}

func (ctrl *userController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.UpdateUserRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	user, err := ctrl.usecase.UpdateUser(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "User berhasil diperbarui",
		"data":        buildUserResponse(user),
	})
}

func (ctrl *userController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteUser(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "User berhasil dihapus",
	})
}

// GoogleLogin tetap sama seperti sebelumnya
func (ctrl *userController) GoogleLogin(c echo.Context) error {
	var input GoogleLoginRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	if input.IDToken == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_token harus diisi",
		})
	}

	user, err := ctrl.usecase.GoogleLogin(input.IDToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{
			"error": err.Error(),
		})
	}

	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 24 * time.Hour
		tokenStr, err := helpers.GenerateToken(user.IDUser, user.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// ✅ Response manual
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Login Google berhasil",
		"data": map[string]interface{}{
			"token": token,
			"user":  buildUserResponse(user),
		},
	})
}

// ✅ Fungsi baru untuk menerima file dari Flutter
func (ctrl *userController) UploadAvatar(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	// 1. Ambil file dengan key "avatar" (Sesuai dengan FormData di Flutter)
	file, err := c.FormFile("avatar")
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "File avatar tidak ditemukan",
		})
	}

	// 2. Validasi Ekstensi (Hanya gambar)
	ext := filepath.Ext(file.Filename)
	if ext != ".jpg" && ext != ".jpeg" && ext != ".png" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Format file tidak didukung. Gunakan .jpg, .jpeg, atau .png",
		})
	}

	// 3. Buka File
	src, err := file.Open()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal membuka file",
		})
	}
	defer src.Close()

	// 4. Siapkan folder uploads/avatars di server
	uploadDir := "./uploads/avatars"
	os.MkdirAll(uploadDir, os.ModePerm)

	// 5. Buat nama file yang unik (mencegah bentrok)
	newFilename := "user_" + strconv.FormatUint(id, 10) + "_" + strconv.FormatInt(time.Now().Unix(), 10) + ext
	dstPath := filepath.Join(uploadDir, newFilename)

	// 6. Buat dan simpan file di server
	dst, err := os.Create(dstPath)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal menyimpan file di server",
		})
	}
	defer dst.Close()

	if _, err = io.Copy(dst, src); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": "Gagal menyalin isi file",
		})
	}

	// 7. Generate URL Publik (Sesuai dengan domain Railway kamu)
	avatarURL := "https://gdself-production.up.railway.app/uploads/avatars/" + newFilename

	// 8. Simpan URL ke Database melalui Usecase
	user, err := ctrl.usecase.UploadAvatar(uint(id), avatarURL)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// 9. Kembalikan Response Sukses
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Foto profil berhasil diperbarui",
		"data":        buildUserResponse(user), // Langsung pakai buildUserResponse yang sudah ada
	})
}