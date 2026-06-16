package repositories

import (
	"monitoring-service/app/models"
	"gorm.io/gorm"
)

type HasilAILabRepository interface {
	Create(lab models.HasilAILab) (models.HasilAILab, error)
	GetByID(id uint) (models.HasilAILab, error)
	GetByLaporanLabID(laporanLabID uint) (models.HasilAILab, error)
}

type hasilAILabRepository struct {
	db *gorm.DB
}

func NewHasilAILabRepository(db *gorm.DB) HasilAILabRepository {
	return &hasilAILabRepository{db: db}
}

func (r *hasilAILabRepository) Create(lab models.HasilAILab) (models.HasilAILab, error) {
	err := r.db.Create(&lab).Error
	return lab, err
}

func (r *hasilAILabRepository) GetByID(id uint) (models.HasilAILab, error) {
	var lab models.HasilAILab
	err := r.db.Preload("LaporanLab").First(&lab, id).Error
	return lab, err
}

func (r *hasilAILabRepository) GetByLaporanLabID(laporanLabID uint) (models.HasilAILab, error) {
	var lab models.HasilAILab
	err := r.db.Where("id_laporan_lab = ?", laporanLabID).First(&lab).Error
	return lab, err
}