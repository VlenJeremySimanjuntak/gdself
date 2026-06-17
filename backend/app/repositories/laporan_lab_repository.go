package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type LaporanLabRepository interface {
	Create(laporan models.LaporanLab) (models.LaporanLab, error)
	GetByID(id uint) (models.LaporanLab, error)
	GetByUserID(userID uint) ([]models.LaporanLab, error)
	GetByUserIDAndDate(userID uint, date string) (models.LaporanLab, error)
	GetAll() ([]models.LaporanLab, error)
	Update(id uint, laporan models.LaporanLab) (models.LaporanLab, error)
	Delete(id uint) error
}

type laporanLabRepository struct {
	db *gorm.DB
}

func NewLaporanLabRepository(db *gorm.DB) LaporanLabRepository {
	return &laporanLabRepository{db: db}
}

func (r *laporanLabRepository) Create(laporan models.LaporanLab) (models.LaporanLab, error) {
	err := r.db.Create(&laporan).Error
	return laporan, err
}

func (r *laporanLabRepository) GetByID(id uint) (models.LaporanLab, error) {
	var laporan models.LaporanLab
	// ✅ Tambahan Preload AI agar lengkap
	err := r.db.Preload("HasilLab.Parameter").Preload("HasilAILab").Preload("HasilAITren").First(&laporan, id).Error
	return laporan, err
}

func (r *laporanLabRepository) GetByUserID(userID uint) ([]models.LaporanLab, error) {
    var laporanList []models.LaporanLab
    err := r.db.
        Joins("JOIN riwayat ON riwayat.id_riwayat = laporan_lab.id_riwayat").
        Where("riwayat.id_user = ?", userID).
        Preload("Riwayat").
        Order("laporan_lab.id_laporan_lab DESC").
        Find(&laporanList).Error
    return laporanList, err
}


func (r *laporanLabRepository) GetByUserIDAndDate(userID uint, date string) (models.LaporanLab, error) {
	var laporan models.LaporanLab
	// ✅ PERBAIKAN: Join dengan Riwayat
	err := r.db.Joins("JOIN riwayat ON riwayat.id_riwayat = laporan_lab.id_riwayat").
		Where("riwayat.id_user = ? AND DATE(laporan_lab.tgl_periksa) = ?", userID, date).
		Preload("HasilLab.Parameter").Preload("HasilAILab").Preload("HasilAITren").
		First(&laporan).Error
	return laporan, err
}

func (r *laporanLabRepository) GetAll() ([]models.LaporanLab, error) {
	var laporan []models.LaporanLab
	err := r.db.Preload("HasilLab.Parameter").Find(&laporan).Error
	return laporan, err
}

func (r *laporanLabRepository) Update(id uint, laporan models.LaporanLab) (models.LaporanLab, error) {
	err := r.db.Model(&models.LaporanLab{}).Where("id_laporan_lab = ?", id).Updates(laporan).Error
	if err == nil {
		laporan, err = r.GetByID(id)
	}
	return laporan, err
}

func (r *laporanLabRepository) Delete(id uint) error {
	return r.db.Delete(&models.LaporanLab{}, id).Error
}