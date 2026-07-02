package controllers

import (
	"net/http"
	"strconv"
	"strings" // ✅ WAJIB DITAMBAHKAN

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type HasilAIController interface {
	// Endpoints untuk HasilAIHarian (dari Wearable)
	CreateHarian(c echo.Context) error
	GetHarianByID(c echo.Context) error
	GetHarianByWearableID(c echo.Context) error
	GetHarianByRiwayatID(c echo.Context) error

	// Endpoints untuk HasilAILab (dari Laporan Lab)
	GetLabByID(c echo.Context) error
	GetLabByLaporanLabID(c echo.Context) error

	// Endpoints untuk HasilAITren (dari Laporan Lab)
	GetTrenByID(c echo.Context) error
	GetTrenByLaporanLabID(c echo.Context) error

	GetLatestValidByUserAndParam(c echo.Context) error


	// Endpoint untuk memproses assessment (menggantikan Create yang lama)
	ProcessAssessment(c echo.Context) error
}

type hasilAIController struct {
	harianUsecase usecases.HasilAIHarianUsecase
	labUsecase    usecases.HasilAILabUsecase
	trenUsecase   usecases.HasilAITrenUsecase
	labUsecase2   usecases.LabUsecase // Untuk memanggil Assess
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

// ==========================================
// HASIL AI HARIAN (DARI WEARABLE)
// ==========================================

func (ctrl *hasilAIController) CreateHarian(c echo.Context) error {
	var input models.HasilAIHarian

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  "payload tidak valid",
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
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

	// Jika tidak ada data, kembalikan array kosong
	if hasilList == nil {
		hasilList = []models.HasilAIHarian{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil AI Harian dari riwayat",
		Data:       hasilList,
	})
}

// ==========================================
// HASIL AI LAB (DARI LAPORAN LAB)
// ==========================================

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
		// ✅ PERBAIKAN: Gunakan strings.Contains agar lebih fleksibel menangkap error GORM
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

// ==========================================
// HASIL AI TREN (DARI LAPORAN LAB)
// ==========================================

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
		// ✅ PERBAIKAN: Sama seperti di atas
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

// ==========================================
// PROCESS ASSESSMENT (MENGGANTIKAN CREATE LAMA)
// ==========================================

func (ctrl *hasilAIController) ProcessAssessment(c echo.Context) error {
	var input models.AssessmentInput

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  "payload tidak valid",
			"detail": err.Error(),
		})
	}

	// Validasi: jika lab day, lab data harus ada
	if input.IsLabDay {
		if input.Lab.IDLaporanLab == 0 && len(input.Lab.Parameters) == 0 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "data lab diperlukan untuk assessment lab day",
			})
		}
	} else {
		// ✅ PERBAIKAN: Tambahkan Sys dan Dia agar Tekanan Darah juga lolos validasi
		if input.Wearable.HR == 0 && input.Wearable.SleepMinutes == 0 && input.Wearable.Sys == 0 && input.Wearable.Dia == 0 {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "data wearable (hr, sleep_minutes, sys, atau dia) diperlukan untuk assessment harian",
			})
		}
	}

	// Panggil LabUsecase.Assess untuk memproses assessment
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

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data ditemukan",
		Data:       result,
	})
}