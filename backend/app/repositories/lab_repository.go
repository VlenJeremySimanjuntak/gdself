package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type LabRepository interface {
	Create(lab models.HasilLab) (models.HasilLab, error)
	GetAll() ([]models.HasilLab, error)
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

func (r *labRepository) GetAll() ([]models.HasilLab, error) {
	var results []models.HasilLab
	err := r.db.Find(&results).Error
	return results, err
}

func (r *labRepository) GetByUserID(userID uint) ([]models.HasilLab, error) {
	var results []models.HasilLab
	// ✅ PERBAIKAN: Join dua kali (LaporanLab lalu Riwayat) untuk mengecek userID
	err := r.db.
		Joins("JOIN laporan_lab ON hasil_lab.id_laporan_lab = laporan_lab.id_laporan_lab").
		Joins("JOIN riwayat ON laporan_lab.id_riwayat = riwayat.id_riwayat").
		Where("riwayat.id_user = ?", userID).
		Preload("Parameter").
		Find(&results).Error
	return results, err
}