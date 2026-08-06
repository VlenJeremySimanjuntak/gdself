package controllers

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/labstack/echo/v4"
)

type ObatController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetKepatuhan(c echo.Context) error
	GetRekapan(c echo.Context) error
	GetByUserID(c echo.Context) error
	GetAll(c echo.Context) error
	Update(c echo.Context) error
	Delete(c echo.Context) error
}

type obatController struct {
	usecase usecases.ObatUsecase
}

func NewObatController(u usecases.ObatUsecase) ObatController {
	return &obatController{usecase: u}
}

func (ctrl *obatController) Create(c echo.Context) error {
	var input models.CreateObatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}

	// Validasi field wajib
	if input.IDUser == 0 || input.NamaObat == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "id_user dan nama_obat harus diisi",
		})
	}
	if input.TglMulai == nil || input.TglSelesai == nil || strings.TrimSpace(*input.TglSelesai) == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "tgl_mulai dan tgl_selesai harus diisi",
		})
	}

	// Mapping ke model Obat sesuai struktur terbaru
	tglSelesai, err := time.Parse("2006-01-02", strings.TrimSpace(*input.TglSelesai))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "tgl_selesai harus berformat YYYY-MM-DD"})
	}

	obat := models.Obat{
		IDUser:     input.IDUser,
		NamaObat:   input.NamaObat,
		TglMulai:   input.TglMulai,
		TglSelesai: &tglSelesai,
		TipeObat:   input.TipeObat,
		Dosis:      input.Dosis,
		Frekuensi:  input.Frekuensi,
	}

	if err := validateTglSelesaiAgainstTglMulai(obat.TglMulai, obat.TglSelesai); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	result, err := ctrl.usecase.CreateObat(obat)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, models.Response{
		StatusCode: http.StatusCreated,
		Message:    "Obat berhasil dibuat",
		Data:       result,
	})
}

func (ctrl *obatController) GetByID(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	obat, err := ctrl.usecase.GetObatByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Obat ditemukan",
		Data:       obat,
	})
}

func (ctrl *obatController) GetKepatuhan(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	kepatuhan, err := ctrl.usecase.GetKepatuhanObat(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data kepatuhan obat ditemukan",
		Data:       kepatuhan,
	})
}

func (ctrl *obatController) GetRekapan(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	rekapan, err := ctrl.usecase.GetRekapanObat(uint(id))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Data rekapan obat ditemukan",
		Data:       rekapan,
	})
}

func (ctrl *obatController) GetByUserID(c echo.Context) error {
	userID, err := strconv.ParseUint(c.Param("user_id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "user_id tidak valid",
		})
	}

	// IDOR Protection: pastikan user yang login sesuai dengan user_id yang diminta
	loggedInUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}
	if uint(userID) != loggedInUserID {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak: Anda tidak memiliki izin untuk melihat data pengguna lain"})
	}

	obatList, err := ctrl.usecase.GetObatByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada obat, kembalikan array kosong
	if obatList == nil {
		obatList = []models.Obat{}
	}

	// Log untuk debugging
	log.Printf("📤 [ObatController] GetByUserID(%d) returning %d obat", userID, len(obatList))
	for i, o := range obatList {
		log.Printf("  💊 Obat[%d]: %s (ID=%d) dengan %d jadwal", i, o.NamaObat, o.IDObat, len(o.JadwalObat))
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar obat user",
		Data:       obatList,
	})
}

func (ctrl *obatController) GetAll(c echo.Context) error {
	obatList, err := ctrl.usecase.GetAllObat()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	// Jika tidak ada obat, kembalikan array kosong
	if obatList == nil {
		obatList = []models.Obat{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar semua obat",
		Data:       obatList,
	})
}

func (ctrl *obatController) Update(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	var input models.UpdateObatRequest

	if err := c.Bind(&input); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":  constants.MSG_INVALID_PAYLOAD,
			"detail": err.Error(),
		})
	}
	if input.TglMulai == nil || input.TglSelesai == nil || strings.TrimSpace(*input.TglSelesai) == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "tgl_mulai dan tgl_selesai harus diisi",
		})
	}

	if _, err := time.Parse("2006-01-02", strings.TrimSpace(*input.TglSelesai)); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "tgl_selesai harus berformat YYYY-MM-DD"})
	}

	obat, err := ctrl.usecase.UpdateObat(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Obat berhasil diperbarui",
		Data:       obat,
	})
}

func validateTglSelesaiAgainstTglMulai(tglMulai *models.CustomDate, tglSelesai *time.Time) error {
	if tglMulai == nil || tglSelesai == nil {
		return fmt.Errorf("tgl_mulai dan tgl_selesai harus diisi")
	}

	startTime := time.Time(*tglMulai)
	startDate := time.Date(startTime.Year(), startTime.Month(), startTime.Day(), 0, 0, 0, 0, startTime.Location())
	endDate := time.Date(tglSelesai.Year(), tglSelesai.Month(), tglSelesai.Day(), 0, 0, 0, 0, tglSelesai.Location())
	if endDate.Before(startDate) {
		return fmt.Errorf("tgl_selesai tidak boleh lebih awal dari tgl_mulai")
	}

	return nil
}

func (ctrl *obatController) Delete(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{
			"error": "ID tidak valid",
		})
	}

	if err := ctrl.usecase.DeleteObat(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Obat berhasil dihapus",
	})
}
