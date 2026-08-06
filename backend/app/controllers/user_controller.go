package controllers

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"monitoring-service/app/constants"
	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/disintegration/imaging"
	"github.com/labstack/echo/v4"
)

type UserController interface {
	Create(c echo.Context) error
	Login(c echo.Context) error
	GoogleLogin(c echo.Context) error
	ServeAvatar(c echo.Context) error
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

func buildUserResponse(user models.User) map[string]interface{} {
	response := map[string]interface{}{
		"id_user":       user.IDUser,
		"nama":          user.Nama,
		"email":         user.Email,
		"jenis_kelamin": user.JenisKelamin,
		"foto_profil":   user.FotoProfil,
		"update_at":     user.UpdateAt.Format("2006-01-02 15:04:05"),
	}

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

	if input.Nama == "" || input.Email == "" || input.Password == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "nama, email, dan password harus diisi",
		})
	}

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

	token, _ := helpers.GenerateToken(result.IDUser, result.Email, 24*time.Hour)

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

	token, _ := helpers.GenerateToken(user.IDUser, user.Email, 24*time.Hour)

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

	// IDOR Check
	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda tidak memiliki izin untuk mengakses data pengguna lain",
		})
	}

	user, err := ctrl.usecase.GetUserByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "User ditemukan",
		"data":        buildUserResponse(user),
	})
}

func (ctrl *userController) GetAll(c echo.Context) error {
	// Proteksi data pasien: user biasa hanya boleh melihat datanya sendiri,
	// bukan daftar seluruh pengguna. Cegah kebocoran email/tgl lahir pasien lain.
	tokenUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}

	user, err := ctrl.usecase.GetUserByID(tokenUserID)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Data user",
		"data":        []map[string]interface{}{buildUserResponse(user)},
	})
}

func (ctrl *userController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	// IDOR Check
	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda tidak memiliki izin untuk mengubah data pengguna lain",
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

	// IDOR Check
	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda tidak memiliki izin untuk menghapus data pengguna lain",
		})
	}

	if err := ctrl.usecase.DeleteUser(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "User berhasil dihapus",
	})
}

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

	token, _ := helpers.GenerateToken(user.IDUser, user.Email, 24*time.Hour)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Login Google berhasil",
		"data": map[string]interface{}{
			"token": token,
			"user":  buildUserResponse(user),
		},
	})
}

func (ctrl *userController) UploadAvatar(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	// IDOR Check
	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda tidak memiliki izin untuk mengubah avatar pengguna lain",
		})
	}

	file, err := c.FormFile("avatar")
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "File avatar tidak ditemukan",
		})
	}

	if verr := helpers.ValidateImageUpload(file); verr != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": verr.Error()})
	}

	src, err := file.Open()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Gagal membuka file"})
	}
	defer src.Close()

	// Sniff MIME dari isi file (magic bytes)
	head := make([]byte, 512)
	n, _ := src.Read(head)
	if !helpers.IsAllowedImageContent(head[:n]) {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "isi file bukan gambar yang valid"})
	}
	if _, err := src.Seek(0, io.SeekStart); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "gagal memproses file"})
	}

	// ✅ FIX 2 (performa): decode → resize maks 512px (jaga rasio) → re-encode JPEG q82.
	// Memangkas ukuran file avatar dari MB jadi puluhan KB → first-load jauh lebih cepat.
	img, err := imaging.Decode(src, imaging.AutoOrientation(true))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "gagal membaca gambar"})
	}
	img = imaging.Fit(img, 512, 512, imaging.Lanczos)

	uploadDir := filepath.Join("uploads", "avatars")
	if err := os.MkdirAll(uploadDir, 0o750); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "gagal menyiapkan folder"})
	}

	newFilename, err := helpers.RandomFileName(file.Filename)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	// Paksa ekstensi .jpg karena hasil selalu di-encode ke JPEG.
	newFilename = strings.TrimSuffix(newFilename, filepath.Ext(newFilename)) + ".jpg"

	dstPath := filepath.Join(uploadDir, newFilename)
	if err := imaging.Save(img, dstPath, imaging.JPEGQuality(82)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Gagal menyimpan file"})
	}

	// Simpan path RELATIF, dilayani lewat GET /api/users/:id/avatar (ber-JWT)
	user, err := ctrl.usecase.UploadAvatar(uint(id), "avatars/"+newFilename)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Foto profil berhasil diperbarui",
		"data":        buildUserResponse(user),
	})
}

// ServeAvatar melayani file avatar hanya ke pemilik akun (ber-JWT).
func (ctrl *userController) ServeAvatar(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	tokenUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak"})
	}

	user, err := ctrl.usecase.GetUserByID(uint(id))
	if err != nil || user.FotoProfil == "" {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "Avatar tidak ditemukan"})
	}

	absPath, err := helpers.SafeUploadPath(filepath.Join("uploads", "avatars"), user.FotoProfil)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "path file tidak valid"})
	}

	c.Response().Header().Set("Cache-Control", "private, max-age=86400")
	return c.File(absPath)
}