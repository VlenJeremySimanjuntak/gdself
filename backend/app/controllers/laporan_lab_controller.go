package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type LaporanLabController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByUserID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type laporanLabController struct {
	usecase usecases.LaporanLabUsecase
}

func NewLaporanLabController(u usecases.LaporanLabUsecase) LaporanLabController {
	return &laporanLabController{usecase: u}
}

func (ctrl *laporanLabController) Create(c echo.Context) error {
	var input models.CreateLaporanLabRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.IDUser == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_user harus diisi",
		})
	}

	if input.NamaLab == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "nama_lab harus diisi",
		})
	}

	// Mapping ke model LaporanLab
	// Note: IDRiwayat akan di-handle oleh usecase (create or find existing Riwayat)
	laporan := models.LaporanLab{
		IDRiwayat:  input.IDRiwayat,
		TglPeriksa: input.TglPeriksa,
		NamaLab:    input.NamaLab,
	}

	result, err := ctrl.usecase.CreateLaporanLab(laporan)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Laporan lab berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *laporanLabController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	laporan, err := ctrl.usecase.GetLaporanLabByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Laporan lab ditemukan",
		Data:       laporan,
	})
}

func (ctrl *laporanLabController) GetByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "user_id tidak valid",
		})
	}

	// Karena LaporanLabUsecase belum memiliki method GetLaporanLabByUserID,
	// kita gunakan GetAllLaporanLab lalu filter berdasarkan Riwayat.IDUser
	allLaporan, err := ctrl.usecase.GetAllLaporanLab()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Filter laporan yang memiliki Riwayat dengan IDUser yang sesuai
	var filteredLaporan []models.LaporanLab
	for _, laporan := range allLaporan {
		if laporan.Riwayat != nil && laporan.Riwayat.IDUser == uint(userID) {
			filteredLaporan = append(filteredLaporan, laporan)
		}
	}

	// Jika tidak ada laporan, kembalikan array kosong
	if filteredLaporan == nil {
		filteredLaporan = []models.LaporanLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar laporan lab user",
		Data:       filteredLaporan,
	})
}

func (ctrl *laporanLabController) GetAll(c echo.Context) error {
	laporanList, err := ctrl.usecase.GetAllLaporanLab()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada laporan, kembalikan array kosong
	if laporanList == nil {
		laporanList = []models.LaporanLab{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua laporan lab",
		Data:       laporanList,
	})
}

func (ctrl *laporanLabController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.UpdateLaporanLabRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi minimal ada field yang diupdate
	if input.TglPeriksa == nil && input.NamaLab == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Minimal satu field (tgl_periksa atau nama_lab) harus diisi untuk update",
		})
	}

	laporan, err := ctrl.usecase.UpdateLaporanLab(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Laporan lab berhasil diperbarui",
		Data:       laporan,
	})
}

func (ctrl *laporanLabController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteLaporanLab(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Laporan lab berhasil dihapus",
	})
}