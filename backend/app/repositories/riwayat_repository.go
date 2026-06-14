package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type RiwayatRepository interface {
	Create(riwayat models.Riwayat) (models.Riwayat, error)
	GetByID(id uint) (models.Riwayat, error)
	GetByUserID(userID uint) ([]models.Riwayat, error)
	GetAll() ([]models.Riwayat, error)
	Update(id uint, riwayat models.Riwayat) (models.Riwayat, error)
	Delete(id uint) error
}

type riwayatRepository struct {
	db *gorm.DB
}

func NewRiwayatRepository(db *gorm.DB) RiwayatRepository {
	return &riwayatRepository{db: db}
}

func (r *riwayatRepository) Create(riwayat models.Riwayat) (models.Riwayat, error) {
	err := r.db.Create(&riwayat).Error
	return riwayat, err
}

func (r *riwayatRepository) GetByID(id uint) (models.Riwayat, error) {
	var riwayat models.Riwayat
	err := r.db.Preload("Wearable").Preload("HasilLab").Preload("HasilAI").First(&riwayat, id).Error
	return riwayat, err
}

func (r *riwayatRepository) GetByUserID(userID uint) ([]models.Riwayat, error) {
	var riwayat []models.Riwayat
	err := r.db.Where("id_user = ?", userID).
		Preload("Wearable").
		Preload("HasilLab").
		Preload("HasilAI").
		Order("tanggal DESC").
		Find(&riwayat).Error
	return riwayat, err
}

func (r *riwayatRepository) GetAll() ([]models.Riwayat, error) {
	var riwayat []models.Riwayat
	err := r.db.Preload("Wearable").Preload("HasilLab").Preload("HasilAI").Find(&riwayat).Error
	return riwayat, err
}

func (r *riwayatRepository) Update(id uint, riwayat models.Riwayat) (models.Riwayat, error) {
	err := r.db.Model(&models.Riwayat{}).Where("id_riwayat = ?", id).Updates(riwayat).Error
	if err == nil {
		riwayat, err = r.GetByID(id)
	}
	return riwayat, err
}

func (r *riwayatRepository) Delete(id uint) error {
	return r.db.Delete(&models.Riwayat{}, id).Error
}
