package usecases

import (
	"fmt"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAILabUsecase interface {
	CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error)
	GetHasilAILabByID(id uint) (models.HasilAILab, error)
	GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error)
}

type hasilAILabUsecase struct {
	repo repositories.HasilAILabRepository
}

func NewHasilAILabUsecase(repo repositories.HasilAILabRepository) HasilAILabUsecase {
	return &hasilAILabUsecase{repo: repo}
}

func (u *hasilAILabUsecase) CreateHasilAILab(lab models.HasilAILab) (models.HasilAILab, error) {
	if lab.IDLaporanLab == 0 {
		return models.HasilAILab{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}
	return u.repo.Create(lab)
}

func (u *hasilAILabUsecase) GetHasilAILabByID(id uint) (models.HasilAILab, error) {
	return u.repo.GetByID(id)
}

func (u *hasilAILabUsecase) GetHasilAILabByLaporanLabID(laporanLabID uint) (models.HasilAILab, error) {
	return u.repo.GetByLaporanLabID(laporanLabID)
}