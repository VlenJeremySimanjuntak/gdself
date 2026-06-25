package controllers

import (
	"net/http"
	"time"

	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type AuthController interface {
	SendOTP(c echo.Context) error
	VerifyOTP(c echo.Context) error
	GoogleCheck(c echo.Context) error
	GoogleComplete(c echo.Context) error
	ForgotPassword(c echo.Context) error
	ResetPassword(c echo.Context) error
}

type authController struct {
	usecase     usecases.AuthUsecase
	userUsecase usecases.UserUsecase
}

func NewAuthController(auth usecases.AuthUsecase, user usecases.UserUsecase) AuthController {
	return &authController{usecase: auth, userUsecase: user}
}

func generateTokenHelper(userID uint, email string) string {
	token, err := helpers.GenerateToken(userID, email, 24*time.Hour)
	if err != nil {
		return ""
	}
	return token
}

// ── POST /api/auth/send-otp ───────────────────────────────────────────────────
func (ctrl *authController) SendOTP(c echo.Context) error {
	var input models.SendOTPRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	if input.Email == "" || input.Type == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "email dan type harus diisi"})
	}

	if input.Type != "register" && input.Type != "reset_password" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "type tidak valid"})
	}

	if err := ctrl.usecase.SendOTP(input.Email, input.Type); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Kode OTP telah dikirim ke email Anda",
	})
}

// ── POST /api/auth/verify-otp ────────────────────────────────────────────────
func (ctrl *authController) VerifyOTP(c echo.Context) error {
	var input models.VerifyOTPRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	if err := ctrl.usecase.VerifyOTP(input.Email, input.Code, input.Type); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "OTP berhasil diverifikasi",
	})
}

// ── POST /api/auth/google/check ──────────────────────────────────────────────
// Cek apakah user Google sudah ada atau belum
func (ctrl *authController) GoogleCheck(c echo.Context) error {
	var input struct {
		IDToken string `json:"id_token"`
	}
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	// 1. Verifikasi Token Google ke Usecase
	result, err := ctrl.usecase.GoogleCheck(input.IDToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": err.Error()})
	}

	// 2. Cek langsung ke database apakah email ini sudah terdaftar
	existingUser, loginErr := ctrl.userUsecase.GetUserByEmail(result.GoogleEmail)

	// 3. LOGIKA UTAMA: Jika terjadi error (misal: Record Not Found), anggap sebagai USER BARU
	if loginErr != nil {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"status_code": http.StatusOK,
			"message":     "User belum terdaftar, silakan lengkapi data",
			"data": map[string]interface{}{
				"is_new_user":  true, // ✅ Flag dikirim sebagai TRUE
				"google_email": result.GoogleEmail,
				"google_name":  result.GoogleName,
				"google_photo": result.GooglePhoto,
			},
		})
	}

	// 4. JIKA USER DITEMUKAN (Sudah Terdaftar sebelumnya)
	token := generateTokenHelper(existingUser.IDUser, existingUser.Email)
	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Login Google berhasil",
		"data": map[string]interface{}{
			"is_new_user": false, // ✅ Flag dikirim sebagai FALSE
			"token":       token,
			"user":        buildUserResponse(existingUser), // Menggunakan helper yang sudah ada di controller Mas
		},
	})
}

// ── POST /api/auth/google/complete ───────────────────────────────────────────
// Selesaikan registrasi user Google baru
func (ctrl *authController) GoogleComplete(c echo.Context) error {
	var input models.GoogleCompleteRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	if input.IDToken == "" || input.Password == "" || input.JenisKelamin == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_token, password, dan jenis_kelamin harus diisi",
		})
	}

	user, err := ctrl.usecase.GoogleComplete(
		input.IDToken,
		input.Password,
		input.JenisKelamin,
		input.TglLahir,
		input.TglTerdiagnosis,
	)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	token := generateTokenHelper(user.IDUser, user.Email)

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status_code": http.StatusCreated,
		"message":     "Registrasi berhasil",
		"data": map[string]interface{}{
			"token": token,
			"user":  buildUserResponse(user),
		},
	})
}

// ── POST /api/auth/forgot-password ───────────────────────────────────────────
func (ctrl *authController) ForgotPassword(c echo.Context) error {
	var input models.ForgotPasswordRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	if err := ctrl.usecase.ForgotPassword(input.Email); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Kode reset password telah dikirim ke email Anda",
	})
}

// ── POST /api/auth/reset-password ────────────────────────────────────────────
func (ctrl *authController) ResetPassword(c echo.Context) error {
	var input models.ResetPasswordRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	if input.Email == "" || input.Code == "" || input.NewPassword == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "email, code, dan new_password harus diisi",
		})
	}

	if len(input.NewPassword) < 6 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "password minimal 6 karakter",
		})
	}

	if err := ctrl.usecase.ResetPassword(input.Email, input.Code, input.NewPassword); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status_code": http.StatusOK,
		"message":     "Password berhasil diubah",
	})
}