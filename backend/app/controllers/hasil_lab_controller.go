package controllers

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type HasilLabController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByLaporanLabID(c echo.Context) error
	GetByRiwayatAndDate(c echo.Context) error
	GetByUserAndDate(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type hasilLabController struct {
	usecase     usecases.HasilLabUsecase
	aiUsecase   usecases.LabUsecase
	laporanRepo repositories.LaporanLabRepository
}

func NewHasilLabController(u usecases.HasilLabUsecase, ai usecases.LabUsecase, laporanRepo repositories.LaporanLabRepository) HasilLabController {
	return &hasilLabController{
		usecase:     u,
		aiUsecase:   ai,
		laporanRepo: laporanRepo,
	}
}

func (ctrl *hasilLabController) Create(c echo.Context) error {
	var input models.CreateHasilLabRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		idLaporan = input.IDReport
	}

	if idLaporan == 0 && (input.IDUser == 0 || strings.TrimSpace(input.NamaLab) == "") {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_laporan_lab atau (id_user + nama_lab) harus diisi",
		})
	}

	if len(input.Parameters) == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "minimal 1 parameter harus diisi",
		})
	}

	for i, p := range input.Parameters {
		if strings.TrimSpace(p.NamaParameter) == "" {
			return c.JSON(http.StatusBadRequest, map[string]string{
				"error": "nama_parameter wajib diisi untuk parameter ke-" + strconv.Itoa(i+1),
			})
		}
	}

	result, err := ctrl.usecase.CreateHasilLab(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Ekstrak ID Laporan
	reportID := idLaporan
	if reportID == 0 {
		resBytes, _ := json.Marshal(result)
		var resMap map[string]interface{}
		if errJSON := json.Unmarshal(resBytes, &resMap); errJSON == nil {
			if val, ok := resMap["id_laporan_lab"].(float64); ok {
				reportID = uint(val)
			}
		} else {
			var resArray []map[string]interface{}
			if errArr := json.Unmarshal(resBytes, &resArray); errArr == nil && len(resArray) > 0 {
				if val, ok := resArray[0]["id_laporan_lab"].(float64); ok {
					reportID = uint(val)
				}
			}
		}
	}

	var aiParams []models.AssessmentParamInput
	for _, p := range input.Parameters {
		aiParams = append(aiParams, models.AssessmentParamInput{
			NamaParameter:   p.NamaParameter,
			NilaiHasil:      p.NilaiHasil,
			NilaiBatasBawah: p.NilaiBatasBawah,
			NilaiBatasAtas:  p.NilaiBatasAtas,
		})
	}

	aiInput := models.AssessmentInput{
		IsLabDay: true,
		Lab: models.AssessmentLabInput{
			IDLaporanLab: reportID,
			Parameters:   aiParams,
		},
	}

	// ✅ Goroutine dengan reassess laporan berikutnya
	go func(data models.AssessmentInput, laporanID uint) {
		_, aiErr := ctrl.aiUsecase.Assess(data)
		if aiErr != nil {
			log.Println("⚠️ [AI FAILED]:", aiErr)
			return
		}
		log.Println("✅ [AI SUCCESS] Laporan ID:", laporanID)

		// 🔄 Reassess laporan berikutnya agar tren diperbarui
		nextLap, err := ctrl.laporanRepo.GetNextLab(laporanID)
		if err == nil && nextLap.IDLaporanLab != 0 {
			var nextParams []models.AssessmentParamInput
			for _, h := range nextLap.HasilLab {
				if h.Parameter != nil {
					nextParams = append(nextParams, models.AssessmentParamInput{
						NamaParameter:   h.Parameter.NamaParameter,
						NilaiHasil:      h.NilaiHasil,
						NilaiBatasBawah: h.NilaiBatasBawah,
						NilaiBatasAtas:  h.NilaiBatasAtas,
					})
				}
			}
			if len(nextParams) > 0 {
				nextInput := models.AssessmentInput{
					IsLabDay: true,
					Lab: models.AssessmentLabInput{
						IDLaporanLab: nextLap.IDLaporanLab,
						Parameters:   nextParams,
					},
				}
				_, reassessErr := ctrl.aiUsecase.Assess(nextInput)
				if reassessErr != nil {
					log.Println("⚠️ [REASSESS FAILED]:", reassessErr)
				} else {
					log.Println("✅ [REASSESS SUCCESS] Next Laporan ID:", nextLap.IDLaporanLab)
				}
			}
		}
	}(aiInput, reportID)

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Hasil lab berhasil dibuat dan AI sedang memproses",
		Data:       result,
	})
}

func (ctrl *hasilLabController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	hasilLab, err := ctrl.usecase.GetHasilLabByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil lab ditemukan",
		Data:       hasilLab,
	})
}

func (ctrl *hasilLabController) GetByLaporanLabID(c echo.Context) error {
	laporanID, err := strconv.ParseUint(c.Param("laporan_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "laporan_id tidak valid",
		})
	}

	hasilLabList, err := ctrl.usecase.GetHasilLabByLaporanLabID(uint(laporanID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if hasilLabList == nil {
		hasilLabList = []models.HasilLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil lab dari laporan",
		Data:       hasilLabList,
	})
}

func (ctrl *hasilLabController) GetByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "riwayat_id tidak valid",
		})
	}

	hasilLabList, err := ctrl.usecase.GetHasilLabByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if hasilLabList == nil {
		hasilLabList = []models.HasilLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil lab dari riwayat",
		Data:       hasilLabList,
	})
}

func (ctrl *hasilLabController) GetByRiwayatAndDate(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "riwayat_id tidak valid",
		})
	}

	date := c.Param("date")
	if strings.TrimSpace(date) == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "tanggal harus diisi (format: YYYY-MM-DD)",
		})
	}

	hasilLabList, err := ctrl.usecase.GetHasilLabByRiwayatIDAndDate(uint(riwayatID), date)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if hasilLabList == nil {
		hasilLabList = []models.HasilLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar hasil lab dari riwayat dan tanggal",
		Data:       hasilLabList,
	})
}

func (ctrl *hasilLabController) GetByUserAndDate(c echo.Context) error {
	userIDParam := c.Param("id_user")
	if userIDParam == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_user tidak boleh kosong",
		})
	}

	userID, err := strconv.ParseUint(userIDParam, 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_user tidak valid",
		})
	}

	tanggal := c.Param("tanggal")
	if strings.TrimSpace(tanggal) == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "tanggal harus diisi (format: YYYY-MM-DD)",
		})
	}

	laporan, err := ctrl.usecase.GetLaporanByUserAndDate(uint(userID), tanggal)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	type paramResp struct {
		IDHasilLab      uint    `json:"id_hasil_lab"`
		NilaiHasil      float64 `json:"nilai_hasil"`
		NilaiBatasBawah float64 `json:"nilai_batas_bawah"`
		NilaiBatasAtas  float64 `json:"nilai_batas_atas"`
		NamaParameter   string  `json:"nama_parameter"`
		Satuan          string  `json:"satuan"`
		Kategori        string  `json:"kategori"`
	}

	var hasilList []paramResp
	for _, h := range laporan.HasilLab {
		pr := paramResp{
			IDHasilLab:      h.IDHasilLab,
			NilaiHasil:      h.NilaiHasil,
			NilaiBatasBawah: h.NilaiBatasBawah,
			NilaiBatasAtas:  h.NilaiBatasAtas,
		}
		if h.Parameter != nil {
			pr.NamaParameter = h.Parameter.NamaParameter
			pr.Satuan = h.Parameter.Satuan
			pr.Kategori = h.Parameter.Kategori
		}
		hasilList = append(hasilList, pr)
	}

	if hasilList == nil {
		hasilList = []paramResp{}
	}

	respData := map[string]interface{}{
		"id_laporan_lab": laporan.IDLaporanLab,
		"tgl_periksa":    laporan.TglPeriksa,
		"nama_lab":       laporan.NamaLab,
		"hasil_lab":      hasilList,
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data hasil lab ditemukan",
		Data:       respData,
	})
}

func (ctrl *hasilLabController) GetAll(c echo.Context) error {
	hasilLabList, err := ctrl.usecase.GetAllHasilLab()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if hasilLabList == nil {
		hasilLabList = []models.HasilLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua hasil lab",
		Data:       hasilLabList,
	})
}

func (ctrl *hasilLabController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.UpdateHasilLabRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// ✅ FIX BUG: Hapus validasi kaku ini agar update nilai menjadi 0.0 tetap diperbolehkan
	// if input.NilaiHasil == 0 && input.NilaiBatasBawah == 0 && input.NilaiBatasAtas == 0 { ... }

	hasilLab, err := ctrl.usecase.UpdateHasilLab(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Hasil lab berhasil diperbarui",
		Data:       hasilLab,
	})
}

func (ctrl *hasilLabController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteHasilLab(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Hasil lab berhasil dihapus",
	})
}
