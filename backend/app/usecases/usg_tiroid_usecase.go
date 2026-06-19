package usecases

import (
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type UsgTiroidUsecase interface {
	CreateUsgTiroid(usg models.USGTiroid) (models.USGTiroid, error)
	GetUsgTiroidByID(id uint) (models.USGTiroid, error)
	GetUsgTiroidByRiwayatID(riwayatID uint) ([]models.USGTiroid, error)
	GetUsgTiroidByUserID(userID uint) ([]models.USGTiroid, error)
	GetAllUsgTiroid() ([]models.USGTiroid, error)
	UpdateUsgTiroid(id uint, input models.USGTiroid) (models.USGTiroid, error)
	DeleteUsgTiroid(id uint) error
}

type usgTiroidUsecase struct {
	repo repositories.UsgTiroidRepository
}

func NewUsgTiroidUsecase(repo repositories.UsgTiroidRepository) UsgTiroidUsecase {
	return &usgTiroidUsecase{repo: repo}
}

func (u *usgTiroidUsecase) CreateUsgTiroid(usg models.USGTiroid) (models.USGTiroid, error) {
	// Langsung dilempar ke repo repository tanpa validasi penghambat
	return u.repo.Create(usg)
}

func (u *usgTiroidUsecase) GetUsgTiroidByID(id uint) (models.USGTiroid, error) {
	return u.repo.GetByID(id)
}

func (u *usgTiroidUsecase) GetUsgTiroidByRiwayatID(riwayatID uint) ([]models.USGTiroid, error) {
	return u.repo.GetByRiwayatID(riwayatID)
}

func (u *usgTiroidUsecase) GetUsgTiroidByUserID(userID uint) ([]models.USGTiroid, error) {
	return u.repo.GetByUserID(userID)
}

func (u *usgTiroidUsecase) GetAllUsgTiroid() ([]models.USGTiroid, error) {
	return u.repo.GetAll()
}

func (u *usgTiroidUsecase) UpdateUsgTiroid(id uint, input models.USGTiroid) (models.USGTiroid, error) {
	return u.repo.Update(id, input)
}

func (u *usgTiroidUsecase) DeleteUsgTiroid(id uint) error {
	return u.repo.Delete(id)
}