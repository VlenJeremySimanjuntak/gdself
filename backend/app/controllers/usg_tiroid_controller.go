package controllers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"monitoring-service/app/helpers"
	"monitoring-service/app/models"
	"monitoring-service/app/usecases"

	"github.com/disintegration/imaging"
	"github.com/labstack/echo/v4"
)

type USGTiroidController interface {
	Create(c echo.Context) error
	GetByID(c echo.Context) error
	GetByRiwayatID(c echo.Context) error
	GetByUserID(c echo.Context) error
	ServeFoto(c echo.Context) error
	ServeFotoThumbnail(c echo.Context) error
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

// thumbRelPathFromFoto menurunkan path relatif thumbnail dari path foto original.
// Contoh: "usg/abc.png" -> "usg/thumb_abc.jpg" (thumbnail SELALU .jpg).
func thumbRelPathFromFoto(fotoRel string) string {
	base := filepath.Base(fotoRel)          // "abc.png"
	ext := filepath.Ext(base)               // ".png"
	name := strings.TrimSuffix(base, ext)   // "abc"
	return "usg/thumb_" + name + ".jpg"
}

// generateUsgThumbnail membuat thumbnail ~400px dari file original.
// - imaging.Fit: downscale agar muat dalam 400x400, pertahankan rasio, TIDAK upscale.
// - AutoOrientation: hormati EXIF orientation dari kamera/HP.
// - Original TIDAK disentuh: detail klinis penuh tetap tersimpan di file asli.
func generateUsgThumbnail(originalDiskPath, thumbDiskPath string) error {
	img, err := imaging.Open(originalDiskPath, imaging.AutoOrientation(true))
	if err != nil {
		return fmt.Errorf("gagal membaca gambar untuk thumbnail: %w", err)
	}
	thumb := imaging.Fit(img, 400, 400, imaging.Lanczos)
	if err := imaging.Save(thumb, thumbDiskPath, imaging.JPEGQuality(80)); err != nil {
		return fmt.Errorf("gagal menyimpan thumbnail: %w", err)
	}
	return nil
}

// simpanFotoUsgAman menyimpan foto USG dengan validasi tipe/ukuran + nama acak.
// Original disimpan APA ADANYA (full-res, tanpa re-encode) agar detail klinis aman.
// Setelah itu di-generate thumbnail ~400px terpisah (best-effort).
// Mengembalikan path relatif ("usg/<acak>.ext"). String kosong = tidak ada file.
func (ctrl *usgTiroidController) simpanFotoUsgAman(c echo.Context) (string, error) {
	file, ferr := c.FormFile("foto")
	if ferr != nil {
		return "", nil // tidak ada file yang diupload, bukan error
	}

	if verr := helpers.ValidateImageUpload(file); verr != nil {
		return "", verr
	}

	src, err := file.Open()
	if err != nil {
		return "", fmt.Errorf("gagal membuka file")
	}
	defer src.Close()

	// Sniff MIME dari isi file (magic bytes)
	head := make([]byte, 512)
	n, _ := src.Read(head)
	if !helpers.IsAllowedImageContent(head[:n]) {
		return "", fmt.Errorf("isi file bukan gambar yang valid")
	}
	if _, err := src.Seek(0, io.SeekStart); err != nil {
		return "", fmt.Errorf("gagal memproses file")
	}

	uploadDir := filepath.Join("uploads", "usg")
	if err := os.MkdirAll(uploadDir, 0o750); err != nil {
		return "", fmt.Errorf("gagal menyiapkan folder upload")
	}

	fname, err := helpers.RandomFileName(file.Filename)
	if err != nil {
		return "", err
	}

	// 1. Simpan ORIGINAL full-res (io.Copy, tanpa decode/re-encode).
	originalDisk := filepath.Join(uploadDir, fname)
	dst, err := os.Create(originalDisk)
	if err != nil {
		return "", fmt.Errorf("gagal menyimpan file")
	}
	if _, err = io.Copy(dst, src); err != nil {
		dst.Close()
		return "", fmt.Errorf("gagal menyalin file")
	}
	// Tutup eksplisit sebelum dibaca ulang untuk thumbnail.
	if err := dst.Close(); err != nil {
		return "", fmt.Errorf("gagal menyimpan file")
	}

	fotoRel := "usg/" + fname // path RELATIF, bukan URL publik

	// 2. Generate THUMBNAIL ~400px (best-effort).
	//    Kalau gagal, JANGAN gagalkan upload — original tetap tersimpan &
	//    thumbnail bisa di-generate on-demand nanti di ServeFotoThumbnail.
	thumbDisk := filepath.Join(uploadDir, filepath.Base(thumbRelPathFromFoto(fotoRel)))
	if terr := generateUsgThumbnail(originalDisk, thumbDisk); terr != nil {
		c.Logger().Warnf("USG thumbnail gagal dibuat untuk %s: %v", fotoRel, terr)
	}

	return fotoRel, nil
}

func (ctrl *usgTiroidController) Create(c echo.Context) error {
	var input models.USGTiroid

	// 1. Ambil data teks (dukung snake_case & all-lowercase dari FE)
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

	// 2. Amankan CustomDate lewat unmarshal JSON string
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

	// 3. Upload foto (aman) + thumbnail
	fotoPath, err := ctrl.simpanFotoUsgAman(c)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	if fotoPath != "" {
		input.FotoPath = fotoPath
	}

	// Validasi field wajib
	if input.NamaRs == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "nama_rs harus diisi"})
	}

	result, err := ctrl.usecase.CreateUsgTiroid(input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	usg, err := ctrl.usecase.GetUsgTiroidByID(uint(id))
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "riwayat_id tidak valid"})
	}

	usgList, err := ctrl.usecase.GetUsgTiroidByRiwayatID(uint(riwayatID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "user_id tidak valid"})
	}

	// IDOR Protection
	loggedInUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}
	if uint(userID) != loggedInUserID {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak: Anda tidak memiliki izin untuk melihat data pengguna lain"})
	}

	usgList, err := ctrl.usecase.GetUsgTiroidByUserID(uint(userID))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
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

func (ctrl *usgTiroidController) GetAll(c echo.Context) error {
	usgList, err := ctrl.usecase.GetAllUsgTiroid()
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	var input models.USGTiroid
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

	// Upload foto baru saat update (aman + thumbnail, sama seperti Create)
	fotoPath, err := ctrl.simpanFotoUsgAman(c)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	if fotoPath != "" {
		input.FotoPath = fotoPath
	}

	usg, err := ctrl.usecase.UpdateUsgTiroid(uint(id), input)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
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
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	if err := ctrl.usecase.DeleteUsgTiroid(uint(id)); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, models.BasicResponse{
		StatusCode: http.StatusOK,
		Message:    "Data USG Tiroid berhasil dihapus",
	})
}

// ServeFoto melayani file foto USG ORIGINAL (full-res) hanya ke pemilik data (ber-JWT).
// Dipakai untuk DETAIL view.
func (ctrl *usgTiroidController) ServeFoto(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	loggedInUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}

	// Cek kepemilikan: USG -> riwayat.id_user
	ownerID, err := ctrl.usecase.GetUsgOwnerUserID(uint(id))
	if err != nil || ownerID == 0 {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "Data USG tidak ditemukan"})
	}
	if ownerID != loggedInUserID {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak: bukan milik Anda"})
	}

	usg, err := ctrl.usecase.GetUsgTiroidByID(uint(id))
	if err != nil || usg.FotoPath == "" {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "Foto tidak ditemukan"})
	}

	absPath, err := helpers.SafeUploadPath(filepath.Join("uploads", "usg"), usg.FotoPath)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "path file tidak valid"})
	}

	c.Response().Header().Set("Cache-Control", "private, max-age=86400")
	return c.File(absPath)
}

// ServeFotoThumbnail melayani THUMBNAIL (~400px) foto USG ke pemilik data (ber-JWT).
// Dipakai untuk preview di list / Monitoring. Kalau thumbnail belum ada (data lama),
// di-generate on-demand dari original, lalu disajikan. Kalau generate gagal,
// fallback ke original supaya gambar tetap tampil.
func (ctrl *usgTiroidController) ServeFotoThumbnail(c echo.Context) error {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "ID tidak valid"})
	}

	loggedInUserID, ok := c.Get("user_id").(uint)
	if !ok {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Token tidak valid"})
	}

	// Cek kepemilikan (sama persis dengan ServeFoto).
	ownerID, err := ctrl.usecase.GetUsgOwnerUserID(uint(id))
	if err != nil || ownerID == 0 {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "Data USG tidak ditemukan"})
	}
	if ownerID != loggedInUserID {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "Akses ditolak: bukan milik Anda"})
	}

	usg, err := ctrl.usecase.GetUsgTiroidByID(uint(id))
	if err != nil || usg.FotoPath == "" {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "Foto tidak ditemukan"})
	}

	baseDir := filepath.Join("uploads", "usg")

	thumbAbs, err := helpers.SafeUploadPath(baseDir, thumbRelPathFromFoto(usg.FotoPath))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "path file tidak valid"})
	}

	originalAbs, oerr := helpers.SafeUploadPath(baseDir, usg.FotoPath)
	if oerr != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "path file tidak valid"})
	}

	// Generate on-demand kalau thumbnail belum ada (data lama).
	if _, statErr := os.Stat(thumbAbs); os.IsNotExist(statErr) {
		if gerr := generateUsgThumbnail(originalAbs, thumbAbs); gerr != nil {
			// Fallback: sajikan original supaya gambar tetap muncul.
			c.Logger().Warnf("USG thumbnail on-demand gagal untuk id %d: %v", id, gerr)
			c.Response().Header().Set("Cache-Control", "private, max-age=86400")
			return c.File(originalAbs)
		}
	}

	c.Response().Header().Set("Cache-Control", "private, max-age=86400")
	return c.File(thumbAbs)
}