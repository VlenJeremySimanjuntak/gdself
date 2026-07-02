package repositories

import (
	"monitoring-service/app/models"
	"gorm.io/gorm"
	"fmt"
)

type HasilAILabRepository interface {
	Create(lab models.HasilAILab) (models.HasilAILab, error)
	Upsert(lab models.HasilAILab) (models.HasilAILab, error)
	GetByID(id uint) (models.HasilAILab, error)
	GetByLaporanLabID(laporanLabID uint) (models.HasilAILab, error)
	GetLatestValidByUserAndParam(userID uint, statusColumn string) (models.HasilAILab, error)
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

// ✅ Jika sudah ada → UPDATE, jika belum → INSERT
func (r *hasilAILabRepository) Upsert(lab models.HasilAILab) (models.HasilAILab, error) {
	var existing models.HasilAILab
	err := r.db.Where("id_laporan_lab = ?", lab.IDLaporanLab).First(&existing).Error

	if err == nil {
		// Sudah ada → UPDATE
		existing.StatusTsh    = lab.StatusTsh
		existing.ReminderTsh  = lab.ReminderTsh
		existing.StatusFt3    = lab.StatusFt3
		existing.ReminderFt3  = lab.ReminderFt3
		existing.StatusFt4    = lab.StatusFt4
		existing.ReminderFt4  = lab.ReminderFt4
		existing.StatusTrab   = lab.StatusTrab
		existing.ReminderTrab = lab.ReminderTrab
		existing.Interpretasi = lab.Interpretasi
		existing.TglHasilAi   = lab.TglHasilAi

		err = r.db.Save(&existing).Error
		return existing, err
	}

	// Belum ada → INSERT
	err = r.db.Create(&lab).Error
	return lab, err
}

func (r *hasilAILabRepository) GetLatestValidByUserAndParam(userID uint, statusColumn string) (models.HasilAILab, error) {
	var result models.HasilAILab

	allowedColumns := map[string]bool{
		"status_tsh":  true,
		"status_ft3":  true,
		"status_ft4":  true,
		"status_trab": true,
	}
	if !allowedColumns[statusColumn] {
		return result, fmt.Errorf("kolom status tidak valid: %s", statusColumn)
	}

	err := r.db.
		Joins("JOIN laporan_lab ON laporan_lab.id_laporan_lab = hasil_ai_lab.id_laporan_lab").
		Joins("JOIN riwayat ON riwayat.id_riwayat = laporan_lab.id_riwayat").
		Where("riwayat.id_user = ? AND hasil_ai_lab."+statusColumn+" != ?", userID, "Tidak Diketahui").
		Order("laporan_lab.tgl_periksa DESC").
		First(&result).Error

	return result, err
}