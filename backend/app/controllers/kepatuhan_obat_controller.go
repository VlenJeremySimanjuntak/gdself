package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type KepatuhanObatController interface {
	GetNotifikasiByObatID(c echo.Context) error
	GetRekapByObatID(c echo.Context) error
	GetNotifikasiByUserID(c echo.Context) error
}

type kepatuhanObatController struct {
	usecase usecases.KepatuhanObatUsecase
}

func NewKepatuhanObatController(u usecases.KepatuhanObatUsecase) KepatuhanObatController {
	return &kepatuhanObatController{usecase: u}
}

func (ctrl *kepatuhanObatController) GetNotifikasiByObatID(c echo.Context) error {
	obatID, err := strconv.ParseUint(c.Param("obat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "obat_id tidak valid"})
	}

	result, err := ctrl.usecase.GetNotifikasiObat(uint(obatID))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data notifikasi kepatuhan obat ditemukan",
		Data:       result,
	})
}

func (ctrl *kepatuhanObatController) GetRekapByObatID(c echo.Context) error {
	obatID, err := strconv.ParseUint(c.Param("obat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "obat_id tidak valid"})
	}

	result, err := ctrl.usecase.GetRekapObat(uint(obatID))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data rekap obat ditemukan",
		Data:       result,
	})
}

// Response JSON Diperbaiki agar sesuai dgn Flutter (membentuk Map)
func (ctrl *kepatuhanObatController) GetNotifikasiByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	resultArray, err := ctrl.usecase.GetNotifikasiObatUser(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// Membungkus ke format yg siap dibaca HomeScreen Flutter (Map/Dictionary)
	perluPerhatian := len(resultArray) > 0
	responseData := map[string]interface{}{
		"perlu_perhatian": perluPerhatian,
		"total_obat":      len(resultArray),
		"obat":            resultArray,
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data notifikasi kepatuhan user berhasil diambil",
		Data:       responseData,
	})
}