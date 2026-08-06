package controllers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
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
	ServeAvatar(c echo.Context) error
	GetByID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
	UploadAvatar(c echo.Context) error

	// ✅ BARU: Hapus Akun
	RequestDeleteAccountOTP(c echo.Context) error
	DeleteAccount(c echo.Context) error
	WebDeleteForm(c echo.Context) error   // PUBLIC (jalur web)
	WebDeleteSubmit(c echo.Context) error // PUBLIC (jalur web)
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

// Delete = endpoint lama DELETE /users/:id (kini sudah cascade + hapus file lewat usecase).
// Direkomendasikan aplikasi memakai DELETE /users/:id/account yang ber-OTP.
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

// =============================================================================
// ✅ BARU: HAPUS AKUN (mobile, ber-OTP)
// =============================================================================

type deleteAccountRequest struct {
	Code         string `json:"code"`
	Confirmation string `json:"confirmation"`
}

// RequestDeleteAccountOTP: kirim OTP delete_account ke email pemilik akun.
// POST /api/users/:id/account/request-otp  (protected)
func (ctrl *userController) RequestDeleteAccountOTP(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda hanya boleh menghapus akun milik sendiri",
		})
	}

	if err := ctrl.usecase.RequestDeleteAccountOTP(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Kode OTP penghapusan akun telah dikirim ke email Anda",
	})
}

// DeleteAccount: hapus akun sendiri (cascade + file). Wajib OTP + konfirmasi "HAPUS".
// DELETE /api/users/:id/account  (protected)  body: {code, confirmation}
func (ctrl *userController) DeleteAccount(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	tokenUserID := c.Get("user_id").(uint)
	if tokenUserID != uint(id) {
		return c.JSON(http.StatusForbidden, map[string]string{
			"error": "Akses ditolak: Anda hanya boleh menghapus akun milik sendiri",
		})
	}

	var body deleteAccountRequest
	if err := c.Bind(&body); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	if err := ctrl.usecase.DeleteAccount(uint(id), body.Code, body.Confirmation); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Akun dan seluruh data medis Anda telah dihapus permanen",
	})
}

// =============================================================================
// ✅ BARU: HAPUS AKUN via WEB (PUBLIC) — untuk user yang sudah uninstall aplikasi
// =============================================================================

// GET /hapus-akun
func (ctrl *userController) WebDeleteForm(c echo.Context) error {
	return c.HTML(http.StatusOK, webDeletePageHTML("", ""))
}

// POST /hapus-akun  (form-urlencoded: email, password, confirmation)
func (ctrl *userController) WebDeleteSubmit(c echo.Context) error {
	email := c.FormValue("email")
	password := c.FormValue("password")
	confirmation := c.FormValue("confirmation")

	if confirmation != "HAPUS" {
		return c.HTML(http.StatusBadRequest, webDeletePageHTML(
			"Konfirmasi gagal: ketik HAPUS (huruf kapital) pada kolom konfirmasi.", ""))
	}

	if err := ctrl.usecase.WebDeleteAccount(email, password); err != nil {
		return c.HTML(http.StatusBadRequest, webDeletePageHTML(err.Error(), ""))
	}

	return c.HTML(http.StatusOK, webDeletePageHTML("",
		"Akun dan seluruh data medis Anda telah dihapus permanen dari server GdSelf."))
}

// webDeletePageHTML membangun halaman form/hasil sederhana untuk jalur web.
func webDeletePageHTML(errMsg, successMsg string) string {
	banner := ""
	if errMsg != "" {
		banner = fmt.Sprintf(`<div style="background:#FFEBEE;color:#C62828;padding:12px;border-radius:8px;margin-bottom:16px;">%s</div>`, errMsg)
	}
	if successMsg != "" {
		return fmt.Sprintf(`<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Hapus Akun GdSelf</title></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:24px;">
<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;">
<h2 style="color:#005F82;">GdSelf</h2>
<div style="background:#E8F5E9;color:#00695C;padding:16px;border-radius:8px;">%s</div>
</div></body></html>`, successMsg)
	}

	return fmt.Sprintf(`<!DOCTYPE html><html lang="id"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Hapus Akun GdSelf</title></head>
<body style="font-family:Arial,sans-serif;background:#f5f5f5;padding:24px;">
<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;padding:32px;box-shadow:0 4px 12px rgba(0,0,0,0.08);">
<h2 style="color:#005F82;margin-top:0;">Hapus Akun GdSelf</h2>
<p style="color:#555;line-height:1.6;">Halaman ini untuk menghapus akun GdSelf beserta <b>seluruh data medis Anda secara permanen</b>
(riwayat pemeriksaan, hasil lab, analisis AI, foto USG, data obat, data wearable, serta foto profil).
Tindakan ini <b>tidak bisa dibatalkan</b>.</p>
%s
<form method="POST" action="/hapus-akun">
<label style="font-size:13px;color:#555;">Email</label><br>
<input name="email" type="email" required style="width:100%%;padding:10px;margin:6px 0 14px;border:1px solid #ccc;border-radius:8px;"><br>
<label style="font-size:13px;color:#555;">Password</label><br>
<input name="password" type="password" required style="width:100%%;padding:10px;margin:6px 0 14px;border:1px solid #ccc;border-radius:8px;"><br>
<label style="font-size:13px;color:#555;">Ketik <b>HAPUS</b> untuk konfirmasi</label><br>
<input name="confirmation" type="text" required style="width:100%%;padding:10px;margin:6px 0 20px;border:1px solid #ccc;border-radius:8px;"><br>
<button type="submit" style="width:100%%;padding:14px;background:#C62828;color:#fff;border:none;border-radius:25px;font-weight:bold;font-size:15px;">Hapus Akun Saya Permanen</button>
</form>
<p style="color:#888;font-size:12px;margin-top:16px;">Butuh bantuan? Email: support@gdself.app</p>
</div></body></html>`, banner)
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

	head := make([]byte, 512)
	n, _ := src.Read(head)
	if !helpers.IsAllowedImageContent(head[:n]) {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "isi file bukan gambar yang valid"})
	}
	if _, err := src.Seek(0, io.SeekStart); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "gagal memproses file"})
	}

	uploadDir := filepath.Join("uploads", "avatars")
	if err := os.MkdirAll(uploadDir, 0o750); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "gagal menyiapkan folder"})
	}
	newFilename, err := helpers.RandomFileName(file.Filename)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	dst, err := os.Create(filepath.Join(uploadDir, newFilename))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Gagal menyimpan file"})
	}
	defer dst.Close()
	if _, err = io.Copy(dst, src); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Gagal menyalin isi file"})
	}

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
	c.Response().Header().Set("Cache-Control", "private, no-store")
	return c.File(absPath)
}