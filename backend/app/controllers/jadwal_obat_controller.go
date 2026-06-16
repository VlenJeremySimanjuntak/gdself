package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type JadwalObatController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByObatID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type jadwalObatController struct {
	usecase usecases.JadwalObatUsecase
}

func NewJadwalObatController(u usecases.JadwalObatUsecase) JadwalObatController {
	return &jadwalObatController{usecase: u}
}

func (ctrl *jadwalObatController) Create(c echo.Context) error {
	var input models.CreateJadwalObatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.IDObat == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_obat harus diisi",
		})
	}

	if input.Hari == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "hari harus diisi",
		})
	}

	if input.WaktuMinumObat == nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "waktu_minum_obat harus diisi",
		})
	}

	// Mapping ke model JadwalObat sesuai struktur terbaru
	jadwalObat := models.JadwalObat{
		IDObat:         input.IDObat,
		Hari:           input.Hari,
		WaktuMinumObat: input.WaktuMinumObat,
	}

	result, err := ctrl.usecase.CreateJadwalObat(jadwalObat)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Jadwal obat berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *jadwalObatController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	jadwalObat, err := ctrl.usecase.GetJadwalObatByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Jadwal obat ditemukan",
		Data:       jadwalObat,
	})
}

func (ctrl *jadwalObatController) GetByObatID(c echo.Context) error {
	obatID, err := strconv.ParseUint(c.Param("obat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "obat_id tidak valid",
		})
	}

	jadwalList, err := ctrl.usecase.GetJadwalObatByObatID(uint(obatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada jadwal, kembalikan array kosong
	if jadwalList == nil {
		jadwalList = []models.JadwalObat{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar jadwal obat",
		Data:       jadwalList,
	})
}

func (ctrl *jadwalObatController) GetAll(c echo.Context) error {
	jadwalList, err := ctrl.usecase.GetAllJadwalObat()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada jadwal, kembalikan array kosong
	if jadwalList == nil {
		jadwalList = []models.JadwalObat{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua jadwal obat",
		Data:       jadwalList,
	})
}

func (ctrl *jadwalObatController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.UpdateJadwalObatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi minimal ada satu field yang diupdate
	if input.Hari == "" && input.WaktuMinumObat == nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Minimal satu field (hari atau waktu_minum_obat) harus diisi untuk update",
		})
	}

	jadwalObat, err := ctrl.usecase.UpdateJadwalObat(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Jadwal obat berhasil diperbarui",
		Data:       jadwalObat,
	})
}

func (ctrl *jadwalObatController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteJadwalObat(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Jadwal obat berhasil dihapus",
	})
}