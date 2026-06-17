package repositories

import (
	"monitoring-service/app/models"
	"gorm.io/gorm"
)

type LogKonsumsiRepository interface {
	Create(log models.LogKonsumsiObat) (models.LogKonsumsiObat, error)
	GetByID(id uint) (models.LogKonsumsiObat, error)
	GetByJadwalID(jadwalID uint) ([]models.LogKonsumsiObat, error)
	GetByJadwalIDAndDate(jadwalID uint, tgl models.CustomDate) (models.LogKonsumsiObat, error)
	Update(id uint, log models.LogKonsumsiObat) (models.LogKonsumsiObat, error)
	Delete(id uint) error
}

type logKonsumsiRepository struct {
	db *gorm.DB
}

func NewLogKonsumsiRepository(db *gorm.DB) LogKonsumsiRepository {
	return &logKonsumsiRepository{db: db}
}

func (r *logKonsumsiRepository) Create(log models.LogKonsumsiObat) (models.LogKonsumsiObat, error) {
	err := r.db.Create(&log).Error
	return log, err
}

func (r *logKonsumsiRepository) GetByID(id uint) (models.LogKonsumsiObat, error) {
	var log models.LogKonsumsiObat
	err := r.db.Preload("JadwalObat").First(&log, id).Error
	return log, err
}

func (r *logKonsumsiRepository) GetByJadwalID(jadwalID uint) ([]models.LogKonsumsiObat, error) {
	var logs []models.LogKonsumsiObat
	err := r.db.Where("id_jadwal_obat = ?", jadwalID).
		Order("tgl_konsumsi DESC").
		Find(&logs).Error
	return logs, err
}

func (r *logKonsumsiRepository) GetByJadwalIDAndDate(jadwalID uint, tgl models.CustomDate) (models.LogKonsumsiObat, error) {
	var log models.LogKonsumsiObat
	err := r.db.Where("id_jadwal_obat = ? AND tgl_konsumsi = ?", jadwalID, tgl).
		First(&log).Error
	return log, err
}

func (r *logKonsumsiRepository) Update(id uint, log models.LogKonsumsiObat) (models.LogKonsumsiObat, error) {
	err := r.db.Model(&models.LogKonsumsiObat{}).
		Where("id_log = ?", id).
		Updates(log).Error
	if err == nil {
		log, err = r.GetByID(id)
	}
	return log, err
}

func (r *logKonsumsiRepository) Delete(id uint) error {
	return r.db.Delete(&models.LogKonsumsiObat{}, id).Error
}