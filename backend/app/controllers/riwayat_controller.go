package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type RiwayatController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByUserID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type riwayatController struct {
	usecase usecases.RiwayatUsecase
}

func NewRiwayatController(u usecases.RiwayatUsecase) RiwayatController {
	return &riwayatController{usecase: u}
}

func (ctrl *riwayatController) Create(c echo.Context) error {
	var input models.CreateRiwayatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	if input.IDUser == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "id_user harus diisi"})
	}

	riwayat := models.Riwayat{
		IDUser:  input.IDUser,
		Tanggal: input.Tanggal,
	}

	result, err := ctrl.usecase.CreateRiwayat(riwayat)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Riwayat berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *riwayatController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	riwayat, err := ctrl.usecase.GetRiwayatByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Riwayat ditemukan",
		Data:       riwayat,
	})
}

func (ctrl *riwayatController) GetByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	riwayat, err := ctrl.usecase.GetRiwayatByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar riwayat user",
		Data:       riwayat,
	})
}

func (ctrl *riwayatController) GetAll(c echo.Context) error {
	riwayat, err := ctrl.usecase.GetAllRiwayat()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua riwayat",
		Data:       riwayat,
	})
}

func (ctrl *riwayatController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	var input models.UpdateRiwayatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	riwayat, err := ctrl.usecase.UpdateRiwayat(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Riwayat berhasil diperbarui",
		Data:       riwayat,
	})
}

func (ctrl *riwayatController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	err = ctrl.usecase.DeleteRiwayat(uint(id))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Riwayat berhasil dihapus",
	})
}
