package usecases

import (
	"fmt"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type RiwayatUsecase interface {
	CreateRiwayat(riwayat models.Riwayat) (models.Riwayat, error)
	GetRiwayatByID(id uint) (models.Riwayat, error)
	GetRiwayatByUserID(userID uint) ([]models.Riwayat, error)
	GetAllRiwayat() ([]models.Riwayat, error)
	UpdateRiwayat(id uint, input models.UpdateRiwayatRequest) (models.Riwayat, error)
	DeleteRiwayat(id uint) error
}

type riwayatUsecase struct {
	repo repositories.RiwayatRepository
}

func NewRiwayatUsecase(repo repositories.RiwayatRepository) RiwayatUsecase {
	return &riwayatUsecase{repo: repo}
}

func (u *riwayatUsecase) CreateRiwayat(riwayat models.Riwayat) (models.Riwayat, error) {
	if riwayat.IDUser == 0 {
		return models.Riwayat{}, fmt.Errorf("id_user tidak boleh kosong")
	}

	return u.repo.Create(riwayat)
}

func (u *riwayatUsecase) GetRiwayatByID(id uint) (models.Riwayat, error) {
	if id == 0 {
		return models.Riwayat{}, fmt.Errorf("id tidak valid")
	}

	riwayat, err := u.repo.GetByID(id)
	if err != nil || riwayat.IDRiwayat == 0 {
		return models.Riwayat{}, fmt.Errorf("riwayat tidak ditemukan")
	}

	return riwayat, nil
}

func (u *riwayatUsecase) GetRiwayatByUserID(userID uint) ([]models.Riwayat, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *riwayatUsecase) GetAllRiwayat() ([]models.Riwayat, error) {
	return u.repo.GetAll()
}

func (u *riwayatUsecase) UpdateRiwayat(id uint, input models.UpdateRiwayatRequest) (models.Riwayat, error) {
	if id == 0 {
		return models.Riwayat{}, fmt.Errorf("id tidak valid")
	}

	// Get existing riwayat
	riwayat, err := u.repo.GetByID(id)
	if err != nil || riwayat.IDRiwayat == 0 {
		return models.Riwayat{}, fmt.Errorf("riwayat tidak ditemukan")
	}

	// Update only non-empty fields
	if input.Tanggal != nil {
		riwayat.Tanggal = input.Tanggal
	}

	return u.repo.Update(id, riwayat)
}

func (u *riwayatUsecase) DeleteRiwayat(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if riwayat exists
	riwayat, err := u.repo.GetByID(id)
	if err != nil || riwayat.IDRiwayat == 0 {
		return fmt.Errorf("riwayat tidak ditemukan")
	}

	return u.repo.Delete(id)
}
