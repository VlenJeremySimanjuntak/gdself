package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type USGTiroidController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetByUserID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type usgTiroidController struct {
	usecase usecases.UsgTiroidUsecase
}

func NewUSGTiroidController(u usecases.UsgTiroidUsecase) USGTiroidController {
	return &usgTiroidController{usecase: u}
}

func (ctrl *usgTiroidController) Create(c echo.Context) error {
	var input models.USGTiroid

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.IDRiwayat == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_riwayat harus diisi",
		})
	}

	if input.NamaRs == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "nama_rs harus diisi",
		})
	}

	result, err := ctrl.usecase.CreateUsgTiroid(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Data USG Tiroid berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *usgTiroidController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	usg, err := ctrl.usecase.GetUsgTiroidByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data USG Tiroid ditemukan",
		Data:       usg,
	})
}

func (ctrl *usgTiroidController) GetByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "riwayat_id tidak valid",
		})
	}

	usgList, err := ctrl.usecase.GetUsgTiroidByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada data, kembalikan array kosong
	if usgList == nil {
		usgList = []models.USGTiroid{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar USG Tiroid dari riwayat",
		Data:       usgList,
	})
}

func (ctrl *usgTiroidController) GetByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "user_id tidak valid",
		})
	}

	usgList, err := ctrl.usecase.GetUsgTiroidByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada data, kembalikan array kosong
	if usgList == nil {
		usgList = []models.USGTiroid{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar USG Tiroid dari user",
		Data:       usgList,
	})
}

func (ctrl *usgTiroidController) GetAll(c echo.Context) error {
	usgList, err := ctrl.usecase.GetAllUsgTiroid()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada data, kembalikan array kosong
	if usgList == nil {
		usgList = []models.USGTiroid{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua USG Tiroid",
		Data:       usgList,
	})
}

func (ctrl *usgTiroidController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.USGTiroid

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi minimal ada field yang diupdate
	if input.NamaRs == "" && input.TglPemeriksaan == nil && 
	   input.FotoPath == "" && input.CatatanDokter == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Minimal satu field harus diisi untuk update",
		})
	}

	usg, err := ctrl.usecase.UpdateUsgTiroid(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data USG Tiroid berhasil diperbarui",
		Data:       usg,
	})
}

func (ctrl *usgTiroidController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteUsgTiroid(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Data USG Tiroid berhasil dihapus",
	})
}