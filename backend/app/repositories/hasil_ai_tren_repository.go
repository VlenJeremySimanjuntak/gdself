package repositories

import (
	"monitoring-service/app/models"
	"gorm.io/gorm"
)

type HasilAITrenRepository interface {
	Create(tren models.HasilAITren) (models.HasilAITren, error)
	GetByID(id uint) (models.HasilAITren, error)
	GetByLaporanLabID(laporanLabID uint) (models.HasilAITren, error)
}

type hasilAITrenRepository struct {
	db *gorm.DB
}

func NewHasilAITrenRepository(db *gorm.DB) HasilAITrenRepository {
	return &hasilAITrenRepository{db: db}
}

func (r *hasilAITrenRepository) Create(tren models.HasilAITren) (models.HasilAITren, error) {
	err := r.db.Create(&tren).Error
	return tren, err
}

func (r *hasilAITrenRepository) GetByID(id uint) (models.HasilAITren, error) {
	var tren models.HasilAITren
	err := r.db.Preload("LaporanLab").First(&tren, id).Error
	return tren, err
}

func (r *hasilAITrenRepository) GetByLaporanLabID(laporanLabID uint) (models.HasilAITren, error) {
	var tren models.HasilAITren
	err := r.db.Where("id_laporan_lab = ?", laporanLabID).First(&tren).Error
	return tren, err
}