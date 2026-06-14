package controllers

import (
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

func (ctrl *userController) Create(c echo.Context) error {
	var input models.CreateUserRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validation
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
		errorMessage := helpers.ParseDBError(err)
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error":  errorMessage,
			"detail": err.Error(),
		})
	}

	// Generate JWT token untuk user baru
	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 15 * time.Minute
		tokenStr, err := helpers.GenerateToken(result.IDUser, result.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// Prepare response without password
	userData := models.UserLoginData{
		IDUser:          result.IDUser,
		Nama:            result.Nama,
		Email:           result.Email,
		TglLahir:        result.TglLahir,
		JenisKelamin:    result.JenisKelamin,
		TglTerdiagnosis: result.TglTerdiagnosis,
		UpdateAt:        result.UpdateAt,
	}

	registerResponse := models.RegisterResponse{
		Token: token,
		User:  userData,
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "User berhasil dibuat",
		Data:       registerResponse,
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

	user, err := ctrl.usecase.Authenticate(input.Email, input.Password)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": err.Error()})
	}

	// Issue JWT token
	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 15 * time.Minute
		tokenStr, err := helpers.GenerateToken(user.IDUser, user.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// Prepare response without password
	userData := models.UserLoginData{
		IDUser:          user.IDUser,
		Nama:            user.Nama,
		Email:           user.Email,
		TglLahir:        user.TglLahir,
		JenisKelamin:    user.JenisKelamin,
		TglTerdiagnosis: user.TglTerdiagnosis,
		UpdateAt:        user.UpdateAt,
	}

	loginResponse := models.LoginResponse{
		Token: token,
		User:  userData,
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Login berhasil",
		Data:       loginResponse,
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

	user, err := ctrl.usecase.GoogleLogin(input.IDToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": err.Error()})
	}

	// Issue JWT token
	jwtSecret := os.Getenv("JWT_SECRET")
	var token string
	if jwtSecret != "" {
		ttl := 15 * time.Minute
		tokenStr, err := helpers.GenerateToken(user.IDUser, user.Email, ttl)
		if err == nil {
			token = tokenStr
		}
	}

	// Prepare response without password
	userData := models.UserLoginData{
		IDUser:          user.IDUser,
		Nama:            user.Nama,
		Email:           user.Email,
		TglLahir:        user.TglLahir,
		JenisKelamin:    user.JenisKelamin,
		TglTerdiagnosis: user.TglTerdiagnosis,
		UpdateAt:        user.UpdateAt,
	}

	loginResponse := models.LoginResponse{
		Token: token,
		User:  userData,
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Login Google berhasil",
		Data:       loginResponse,
	})
}

func (ctrl *userController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	user, err := ctrl.usecase.GetUserByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "User ditemukan",
		Data:       user,
	})
}

func (ctrl *userController) GetAll(c echo.Context) error {
	users, err := ctrl.usecase.GetAllUsers()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar user",
		Data:       users,
	})
}

func (ctrl *userController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	var input models.UpdateUserRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	user, err := ctrl.usecase.UpdateUser(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "User berhasil diperbarui",
		Data:       user,
	})
}

func (ctrl *userController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	err = ctrl.usecase.DeleteUser(uint(id))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "User berhasil dihapus",
	})
}