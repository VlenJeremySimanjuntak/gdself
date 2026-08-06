package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type HasilLabRepository interface {
	Create(hasilLab models.HasilLab) (models.HasilLab, error)
	GetByID(id uint) (models.HasilLab, error)
	GetByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error)
	GetByRiwayatID(riwayatID uint) ([]models.HasilLab, error)
	GetByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error)
	GetAll() ([]models.HasilLab, error)
	Update(id uint, hasilLab models.HasilLab) (models.HasilLab, error)
	Delete(id uint) error
}

type hasilLabRepository struct {
	db *gorm.DB
}

func NewHasilLabRepository(db *gorm.DB) HasilLabRepository {
	return &hasilLabRepository{db: db}
}

func (r *hasilLabRepository) Create(hasilLab models.HasilLab) (models.HasilLab, error) {
	err := r.db.Create(&hasilLab).Error
	return hasilLab, err
}

func (r *hasilLabRepository) GetByID(id uint) (models.HasilLab, error) {
	var hasilLab models.HasilLab
	err := r.db.Preload("Parameter").First(&hasilLab, id).Error
	return hasilLab, err
}

func (r *hasilLabRepository) GetByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error) {
	var hasilLab []models.HasilLab
	err := r.db.Where("id_laporan_lab = ?", laporanLabID).Preload("Parameter").Order("created_at DESC").Find(&hasilLab).Error
	return hasilLab, err
}

func (r *hasilLabRepository) GetByRiwayatID(riwayatID uint) ([]models.HasilLab, error) {
	var hasilLab []models.HasilLab
	// ✅ PERBAIKAN: Join LaporanLab untuk mencari id_riwayat
	err := r.db.Joins("JOIN laporan_lab ON hasil_lab.id_laporan_lab = laporan_lab.id_laporan_lab").
		Where("laporan_lab.id_riwayat = ?", riwayatID).
		Preload("Parameter").Order("hasil_lab.created_at DESC").Find(&hasilLab).Error
	return hasilLab, err
}

func (r *hasilLabRepository) GetByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error) {
	var hasilLab []models.HasilLab
	// ✅ PERBAIKAN: Join LaporanLab
	err := r.db.Joins("JOIN laporan_lab ON hasil_lab.id_laporan_lab = laporan_lab.id_laporan_lab").
		Where("laporan_lab.id_riwayat = ? AND laporan_lab.tgl_periksa = ?", riwayatID, date).
		Preload("Parameter").Order("hasil_lab.created_at DESC").Find(&hasilLab).Error
	return hasilLab, err
}

func (r *hasilLabRepository) GetAll() ([]models.HasilLab, error) {
	var hasilLab []models.HasilLab
	err := r.db.Preload("Parameter").Find(&hasilLab).Error
	return hasilLab, err
}

func (r *hasilLabRepository) Update(id uint, hasilLab models.HasilLab) (models.HasilLab, error) {
	err := r.db.Model(&models.HasilLab{}).Where("id_hasil_lab = ?", id).Updates(hasilLab).Error
	if err == nil {
		hasilLab, err = r.GetByID(id)
	}
	return hasilLab, err
}

func (r *hasilLabRepository) Delete(id uint) error {
	return r.db.Delete(&models.HasilLab{}, id).Error
}