package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type LabRepository interface {
	Create(lab models.HasilLab) (models.HasilLab, error)
	GetAll() ([]models.HasilLab, error) // Kontrak mewajibkan ini
	GetByUserID(userID uint) ([]models.HasilLab, error)
}

type labRepository struct {
	db *gorm.DB
}

func NewLabRepository(db *gorm.DB) LabRepository {
	return &labRepository{db: db}
}

func (r *labRepository) Create(lab models.HasilLab) (models.HasilLab, error) {
	err := r.db.Create(&lab).Error
	return lab, err
}

// TAMBAHKAN INI: Supaya kontrak 'GetAll' terpenuhi
func (r *labRepository) GetAll() ([]models.HasilLab, error) {
	var results []models.HasilLab
	err := r.db.Find(&results).Error
	return results, err
}

// Ini fungsi tambahan kamu, tetap pertahankan
func (r *labRepository) GetByUserID(userID uint) ([]models.HasilLab, error) {
	var results []models.HasilLab
	// Join dengan laporan_lab untuk mendapatkan hasil lab berdasarkan user_id
	err := r.db.
		Joins("JOIN laporan_lab ON hasil_lab.id_laporan_lab = laporan_lab.id_laporan_lab").
		Where("laporan_lab.id_user = ?", userID).
		Find(&results).Error
	return results, err
}
