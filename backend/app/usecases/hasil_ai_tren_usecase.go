package usecases

import (
	"fmt"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAITrenUsecase interface {
	CreateHasilAITren(tren models.HasilAITren) (models.HasilAITren, error)
	GetHasilAITrenByID(id uint) (models.HasilAITren, error)
	GetHasilAITrenByLaporanLabID(laporanLabID uint) (models.HasilAITren, error)
}

type hasilAITrenUsecase struct {
	repo repositories.HasilAITrenRepository
}

func NewHasilAITrenUsecase(repo repositories.HasilAITrenRepository) HasilAITrenUsecase {
	return &hasilAITrenUsecase{repo: repo}
}

func (u *hasilAITrenUsecase) CreateHasilAITren(tren models.HasilAITren) (models.HasilAITren, error) {
	if tren.IDLaporanLab == 0 {
		return models.HasilAITren{}, fmt.Errorf("id_laporan_lab tidak boleh kosong")
	}
	return u.repo.Create(tren)
}

func (u *hasilAITrenUsecase) GetHasilAITrenByID(id uint) (models.HasilAITren, error) {
	return u.repo.GetByID(id)
}

func (u *hasilAITrenUsecase) GetHasilAITrenByLaporanLabID(laporanLabID uint) (models.HasilAITren, error) {
	return u.repo.GetByLaporanLabID(laporanLabID)
}