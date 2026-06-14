package usecases

import (
	"fmt"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type JadwalObatUsecase interface {
	CreateJadwalObat(jadwalObat models.JadwalObat) (models.JadwalObat, error)
	GetJadwalObatByID(id uint) (models.JadwalObat, error)
	GetJadwalObatByObatID(obatID uint) ([]models.JadwalObat, error)
	GetAllJadwalObat() ([]models.JadwalObat, error)
	UpdateJadwalObat(id uint, input models.UpdateJadwalObatRequest) (models.JadwalObat, error)
	DeleteJadwalObat(id uint) error
}

type jadwalObatUsecase struct {
	repo repositories.JadwalObatRepository
}

func NewJadwalObatUsecase(repo repositories.JadwalObatRepository) JadwalObatUsecase {
	return &jadwalObatUsecase{repo: repo}
}

func (u *jadwalObatUsecase) CreateJadwalObat(jadwalObat models.JadwalObat) (models.JadwalObat, error) {
	if jadwalObat.IDObat == 0 {
		return models.JadwalObat{}, fmt.Errorf("id_obat tidak boleh kosong")
	}

	return u.repo.Create(jadwalObat)
}

func (u *jadwalObatUsecase) GetJadwalObatByID(id uint) (models.JadwalObat, error) {
	if id == 0 {
		return models.JadwalObat{}, fmt.Errorf("id tidak valid")
	}

	jadwalObat, err := u.repo.GetByID(id)
	if err != nil || jadwalObat.IDJadwalObat == 0 {
		return models.JadwalObat{}, fmt.Errorf("jadwal obat tidak ditemukan")
	}

	return jadwalObat, nil
}

func (u *jadwalObatUsecase) GetJadwalObatByObatID(obatID uint) ([]models.JadwalObat, error) {
	if obatID == 0 {
		return nil, fmt.Errorf("obat_id tidak valid")
	}

	return u.repo.GetByObatID(obatID)
}

func (u *jadwalObatUsecase) GetAllJadwalObat() ([]models.JadwalObat, error) {
	return u.repo.GetAll()
}

func (u *jadwalObatUsecase) UpdateJadwalObat(id uint, input models.UpdateJadwalObatRequest) (models.JadwalObat, error) {
	if id == 0 {
		return models.JadwalObat{}, fmt.Errorf("id tidak valid")
	}

	// Get existing jadwal obat
	jadwalObat, err := u.repo.GetByID(id)
	if err != nil || jadwalObat.IDJadwalObat == 0 {
		return models.JadwalObat{}, fmt.Errorf("jadwal obat tidak ditemukan")
	}

	// Update only non-empty fields
	if input.WaktuMinumObat != nil {
		jadwalObat.WaktuMinumObat = input.WaktuMinumObat
	}

	return u.repo.Update(id, jadwalObat)
}

func (u *jadwalObatUsecase) DeleteJadwalObat(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if jadwal obat exists
	jadwalObat, err := u.repo.GetByID(id)
	if err != nil || jadwalObat.IDJadwalObat == 0 {
		return fmt.Errorf("jadwal obat tidak ditemukan")
	}

	return u.repo.Delete(id)
}
