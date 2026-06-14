package usecases

import (
	"fmt"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type LaporanLabUsecase interface {
	CreateLaporanLab(laporan models.LaporanLab) (models.LaporanLab, error)
	GetLaporanLabByID(id uint) (models.LaporanLab, error)
	GetLaporanLabByUserID(userID uint) ([]models.LaporanLab, error)
	GetAllLaporanLab() ([]models.LaporanLab, error)
	UpdateLaporanLab(id uint, input models.UpdateLaporanLabRequest) (models.LaporanLab, error)
	DeleteLaporanLab(id uint) error
}

type laporanLabUsecase struct {
	repo repositories.LaporanLabRepository
}

func NewLaporanLabUsecase(repo repositories.LaporanLabRepository) LaporanLabUsecase {
	return &laporanLabUsecase{repo: repo}
}

func (u *laporanLabUsecase) CreateLaporanLab(laporan models.LaporanLab) (models.LaporanLab, error) {
	if laporan.IDUser == 0 || laporan.NamaLab == "" {
		return models.LaporanLab{}, fmt.Errorf("id_user dan nama_lab tidak boleh kosong")
	}

	return u.repo.Create(laporan)
}

func (u *laporanLabUsecase) GetLaporanLabByID(id uint) (models.LaporanLab, error) {
	if id == 0 {
		return models.LaporanLab{}, fmt.Errorf("id tidak valid")
	}

	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("laporan lab tidak ditemukan")
	}

	return laporan, nil
}

func (u *laporanLabUsecase) GetLaporanLabByUserID(userID uint) ([]models.LaporanLab, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *laporanLabUsecase) GetAllLaporanLab() ([]models.LaporanLab, error) {
	return u.repo.GetAll()
}

func (u *laporanLabUsecase) UpdateLaporanLab(id uint, input models.UpdateLaporanLabRequest) (models.LaporanLab, error) {
	if id == 0 {
		return models.LaporanLab{}, fmt.Errorf("id tidak valid")
	}

	// Get existing laporan lab
	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("laporan lab tidak ditemukan")
	}

	// Update only non-empty fields
	if input.NamaLab != "" {
		laporan.NamaLab = input.NamaLab
	}
	if input.TglPeriksa != nil {
		laporan.TglPeriksa = input.TglPeriksa
	}

	return u.repo.Update(id, laporan)
}

func (u *laporanLabUsecase) DeleteLaporanLab(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if laporan lab exists
	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return fmt.Errorf("laporan lab tidak ditemukan")
	}

	return u.repo.Delete(id)
}
