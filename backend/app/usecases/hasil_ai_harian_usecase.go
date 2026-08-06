package usecases

import (
	"fmt"
	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type HasilAIHarianUsecase interface {
	CreateHasilAIHarian(harian models.HasilAIHarian) (models.HasilAIHarian, error)
	GetHasilAIHarianByID(id uint) (models.HasilAIHarian, error)
	GetHasilAIHarianByRiwayatID(riwayatID uint) ([]models.HasilAIHarian, error)
	GetHasilAIHarianByWearableID(wearableID uint) (models.HasilAIHarian, error)
}

type hasilAIHarianUsecase struct {
	repo repositories.HasilAIHarianRepository
}

func NewHasilAIHarianUsecase(repo repositories.HasilAIHarianRepository) HasilAIHarianUsecase {
	return &hasilAIHarianUsecase{repo: repo}
}

func (u *hasilAIHarianUsecase) CreateHasilAIHarian(harian models.HasilAIHarian) (models.HasilAIHarian, error) {
	if harian.IDWearable == 0 {
		return models.HasilAIHarian{}, fmt.Errorf("id_wearable tidak boleh kosong")
	}
	return u.repo.Create(harian)
}

func (u *hasilAIHarianUsecase) GetHasilAIHarianByID(id uint) (models.HasilAIHarian, error) {
	return u.repo.GetByID(id)
}

func (u *hasilAIHarianUsecase) GetHasilAIHarianByRiwayatID(riwayatID uint) ([]models.HasilAIHarian, error) {
	return u.repo.GetByRiwayatID(riwayatID)
}

func (u *hasilAIHarianUsecase) GetHasilAIHarianByWearableID(wearableID uint) (models.HasilAIHarian, error) {
	return u.repo.GetByWearableID(wearableID)
}