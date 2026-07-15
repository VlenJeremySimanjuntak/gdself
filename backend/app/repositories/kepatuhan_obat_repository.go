package repositories

import (
	"regexp"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

type KepatuhanObatRepository interface {
	GetStatDiminum(obatID uint) (int, error)
	GetStatTotal(obatID uint, tglMulai time.Time, frekuensi string) (int, error)
	GetStatusLog(obatID uint) ([]string, error)
}

type kepatuhanObatRepository struct {
	db *gorm.DB
}

func NewKepatuhanObatRepository(db *gorm.DB) KepatuhanObatRepository {
	return &kepatuhanObatRepository{db: db}
}

func (r *kepatuhanObatRepository) GetStatDiminum(obatID uint) (int, error) {
	var statDiminum int64
	err := r.db.Table("log_konsumsi_obat").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ? AND log_konsumsi_obat.status = ?", obatID, "Diminum").
		Count(&statDiminum).Error
	if err != nil {
		return 0, err
	}

	return int(statDiminum), nil
}

func (r *kepatuhanObatRepository) GetStatTotal(obatID uint, tglMulai time.Time, frekuensi string) (int, error) {
	if tglMulai.IsZero() {
		return 0, nil
	}

	startDate := time.Date(tglMulai.Year(), tglMulai.Month(), tglMulai.Day(), 0, 0, 0, 0, time.Local)
	today := time.Now()
	todayDate := time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, time.Local)
	if todayDate.Before(startDate) {
		return 0, nil
	}

	days := int(todayDate.Sub(startDate).Hours()/24) + 1
	if days <= 0 {
		return 0, nil
	}

	frequency := parseDailyFrequency(frekuensi)
	if frequency <= 0 {
		frequency = 1
	}

	return days * frequency, nil
}

func (r *kepatuhanObatRepository) GetStatusLog(obatID uint) ([]string, error) {
	type statusRow struct {
		Status string `gorm:"column:status"`
	}

	var rows []statusRow
	err := r.db.Table("log_konsumsi_obat").
		Select("log_konsumsi_obat.status").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ?", obatID).
		Order("log_konsumsi_obat.tgl_konsumsi DESC, log_konsumsi_obat.id_log DESC").
		Limit(3).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}

	statusLog := make([]string, 3)
	for i := 0; i < len(rows); i++ {
		statusLog[2-i] = rows[i].Status
	}

	return statusLog, nil
}

func parseDailyFrequency(frekuensi string) int {
	frekuensi = strings.TrimSpace(strings.ToLower(frekuensi))
	if frekuensi == "" {
		return 1
	}

	re := regexp.MustCompile(`\d+`)
	match := re.FindString(frekuensi)
	if match == "" {
		return 1
	}

	nilai, err := strconv.Atoi(match)
	if err != nil || nilai <= 0 {
		return 1
	}

	return nilai
}
