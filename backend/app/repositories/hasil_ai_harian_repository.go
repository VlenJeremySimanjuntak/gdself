package repositories

import (
	"monitoring-service/app/models"
	"gorm.io/gorm"
)

type HasilAIHarianRepository interface {
	Create(harian models.HasilAIHarian) (models.HasilAIHarian, error)
	GetByID(id uint) (models.HasilAIHarian, error)
	GetByRiwayatID(riwayatID uint) ([]models.HasilAIHarian, error)
	GetByWearableID(wearableID uint) (models.HasilAIHarian, error)
}

type hasilAIHarianRepository struct {
	db *gorm.DB
}

func NewHasilAIHarianRepository(db *gorm.DB) HasilAIHarianRepository {
	return &hasilAIHarianRepository{db: db}
}

func (r *hasilAIHarianRepository) Create(harian models.HasilAIHarian) (models.HasilAIHarian, error) {
	err := r.db.Create(&harian).Error
	return harian, err
}

func (r *hasilAIHarianRepository) GetByID(id uint) (models.HasilAIHarian, error) {
	var harian models.HasilAIHarian
	err := r.db.Preload("Wearable").First(&harian, id).Error
	return harian, err
}

func (r *hasilAIHarianRepository) GetByRiwayatID(riwayatID uint) ([]models.HasilAIHarian, error) {
	var harian []models.HasilAIHarian
	err := r.db.
		Joins("JOIN wearable ON wearable.id_wearable = hasil_ai_harian.id_wearable").
		Where("wearable.id_riwayat = ?", riwayatID).
		Order("hasil_ai_harian.created_at DESC").
		Find(&harian).Error
	return harian, err
}


func (r *hasilAIHarianRepository) GetByWearableID(wearableID uint) (models.HasilAIHarian, error) {
	var harian models.HasilAIHarian
	err := r.db.Where("id_wearable = ?", wearableID).First(&harian).Error
	return harian, err
}