package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type ObatUsecase interface {
	CreateObat(obat models.Obat) (models.Obat, error)
	GetObatByID(id uint) (models.Obat, error)
	GetObatByUserID(userID uint) ([]models.Obat, error)
	GetAllObat() ([]models.Obat, error)
	UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error)
	DeleteObat(id uint) error
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

	// Get existing obat
	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	// Update only non-empty fields
	if input.NamaObat != "" {
		obat.NamaObat = input.NamaObat
	}
	if input.Dosis != "" {
		obat.Dosis = input.Dosis
	}
	if input.Frekuensi != "" {
		obat.Frekuensi = input.Frekuensi
	}
	if input.HariKonsumsi != "" {
		obat.HariKonsumsi = input.HariKonsumsi
	}
	if input.StatusAktif != nil {
		obat.StatusAktif = *input.StatusAktif
	}

	// 👇 TAMBAHKAN BLOK KODE INI MAS 👇
	if input.TanggalMulai != nil && *input.TanggalMulai != "" {
		t, err := time.Parse("2006-01-02", *input.TanggalMulai)
		if err == nil {
			obat.TanggalMulai = &t
		}
	}
	// 👆 SAMPAI SINI 👆

	return u.repo.Update(id, obat)
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
