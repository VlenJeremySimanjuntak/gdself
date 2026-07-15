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
	GetKepatuhanByObatID(obatID uint) (int64, []string, error)
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
		Order("tgl_konsumsi DESC, id_log DESC").
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

func (r *logKonsumsiRepository) GetKepatuhanByObatID(obatID uint) (int64, []string, error) {
	var statDiminum int64
	err := r.db.Table("log_konsumsi_obat").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ? AND log_konsumsi_obat.status = ?", obatID, "Diminum").
		Count(&statDiminum).Error
	if err != nil {
		return 0, nil, err
	}

	type statusRow struct {
		Status string `gorm:"column:status"`
	}

	var rows []statusRow
	err = r.db.Table("log_konsumsi_obat").
		Select("log_konsumsi_obat.status").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ?", obatID).
		Order("log_konsumsi_obat.tgl_konsumsi DESC, log_konsumsi_obat.id_log DESC").
		Limit(3).
		Scan(&rows).Error
	if err != nil {
		return 0, nil, err
	}

	statusLog := make([]string, 3)
	for i, row := range rows {
		statusLog[i] = row.Status
	}

	return statDiminum, statusLog, nil
}
