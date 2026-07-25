package controllers

import (
	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"
	"net/http"
	"strconv"

	"github.com/labstack/echo/v4"
)

type LabController interface {
	Create(c echo.Context) error
	GetAll(c echo.Context) error
	GetByUserID(c echo.Context) error
	Assess(c echo.Context) error
}

type labController struct {
	usecase usecases.LabUsecase
}

func NewLabController(u usecases.LabUsecase) LabController {
	return &labController{usecase: u}
}

func (ctrl *labController) Create(c echo.Context) error {
	var input models.CreateHasilLabRequest

	// 1. Tangkap data JSON dari Flutter
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		idLaporan = input.IDReport
	}

	if idLaporan == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID Laporan Lab is required"})
	}

	if input.IDRiwayat == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID Riwayat is required"})
	}

	if len(input.Parameters) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Minimal 1 parameter harus ada"})
	}

	// =========================================================================
	// PERBAIKAN: Cek apakah pointer tidak nil, lalu lakukan dereference (*)
	// =========================================================================
	if input.NilaiHasil != nil && *input.NilaiHasil < 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.ERR_NEGATIVE_VALUE})
	}
	// =========================================================================

	// 2. Oper ke Usecase (Otak) untuk simpan ke DB
	result, err := ctrl.usecase.SaveLabResult(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// 3. Kirim balik hasil analisisnya ke Flutter
	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": constants.MSG_ANALISIS_BERHASIL,
		"data":    result,
	})
}

func (ctrl *labController) GetAll(c echo.Context) error {
	results, err := ctrl.usecase.GetAllLabResults()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": constants.MSG_FETCH_BERHASIL,
		"data":    results,
	})
}

func (ctrl *labController) GetByUserID(c echo.Context) error {
	userIDParam := c.Param("user_id")
	if userIDParam == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.ERR_USER_ID_REQUIRED})
	}

	parsed, err := strconv.ParseUint(userIDParam, 10, 64)
	if err != nil || parsed == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.ERR_INVALID_USER_ID})
	}

	results, err := ctrl.usecase.GetLabResultsByUserID(uint(parsed))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": constants.MSG_FETCH_BERHASIL,
		"data":    results,
	})
}

func (ctrl *labController) Assess(c echo.Context) error {
	var input models.AssessmentInput

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": constants.MSG_INVALID_PAYLOAD})
	}

	result, err := ctrl.usecase.Assess(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": constants.MSG_ANALISIS_BERHASIL,
		"data":    result,
	})
}
