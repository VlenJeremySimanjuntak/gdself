package controllers

import (
	"net/http"
	"strconv"
	"strings"

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type HasilAIController interface {
	CreateHarian(c echo.Context) error
	GetHarianByID(c echo.Context) error
	GetHarianByWearableID(c echo.Context) error
	GetHarianByRiwayatID(c echo.Context) error

	GetLabByID(c echo.Context) error
	GetLabByLaporanLabID(c echo.Context) error

	GetTrenByID(c echo.Context) error
	GetTrenByLaporanLabID(c echo.Context) error

	GetLatestValidByUserAndParam(c echo.Context) error
	ProcessAssessment(c echo.Context) error
}

type hasilAIController struct {
	harianUsecase usecases.HasilAIHarianUsecase
	labUsecase    usecases.HasilAILabUsecase
	trenUsecase   usecases.HasilAITrenUsecase
	labUsecase2   usecases.LabUsecase 
}

func NewHasilAIController(
	harian usecases.HasilAIHarianUsecase,
	lab usecases.HasilAILabUsecase,
	tren usecases.HasilAITrenUsecase,
	lab2 usecases.LabUsecase,
) HasilAIController {
	return &hasilAIController{
		harianUsecase: harian,
		labUsecase:    lab,
		trenUsecase:   tren,
		labUsecase2:   lab2,
	}
}

func (ctrl *hasilAIController) CreateHarian(c echo.Context) error {
	var input models.HasilAIHarian

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  "payload tidak valid",
			"detail": err.Error(),
		})
	}

	if input.IDWearable == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_wearable harus diisi",
		})
	}

	result, err := ctrl.harianUsecase.CreateHasilAIHarian(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Hasil AI Harian berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *hasilAIController) GetHarianByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	hasil, err := ctrl.harianUsecase.GetHasilAIHarianByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI Harian ditemukan",
		Data:       hasil,
	})
}

func (ctrl *hasilAIController) GetHarianByWearableID(c echo.Context) error {
	wearableID, err := strconv.ParseUint(c.Param("wearable_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "wearable_id tidak valid",
		})
	}

	hasil, err := ctrl.harianUsecase.GetHasilAIHarianByWearableID(uint(wearableID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI Harian dari wearable ditemukan",
		Data:       hasil,
	})
}

func (ctrl *hasilAIController) GetHarianByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "riwayat_id tidak valid",
		})
	}

	hasilList, err := ctrl.harianUsecase.GetHasilAIHarianByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if hasilList == nil {
		hasilList = []models.HasilAIHarian{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil AI Harian dari riwayat",
		Data:       hasilList,
	})
}

func (ctrl *hasilAIController) GetLabByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	hasil, err := ctrl.labUsecase.GetHasilAILabByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI Lab ditemukan",
		Data:       hasil,
	})
}

func (ctrl *hasilAIController) GetLabByLaporanLabID(c echo.Context) error {
	laporanLabID, err := strconv.ParseUint(c.Param("laporan_lab_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "laporan_lab_id tidak valid"})
	}

	hasil, err := ctrl.labUsecase.GetHasilAILabByLaporanLabID(uint(laporanLabID))
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "not found") {
			return c.JSON(http.StatusOK, models.Response{
				StatusCode: http.StatusOK,
				Message:    "Data Hasil AI Lab belum tersedia untuk laporan ini",
				Data:       nil,
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{StatusCode: http.StatusOK, Message: "Hasil AI Lab ditemukan", Data: hasil})
}

func (ctrl *hasilAIController) GetTrenByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	hasil, err := ctrl.trenUsecase.GetHasilAITrenByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil AI Tren ditemukan",
		Data:       hasil,
	})
}

func (ctrl *hasilAIController) GetTrenByLaporanLabID(c echo.Context) error {
	laporanLabID, err := strconv.ParseUint(c.Param("laporan_lab_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "laporan_lab_id tidak valid"})
	}

	hasil, err := ctrl.trenUsecase.GetHasilAITrenByLaporanLabID(uint(laporanLabID))
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "not found") {
			return c.JSON(http.StatusOK, models.Response{
				StatusCode: http.StatusOK,
				Message:    "Data tren belum tersedia untuk laporan ini",
				Data:       nil,
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{StatusCode: http.StatusOK, Message: "Hasil AI Tren ditemukan", Data: hasil})
}

func (ctrl *hasilAIController) ProcessAssessment(c echo.Context) error {
	var input models.AssessmentInput

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  "payload tidak valid",
			"detail": err.Error(),
		})
	}

	if input.IsLabDay {
		if input.Lab.IDLaporanLab == 0 && len(input.Lab.Parameters) == 0 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "data lab diperlukan untuk assessment lab day",
			})
		}
	} else {
		// Validasi aman jika wearable dikirim atau tidak dikirim
		if input.Wearable != nil && input.Wearable.SleepMinutes == 0 && input.Wearable.Sys == 0 && input.Wearable.Dia == 0 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "data wearable diperlukan untuk assessment harian",
			})
		}
	}

	result, err := ctrl.labUsecase2.Assess(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Assessment berhasil diproses",
		Data:       result,
	})
}

func (ctrl *hasilAIController) GetLatestValidByUserAndParam(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	paramKey := strings.ToUpper(c.Param("param")) // TSH | FT3 | FT4 | TRAB

	result, err := ctrl.labUsecase.GetLatestValidByUserAndParam(uint(userID), paramKey)
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "not found") {
			return c.JSON(http.StatusOK, models.Response{
				StatusCode: http.StatusOK,
				Message:    "Belum ada data valid untuk parameter ini",
				Data:       nil,
			})
		}
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// ✅ Ambil hanya status & reminder untuk parameter yang diminta,
	// bukan seluruh baris hasil_ai_lab (yang berisi semua parameter sekaligus).
	var status, reminder string
	switch paramKey {
	case "TSH", "TSHS":
		status, reminder = result.StatusTsh, result.ReminderTsh
	case "FT3":
		status, reminder = result.StatusFt3, result.ReminderFt3
	case "FT4":
		status, reminder = result.StatusFt4, result.ReminderFt4
	case "TRAB":
		status, reminder = result.StatusTrab, result.ReminderTrab
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data ditemukan",
		Data: map[string]interface{}{
			"id_hasil_ai_lab": result.IDHasilAILab,
			"id_laporan_lab":  result.IDLaporanLab,
			"parameter":       paramKey,
			"status":          status,
			"reminder":        reminder,
			"interpretasi":    result.Interpretasi,
			"tgl_hasil_ai":    result.TglHasilAi,
			"created_at":      result.CreatedAt,
		},
	})
}