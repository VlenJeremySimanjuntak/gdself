package usecases

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type ObatKepatuhanResponse struct {
	StatDiminum     int      `json:"stat_diminum"`
	StatTotal       int      `json:"stat_total"`
	StatusLog       []string `json:"status_log"`
	StatusKepatuhan string   `json:"status_kepatuhan"` // "Menunggu Data" | "Rutin" | "Belum Rutin"
	ShowWarning     bool     `json:"show_warning"`     // true jika harus memunculkan modal
}

type ObatUsecase interface {
	CreateObat(obat models.Obat) (models.Obat, error)
	GetObatByID(id uint) (models.Obat, error)
	GetObatByUserID(userID uint) ([]models.Obat, error)
	GetAllObat() ([]models.Obat, error)
	UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error)
	DeleteObat(id uint) error
	GetKepatuhanObat(id uint) (ObatKepatuhanResponse, error)
	GetRekapanObat(id uint) (ObatKepatuhanResponse, error)
}

type obatUsecase struct {
	repo repositories.ObatRepository
}

func NewObatUsecase(repo repositories.ObatRepository) ObatUsecase {
	return &obatUsecase{repo: repo}
}

func (u *obatUsecase) CreateObat(obat models.Obat) (models.Obat, error) {
	if obat.IDUser == 0 || obat.NamaObat == "" {
		return models.Obat{}, fmt.Errorf("id_user dan nama_obat tidak boleh kosong")
	}
	if obat.TglMulai == nil || obat.TglSelesai == nil {
		return models.Obat{}, fmt.Errorf("tgl_mulai dan tgl_selesai harus diisi")
	}

	if err := validateTglSelesaiAgainstTglMulai(obat.TglMulai, obat.TglSelesai); err != nil {
		return models.Obat{}, err
	}

	return u.repo.Create(obat)
}

func (u *obatUsecase) GetObatByID(id uint) (models.Obat, error) {
	if id == 0 {
		return models.Obat{}, fmt.Errorf("id tidak valid")
	}

	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	return obat, nil
}

func (u *obatUsecase) GetObatByUserID(userID uint) ([]models.Obat, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *obatUsecase) GetAllObat() ([]models.Obat, error) {
	return u.repo.GetAll()
}

// ✅ PERBAIKAN UTAMA: Logika Integrasi New Prescription Approach & Mapping Jadwal Baru
func (u *obatUsecase) UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error) {
	if id == 0 {
		return models.Obat{}, fmt.Errorf("id tidak valid")
	}

	// 1. Ambil data lama dari database untuk referensi data yang tidak diubah
	obatLama, err := u.repo.GetByID(id)
	if err != nil || obatLama.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	// 2. Petakan field baru dari input DTO. Jika kosong, pertahankan nilai lama.
	namaObat := obatLama.NamaObat
	if input.NamaObat != "" {
		namaObat = input.NamaObat
	}
	dosis := obatLama.Dosis
	if input.Dosis != "" {
		dosis = input.Dosis
	}
	frekuensi := obatLama.Frekuensi
	if input.Frekuensi != "" {
		frekuensi = input.Frekuensi
	}
	tipeObat := obatLama.TipeObat
	if input.TipeObat != "" {
		tipeObat = input.TipeObat
	}

	if input.TglMulai == nil || input.TglSelesai == nil {
		return models.Obat{}, fmt.Errorf("tgl_mulai dan tgl_selesai harus diisi")
	}

	// Parsing tanggal selesai baru dari form Flutter
	tglSelesaiBaru, err := time.Parse("2006-01-02", strings.TrimSpace(*input.TglSelesai))
	if err != nil {
		return models.Obat{}, fmt.Errorf("tgl_selesai harus berformat YYYY-MM-DD")
	}

	// Definisikan waktu hari ini untuk memotong masa aktif resep lama
	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	// Validasi silang tanggal selesai baru terhadap tanggal mulai baru yang dikirim Flutter
	if err := validateTglSelesaiAgainstTglMulai(input.TglMulai, &tglSelesaiBaru); err != nil {
		return models.Obat{}, err
	}

	// ==================== MAPPING JADWAL OBAT BARU ====================
	var jadwalBaru []models.JadwalObat

	if len(input.JadwalObat) > 0 {
		// A. Jika Flutter mengirim struktur jadwal yang diubah oleh pengguna
		for _, j := range input.JadwalObat {
			jadwalBaru = append(jadwalBaru, models.JadwalObat{
				Hari:           j.Hari,
				WaktuMinumObat: j.WaktuMinumObat,
				// IDObat & IDJadwalObat dikosongkan agar GORM men-generate ID baru dalam record resep baru
			})
		}
	} else {
		// B. Jika Flutter tidak merubah jadwal, wariskan jadwal lama ke resep baru
		for _, j := range obatLama.JadwalObat {
			jadwalBaru = append(jadwalBaru, models.JadwalObat{
				Hari:           j.Hari,
				WaktuMinumObat: j.WaktuMinumObat,
			})
		}
	}
	// ==================================================================

	// 3. Susun struktur objek Obat yang baru
	obatBaru := models.Obat{
		IDUser:     obatLama.IDUser,
		NamaObat:   namaObat,
		Dosis:      dosis,
		Frekuensi:  frekuensi,
		TipeObat:   tipeObat,
		TglMulai:   input.TglMulai,
		TglSelesai: &tglSelesaiBaru,
		JadwalObat: jadwalBaru, // Mengikat data anak tabel jadwal_obat yang baru
	}

	// 4. Perintahkan repository mengeksekusi pembaruan via jalur Transaksi
	return u.repo.UpdateResepBaru(id, today, obatBaru)
}

func (u *obatUsecase) GetKepatuhanObat(id uint) (ObatKepatuhanResponse, error) {
	if id == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("id tidak valid")
	}

	obat, statDiminum, statusLogs, err := u.repo.GetKepatuhanByID(id)
	if err != nil || obat.IDObat == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("obat tidak ditemukan")
	}

	statusKepatuhan := "Rutin"
	showWarning := false

	if len(statusLogs) < 3 {
		statusKepatuhan = "Menunggu Data"
		showWarning = false
	} else {
		hasTerlewat := false
		for _, status := range statusLogs {
			if strings.TrimSpace(status) == "Terlewat" {
				hasTerlewat = true
				break
			}
		}

		if hasTerlewat {
			statusKepatuhan = "Belum Rutin"
			showWarning = true
		}
	}

	return ObatKepatuhanResponse{
		StatDiminum:     int(statDiminum),
		StatTotal:       HitungStatTotalBerjalan(obat.TglMulai, obat.Frekuensi),
		StatusLog:       statusLogs,
		StatusKepatuhan: statusKepatuhan,
		ShowWarning:     showWarning,
	}, nil
}

func (u *obatUsecase) GetRekapanObat(id uint) (ObatKepatuhanResponse, error) {
	if id == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("id tidak valid")
	}

	obat, statDiminum, statusLogs, err := u.repo.GetKepatuhanByID(id)
	if err != nil || obat.IDObat == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("obat tidak ditemukan")
	}

	if obat.TglSelesai == nil {
		return ObatKepatuhanResponse{}, fmt.Errorf("tgl_selesai belum diisi")
	}

	return ObatKepatuhanResponse{
		StatDiminum:     int(statDiminum),
		StatTotal:       HitungStatTotalRekap(obat.TglMulai, obat.TglSelesai, obat.Frekuensi),
		StatusLog:       statusLogs,
		StatusKepatuhan: "",
		ShowWarning:     false,
	}, nil
}

func HitungStatTotalBerjalan(tglMulai *models.CustomDate, frekuensi string) int {
	if tglMulai == nil {
		return 0
	}

	startTime := time.Time(*tglMulai)
	startDate := time.Date(startTime.Year(), startTime.Month(), startTime.Day(), 0, 0, 0, 0, startTime.Location())
	todayTime := time.Now()
	todayDate := time.Date(todayTime.Year(), todayTime.Month(), todayTime.Day(), 0, 0, 0, 0, todayTime.Location())
	if todayDate.Before(startDate) {
		return 0
	}

	days := int(todayDate.Sub(startDate).Hours()/24) + 1
	if days <= 0 {
		return 0
	}

	dailyFrequency := parseDailyFrequency(frekuensi)
	if dailyFrequency <= 0 {
		dailyFrequency = 1
	}

	return days * dailyFrequency
}

func HitungStatTotalRekap(tglMulai *models.CustomDate, tglSelesai *time.Time, frekuensi string) int {
	if tglMulai == nil || tglSelesai == nil {
		return 0
	}

	startTime := time.Time(*tglMulai)
	endTime := *tglSelesai
	startDate := time.Date(startTime.Year(), startTime.Month(), startTime.Day(), 0, 0, 0, 0, startTime.Location())
	endDate := time.Date(endTime.Year(), endTime.Month(), endTime.Day(), 0, 0, 0, 0, endTime.Location())
	if endDate.Before(startDate) {
		return 0
	}

	days := int(endDate.Sub(startDate).Hours()/24) + 1
	if days <= 0 {
		return 0
	}

	dailyFrequency := parseDailyFrequency(frekuensi)
	if dailyFrequency <= 0 {
		dailyFrequency = 1
	}

	return days * dailyFrequency
}

func parseDailyFrequency(frekuensi string) int {
	frekuensi = strings.TrimSpace(frekuensi)
	if frekuensi == "" {
		return 1
	}

	re := regexp.MustCompile(`\d+`)
	match := re.FindString(frekuensi)
	if match == "" {
		return 1
	}

	nilai, err := strconv.Atoi(match)
	if err != nil || nilai <= 0 {
		return 1
	}

	return nilai
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

func (u *obatUsecase) DeleteObat(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return fmt.Errorf("obat tidak ditemukan")
	}

	return u.repo.Delete(id)
}