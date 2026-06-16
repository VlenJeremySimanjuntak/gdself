package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type WearableRepository interface {
	Create(wearable models.Wearable) (models.Wearable, error)
	GetByID(id uint) (models.Wearable, error)
	GetByRiwayatID(riwayatID uint) ([]models.Wearable, error)
	GetByUserID(userID uint) ([]models.Wearable, error)
	GetAll() ([]models.Wearable, error)
	Update(id uint, wearable models.Wearable) (models.Wearable, error)
	Delete(id uint) error
}

type wearableRepository struct {
	db *gorm.DB
}

func NewWearableRepository(db *gorm.DB) WearableRepository {
	return &wearableRepository{db: db}
}

func (r *wearableRepository) Create(wearable models.Wearable) (models.Wearable, error) {
	err := r.db.Create(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetByID(id uint) (models.Wearable, error) {
	var wearable models.Wearable
	// ✅ PERBAIKAN: HasilAIGabungan dihapus, sisa HasilAIHarian saja
	err := r.db.Preload("HasilAIHarian").First(&wearable, id).Error
	return wearable, err
}

func (r *wearableRepository) GetByRiwayatID(riwayatID uint) ([]models.Wearable, error) {
	var wearable []models.Wearable
	err := r.db.Where("id_riwayat = ?", riwayatID).
		Preload("HasilAIHarian").
		Order("tgl_data DESC, waktu_data DESC").
		Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetByUserID(userID uint) ([]models.Wearable, error) {
	var wearable []models.Wearable
	// Wearable no longer stores id_user. Join via riwayat.
	err := r.db.Model(&models.Wearable{}).
		Joins("JOIN riwayat r ON r.id_riwayat = wearable.id_riwayat").
		Where("r.id_user = ?", userID).
		Preload("HasilAIHarian").
		Order("tgl_data DESC, waktu_data DESC").
		Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) GetAll() ([]models.Wearable, error) {
	var wearable []models.Wearable
	err := r.db.Preload("HasilAIHarian").Find(&wearable).Error
	return wearable, err
}

func (r *wearableRepository) Update(id uint, wearable models.Wearable) (models.Wearable, error) {
	err := r.db.Model(&models.Wearable{}).Where("id_wearable = ?", id).Updates(wearable).Error
	if err == nil {
		wearable, err = r.GetByID(id)
	}
	return wearable, err
}

func (r *wearableRepository) Delete(id uint) error {
	return r.db.Delete(&models.Wearable{}, id).Error
}