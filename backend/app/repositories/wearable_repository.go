package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type WearableRepository interface {
	Create(wearable models.WearableRecord) (models.WearableRecord, error)
	GetByID(id uint) (models.WearableRecord, error)
	GetByRiwayatID(riwayatID uint) ([]models.WearableRecord, error)
	GetByUserID(userID uint) ([]models.WearableRecord, error)
	GetAll() ([]models.WearableRecord, error)
	Update(id uint, wearable models.WearableRecord) (models.WearableRecord, error)
	Delete(id uint) error
}

type wearableRepository struct {
	db *gorm.DB
}

func NewWearableRepository(db *gorm.DB) WearableRepository {
	return &wearableRepository{db: db}
}

func (r *wearableRepository) Create(wearable models.WearableRecord) (models.WearableRecord, error) {
	err := r.db.Create(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetByID(id uint) (models.WearableRecord, error) {
	var wearable models.WearableRecord
	err := r.db.Preload("Riwayat").Preload("HasilAIHarian").Preload("HasilAIGabungan").First(&wearable, id).Error
	return wearable, err
}

func (r *wearableRepository) GetByRiwayatID(riwayatID uint) ([]models.WearableRecord, error) {
	var wearable []models.WearableRecord
	err := r.db.Where("id_riwayat = ?", riwayatID).
		Preload("Riwayat").
		Preload("HasilAIHarian").
		Preload("HasilAIGabungan").
		Order("tgl_data DESC, waktu_data DESC").
		Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetByUserID(userID uint) ([]models.WearableRecord, error) {
	var wearable []models.WearableRecord
	// Wearable no longer stores id_user. Join via riwayat.
	err := r.db.Model(&models.WearableRecord{}).
		Joins("JOIN riwayat r ON r.id_riwayat = wearable.id_riwayat").
		Where("r.id_user = ?", userID).
		Preload("Riwayat").
		Preload("HasilAIHarian").
		Preload("HasilAIGabungan").
		Order("tgl_data DESC, waktu_data DESC").
		Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetAll() ([]models.WearableRecord, error) {
	var wearable []models.WearableRecord
	err := r.db.Preload("Riwayat").Preload("HasilAIHarian").Preload("HasilAIGabungan").Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) Update(id uint, wearable models.WearableRecord) (models.WearableRecord, error) {
	err := r.db.Model(&models.WearableRecord{}).Where("id_wearable = ?", id).Updates(wearable).Error
	if err == nil {
		wearable, err = r.GetByID(id)
	}
	return wearable, err
}

func (r *wearableRepository) Delete(id uint) error {
	return r.db.Delete(&models.WearableRecord{}, id).Error
}
