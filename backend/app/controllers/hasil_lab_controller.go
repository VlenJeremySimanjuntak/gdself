package controllers

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

// =========================================================================
// INTERFACE: Harus sama persis dengan yang dipanggil di routes.go
// =========================================================================
type HasilLabController interface {
	Create(c echo.Context) error
	GetAll(c echo.Context) error
	GetByLaporanLabID(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetByUserAndDate(c echo.Context) error
	GetByRiwayatAndDate(c echo.Context) error
	GetByID(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type hasilLabController struct {
	usecase usecases.HasilLabUsecase
}

func NewHasilLabController(u usecases.HasilLabUsecase) HasilLabController {
	return &hasilLabController{
		usecase: u,
	}
}

// =========================================================================
// IMPLEMENTASI FUNGSI-FUNGSI CONTROLLER
// =========================================================================

func (ctrl *hasilLabController) Create(c echo.Context) error {
	var input models.CreateHasilLabRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "Format request tidak valid: " + err.Error(),
		})
	}

	// BLOK VALIDASI: Mencegah parameter utama diisi parsial/setengah-setengah
	for _, param := range input.Parameters {
		name := strings.ToUpper(strings.TrimSpace(param.NamaParameter))
		isMainParam := name == "FT3" || name == "FT4" || name == "TSH" || name == "TRAB"

		if isMainParam {
			hasNilai := param.Nilai != nil || param.NilaiHasil != nil
			hasBatasBawah := param.NilaiBatasBawah != nil
			hasBatasAtas := param.NilaiBatasAtas != nil

			if hasNilai || hasBatasBawah || hasBatasAtas {
				if !(hasNilai && hasBatasBawah && hasBatasAtas) {
					return c.JSON(http.StatusBadRequest, map[string]interface{}{
						"status":  "error",
						"message": fmt.Sprintf("Data tidak lengkap! Parameter %s harus diisi beserta Batas Bawah dan Batas Atas, atau dikosongkan semuanya.", param.NamaParameter),
					})
				}
			}
		}
	}

	hasil, err := ctrl.usecase.CreateHasilLab(input)
	if err != nil {
		// ✅ TANGKAP WARNING TREMOR
		if strings.HasPrefix(err.Error(), "TREMOR_WARNING:") {
			return c.JSON(http.StatusUnprocessableEntity, map[string]interface{}{
				"status":            "error",
				"message":           strings.TrimSpace(strings.TrimPrefix(err.Error(), "TREMOR_WARNING:")),
				"need_confirmation": true,
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"status":  "success",
		"message": "Hasil lab berhasil ditambahkan",
		"data":    hasil,
	})
}

func (ctrl *hasilLabController) GetAll(c echo.Context) error {
	hasil, err := ctrl.usecase.GetAllHasilLab()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   hasil,
	})
}

func (ctrl *hasilLabController) GetByLaporanLabID(c echo.Context) error {
	laporanLabID, err := strconv.Atoi(c.Param("laporan_id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "ID Laporan Lab tidak valid",
		})
	}

	hasil, err := ctrl.usecase.GetHasilLabByLaporanLabID(uint(laporanLabID))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   hasil,
	})
}

func (ctrl *hasilLabController) GetByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.Atoi(c.Param("riwayat_id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "ID Riwayat tidak valid",
		})
	}

	hasil, err := ctrl.usecase.GetHasilLabByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   hasil,
	})
}

func (ctrl *hasilLabController) GetByUserAndDate(c echo.Context) error {
	userID, err := strconv.Atoi(c.Param("id_user"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "user_id tidak valid",
		})
	}
	date := c.Param("tanggal")

	laporan, err := ctrl.usecase.GetLaporanByUserAndDate(uint(userID), date)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   laporan,
	})
}

func (ctrl *hasilLabController) GetByRiwayatAndDate(c echo.Context) error {
	riwayatID, err := strconv.Atoi(c.Param("riwayat_id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "riwayat_id tidak valid",
		})
	}
	date := c.Param("date")

	laporan, err := ctrl.usecase.GetHasilLabByRiwayatIDAndDate(uint(riwayatID), date)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   laporan,
	})
}

func (ctrl *hasilLabController) GetByID(c echo.Context) error {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "ID tidak valid",
		})
	}

	hasil, err := ctrl.usecase.GetHasilLabByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status": "success",
		"data":   hasil,
	})
}

func (ctrl *hasilLabController) Update(c echo.Context) error {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "ID tidak valid",
		})
	}

	var input models.UpdateHasilLabRequest
	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	hasil, err := ctrl.usecase.UpdateHasilLab(uint(id), input)
	if err != nil {
		// ✅ TANGKAP WARNING TREMOR
		if strings.HasPrefix(err.Error(), "TREMOR_WARNING:") {
			return c.JSON(http.StatusUnprocessableEntity, map[string]interface{}{
				"status":            "error",
				"message":           strings.TrimSpace(strings.TrimPrefix(err.Error(), "TREMOR_WARNING:")),
				"need_confirmation": true,
			})
		}

		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status":  "success",
		"message": "Data berhasil diupdate",
		"data":    hasil,
	})
}

func (ctrl *hasilLabController) Delete(c echo.Context) error {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"status":  "error",
			"message": "ID tidak valid",
		})
	}

	err = ctrl.usecase.DeleteHasilLab(uint(id))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"status":  "success",
		"message": "Hasil lab berhasil dihapus",
	})
}