package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type UsgTiroidRepository interface {
	Create(usg models.USGTiroid) (models.USGTiroid, error)
	GetByID(id uint) (models.USGTiroid, error)
	GetByRiwayatID(riwayatID uint) ([]models.USGTiroid, error)
	GetByUserID(userID uint) ([]models.USGTiroid, error)
	GetAll() ([]models.USGTiroid, error)
	Update(id uint, usg models.USGTiroid) (models.USGTiroid, error)
	Delete(id uint) error
}

type usgTiroidRepository struct {
	db *gorm.DB
}

func NewUsgTiroidRepository(db *gorm.DB) UsgTiroidRepository {
	return &usgTiroidRepository{db: db}
}

func (r *usgTiroidRepository) Create(usg models.USGTiroid) (models.USGTiroid, error) {
	err := r.db.Create(&usg).Error
	return usg, err
}

func (r *usgTiroidRepository) GetByID(id uint) (models.USGTiroid, error) {
	var usg models.USGTiroid
	err := r.db.First(&usg, id).Error
	return usg, err
}

func (r *usgTiroidRepository) GetByRiwayatID(riwayatID uint) ([]models.USGTiroid, error) {
	var usgs []models.USGTiroid
	err := r.db.Where("id_riwayat = ?", riwayatID).Order("tgl_pemeriksaan DESC").Find(&usgs).Error
	return usgs, err
}

func (r *usgTiroidRepository) GetByUserID(userID uint) ([]models.USGTiroid, error) {
	var usgs []models.USGTiroid
	// Menggunakan JOIN karena id_user ada di tabel riwayat
	err := r.db.Joins("JOIN riwayat ON riwayat.id_riwayat = usg_tiroid.id_riwayat").
		Where("riwayat.id_user = ?", userID).
		Order("usg_tiroid.tgl_pemeriksaan DESC").
		Find(&usgs).Error
	return usgs, err
}

func (r *usgTiroidRepository) GetAll() ([]models.USGTiroid, error) {
	var usgs []models.USGTiroid
	err := r.db.Order("tgl_pemeriksaan DESC").Find(&usgs).Error
	return usgs, err
}

func (r *usgTiroidRepository) Update(id uint, usg models.USGTiroid) (models.USGTiroid, error) {
	err := r.db.Model(&models.USGTiroid{}).Where("id_usg = ?", id).Updates(usg).Error
	if err == nil {
		usg, err = r.GetByID(id)
	}
	return usg, err
}

func (r *usgTiroidRepository) Delete(id uint) error {
	return r.db.Delete(&models.USGTiroid{}, id).Error
}