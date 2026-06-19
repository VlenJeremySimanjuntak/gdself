package controllers

import (
	"net/http"
	"strconv"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type WearableController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetByUserID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type wearableController struct {
	usecase usecases.WearableUsecase
}

func NewWearableController(u usecases.WearableUsecase) WearableController {
	return &wearableController{usecase: u}
}

func (ctrl *wearableController) Create(c echo.Context) error {
	var input models.CreateWearableRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.IDUser == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "id_user harus diisi"})
	}

	if input.HeartRateHr == 0 && input.SleepDuration == 0 && input.Sistolik == 0 && input.Diastolik == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Minimal satu data metrik harus diisi"})
	}

	// Mapping ke model Wearable
	wearable := models.Wearable{
		IDRiwayat:     input.IDRiwayat,
		TglData:       input.TglData,
		WaktuData:     input.WaktuData,
		HeartRateHr:   input.HeartRateHr,
		SleepDuration: input.SleepDuration,
		Sistolik:      input.Sistolik,  // ✅ Mapping Sistolik
		Diastolik:     input.Diastolik, // ✅ Mapping Diastolik
	}

	result, err := ctrl.usecase.CreateWearable(input.IDUser, wearable)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Data wearable berhasil disimpan",
		Data:       result,
	})
}

func (ctrl *wearableController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	wearable, err := ctrl.usecase.GetWearableByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data wearable ditemukan",
		Data:       wearable,
	})
}

func (ctrl *wearableController) GetByRiwayatID(c echo.Context) error {
	riwayatID, err := strconv.ParseUint(c.Param("riwayat_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "riwayat_id tidak valid"})
	}

	wearables, err := ctrl.usecase.GetWearableByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar data wearable berdasarkan riwayat",
		Data:       wearables,
	})
}

func (ctrl *wearableController) GetByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	wearables, err := ctrl.usecase.GetWearableByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar data wearable berdasarkan user",
		Data:       wearables,
	})
}

func (ctrl *wearableController) GetAll(c echo.Context) error {
	wearables, err := ctrl.usecase.GetAllWearable()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua data wearable",
		Data:       wearables,
	})
}

func (ctrl *wearableController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	var input models.UpdateWearableRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	if input.TglData == nil && input.WaktuData == nil && input.HeartRateHr == 0 && input.SleepDuration == 0 && input.Sistolik == 0 && input.Diastolik == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "Minimal satu field harus diisi untuk update",
		})
	}

	wearable, err := ctrl.usecase.UpdateWearable(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data wearable berhasil diperbarui",
		Data:       wearable,
	})
}

func (ctrl *wearableController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	if err := ctrl.usecase.DeleteWearable(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Data wearable berhasil dihapus",
	})
}