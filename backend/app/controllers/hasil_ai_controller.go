package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type HasilAIController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetByWearableID(c echo.Context) error
	GetByHasilLabID(c echo.Context) error
	GetAll(c echo.Context) error
	UpdateIsRead(c echo.Context) error
}

type hasilAIController struct {
	usecase usecases.HasilAIUsecase
}

func NewHasilAIController(u usecases.HasilAIUsecase) HasilAIController {
	return &hasilAIController{usecase: u}
}

type processAIRequest struct {
	IDUser     uint                   `json:"id_user"`
	IDWearable *uint                  `json:"id_wearable,omitempty"`
	Input      models.AssessmentInput `json:"input"`
}

func (ctrl *hasilAIController) Create(c echo.Context) error {
	var req processAIRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "payload tidak valid"})
	}

	// Validate: if not a lab day, wearable data must be present
	w := req.Input.Wearable
	hasWearable := !(w.HR == 0 && w.Stress == 0 && w.SleepMinutes == 0)
	// If caller provided only an id_wearable, try to load metrics from DB
	if !hasWearable && req.IDWearable != nil {
		// attempt to fetch wearable record
		wrRepo := repositories.NewWearableRepository(repositories.DB)
		if wearableRec, err := wrRepo.GetByID(*req.IDWearable); err == nil && wearableRec.IDWearable != 0 {
			// map wearable record fields into AssessmentInput.Wearable
			req.Input.Wearable.HR = float64(wearableRec.HeartRateRHR)
			req.Input.Wearable.Stress = float64(wearableRec.StressScore)
			req.Input.Wearable.SleepMinutes = float64(wearableRec.SleepDuration)
			hasWearable = true
		}
	}

	if !req.Input.IsLabDay && !hasWearable {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "data wearable diperlukan untuk analisis harian"})
	}

	// Build usecase request
	ur := usecases.AssessRequest{
		Input:      req.Input,
		IDUser:     req.IDUser,
		IDWearable: req.IDWearable,
	}

	hasil, err := ctrl.usecase.ProcessAIAssessment(ur)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI dibuat",
		Data:       hasil,
	})
}

func (ctrl *hasilAIController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	hasilAI, err := ctrl.usecase.GetHasilAIByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI ditemukan",
		Data:       hasilAI,
	})
}

func (ctrl *hasilAIController) GetByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "riwayat_id tidak valid"})
	}

	hasilAI, err := ctrl.usecase.GetHasilAIByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil AI dari riwayat",
		Data:       hasilAI,
	})
}

func (ctrl *hasilAIController) GetByWearableID(c echo.Context) error {
	wearableID, err := strconv.ParseUint(c.Param("wearable_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "wearable_id tidak valid"})
	}

	hasilAI, err := ctrl.usecase.GetHasilAIByWearableID(uint(wearableID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil AI dari wearable",
		Data:       hasilAI,
	})
}

func (ctrl *hasilAIController) GetByHasilLabID(c echo.Context) error {
	hasilLabID, err := strconv.ParseUint(c.Param("hasil_lab_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "hasil_lab_id tidak valid"})
	}

	hasilAI, err := ctrl.usecase.GetHasilAIByHasilLabID(uint(hasilLabID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil AI dari hasil lab",
		Data:       hasilAI,
	})
}

func (ctrl *hasilAIController) GetAll(c echo.Context) error {
	hasilAI, err := ctrl.usecase.GetAllHasilAI()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua hasil AI",
		Data:       hasilAI,
	})
}

func (ctrl *hasilAIController) UpdateIsRead(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	hasilAI, err := ctrl.usecase.UpdateIsRead(uint(id))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Status is_read berhasil diperbarui",
		Data:       hasilAI,
	})
}
