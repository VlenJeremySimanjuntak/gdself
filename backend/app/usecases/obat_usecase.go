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
	StatDiminum int      `json:"stat_diminum"`
	StatTotal   int      `json:"stat_total"`
	StatusLog   []string `json:"status_log"`
}

type ObatUsecase interface {
	CreateObat(obat models.Obat) (models.Obat, error)
	GetObatByID(id uint) (models.Obat, error)
	GetObatByUserID(userID uint) ([]models.Obat, error)
	GetAllObat() ([]models.Obat, error)
	UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error)
	DeleteObat(id uint) error
	GetKepatuhanObat(id uint) (ObatKepatuhanResponse, error)
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

func (u *obatUsecase) UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error) {
	if id == 0 {
		return models.Obat{}, fmt.Errorf("id tidak valid")
	}

	// 1. Ambil data lama dari database
	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	// 2. Update field yang ada di DTO (sesuaikan dengan struct UpdateObatRequest)
	if input.NamaObat != "" {
		obat.NamaObat = input.NamaObat
	}
	if input.Dosis != "" {
		obat.Dosis = input.Dosis
	}
	if input.Frekuensi != "" {
		obat.Frekuensi = input.Frekuensi
	}
	if input.TipeObat != "" {
		obat.TipeObat = input.TipeObat
	}

	// TglMulai tetap bisa diupdate jika dikirim
	if input.TglMulai != nil {
		obat.TglMulai = input.TglMulai
	}

	// 3. Simpan kembali ke repository
	return u.repo.Update(id, obat)
}

func (u *obatUsecase) GetKepatuhanObat(id uint) (ObatKepatuhanResponse, error) {
	if id == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("id tidak valid")
	}

	obat, statDiminum, statusLogs, err := u.repo.GetKepatuhanByID(id)
	if err != nil || obat.IDObat == 0 {
		return ObatKepatuhanResponse{}, fmt.Errorf("obat tidak ditemukan")
	}

	return ObatKepatuhanResponse{
		StatDiminum: int(statDiminum),
		StatTotal:   calculateStatTotal(obat.TglMulai, obat.Frekuensi),
		StatusLog:   statusLogs,
	}, nil
}

func calculateStatTotal(tglMulai *models.CustomDate, frekuensi string) int {
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

func (u *obatUsecase) DeleteObat(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if obat exists
	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return fmt.Errorf("obat tidak ditemukan")
	}

	return u.repo.Delete(id)
}
