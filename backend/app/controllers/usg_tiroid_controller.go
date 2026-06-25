package controllers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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

	// 1. Ambil data teks secara manual (Mendukung snake_case maupun all-lowercase dari FE)
	idRiwayatStr := c.FormValue("id_riwayat")
	if idRiwayatStr == "" {
		idRiwayatStr = c.FormValue("idriwayat")
	}
	if idRiwayatStr != "" {
		id, _ := strconv.ParseUint(idRiwayatStr, 10, 32)
		input.IDRiwayat = uint(id)
	}

	input.NamaRs = c.FormValue("nama_rs")
	if input.NamaRs == "" {
		input.NamaRs = c.FormValue("namars")
	}

	input.CatatanDokter = c.FormValue("catatan_dokter")
	if input.CatatanDokter == "" {
		input.CatatanDokter = c.FormValue("catatandokter")
	}

	// 2. Trik Amankan CustomDate: Lakukan unmarshal via json string agar mengikuti aturan CustomDate dari BE Mas
	tglStr := c.FormValue("tgl_pemeriksaan")
	if tglStr == "" {
		tglStr = c.FormValue("tglpemeriksaan")
	}
	if tglStr != "" {
		type DateBinder struct {
			Tgl *models.CustomDate `json:"tgl"`
		}
		var db DateBinder
		jsonStr := fmt.Sprintf(`{"tgl":"%s"}`, tglStr)
		if err := json.Unmarshal([]byte(jsonStr), &db); err == nil {
			input.TglPemeriksaan = db.Tgl
		}
	}

	// 3. Tangani Upload File Foto
	file, err := c.FormFile("foto")
	if err == nil {
		src, err := file.Open()
		if err == nil {
			defer src.Close()

			// Buat direktori penyimpanan jika belum ada
			uploadDir := filepath.Join("uploads", "usg")
			_ = os.MkdirAll(uploadDir, os.ModePerm)

			// Simpan file dengan nama unik bawaan file asal
			dstPath := filepath.Join(uploadDir, file.Filename)
			dst, err := os.Create(dstPath)
			if err == nil {
				defer dst.Close()
				if _, err = io.Copy(dst, src); err == nil {
					input.FotoPath = "/" + dstPath // Path inilah yang masuk ke database
				}
			}
		}
	}

	// Validasi field wajib
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

	// IDOR Protection: pastikan user yang login sesuai dengan user_id yang diminta
	loggedInUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}
	if uint(userID) != loggedInUserID {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak: Anda tidak memiliki izin untuk melihat data pengguna lain"})
	}

	usgList, err := ctrl.usecase.GetUsgTiroidByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

	if usgList == nil {
		usgList = []models.USGTiroid{}
	}

	return c.JSON(http.StatusOK, models.Response{
		StatusCode: http.StatusOK,
		Message:    "Daftar USG Tiroid dari user",
		Data:       usgList,
	})
}

func (ctrl *usgTiroidController) TemplateMethod(c echo.Context) error {
	return nil
}

func (ctrl *usgTiroidController) GetAll(c echo.Context) error {
	usgList, err := ctrl.usecase.GetAllUsgTiroid()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{
			"error": err.Error(),
		})
	}

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

	// Membaca input teks perubahan secara manual agar konsisten aman dari Multipart Form
	namaRs := c.FormValue("nama_rs")
	if namaRs == "" {
		namaRs = c.FormValue("namars")
	}
	input.NamaRs = namaRs
	input.CatatanDokter = c.FormValue("catatan_dokter")

	tglStr := c.FormValue("tgl_pemeriksaan")
	if tglStr != "" {
		type DateBinder struct {
			Tgl *models.CustomDate `json:"tgl"`
		}
		var db DateBinder
		jsonStr := fmt.Sprintf(`{"tgl":"%s"}`, tglStr)
		_ = json.Unmarshal([]byte(jsonStr), &db)
		input.TglPemeriksaan = db.Tgl
	}

	// Tangani perubahan file foto baru saat update jika ada
	file, err := c.FormFile("foto")
	if err == nil {
		src, err := file.Open()
		if err == nil {
			defer src.Close()
			uploadDir := filepath.Join("uploads", "usg")
			_ = os.MkdirAll(uploadDir, os.ModePerm)
			dstPath := filepath.Join(uploadDir, file.Filename)
			dst, err := os.Create(dstPath)
			if err == nil {
				defer dst.Close()
				if _, err = io.Copy(dst, src); err == nil {
					input.FotoPath = "/" + dstPath
				}
			}
		}
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