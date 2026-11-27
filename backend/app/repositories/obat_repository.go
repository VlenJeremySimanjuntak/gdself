package repositories

import (
	"gorm.io/gorm"
	"log"
	"monitoring-service/app/models"
)

type ObatRepository interface {
	Create(obat models.Obat) (models.Obat, error)
	GetByID(id uint) (models.Obat, error)
	GetByUserID(userID uint) ([]models.Obat, error)
	GetAll() ([]models.Obat, error)
	Update(id uint, obat models.Obat) (models.Obat, error)
	Delete(id uint) error
	GetKepatuhanByID(obatID uint) (models.Obat, int64, []string, error)
}

type obatRepository struct {
	db *gorm.DB
}

func NewObatRepository(db *gorm.DB) ObatRepository {
	return &obatRepository{db: db}
}

func (r *obatRepository) Create(obat models.Obat) (models.Obat, error) {
	err := r.db.Create(&obat).Error
	return obat, err
}

func (r *obatRepository) GetByID(id uint) (models.Obat, error) {
	var obat models.Obat
	err := r.db.Preload("JadwalObat").First(&obat, id).Error
	return obat, err
}

func (r *obatRepository) GetByUserID(userID uint) ([]models.Obat, error) {
	var obat []models.Obat

	query := r.db.Where("id_user = ?", userID)
	log.Printf("🔍 [ObatRepo] Base query for userID=%d", userID)

	err := query.Preload("JadwalObat", func(db *gorm.DB) *gorm.DB {
		return db.Order("waktu_minum_obat ASC")
	}).Find(&obat).Error

	if err == nil {
		log.Printf("🔍 [ObatRepo] GetByUserID(%d): Found %d obat", userID, len(obat))
	} else {
		log.Printf("❌ [ObatRepo] GetByUserID(%d) error: %v", userID, err)
	}

	return obat, err
}

func (r *obatRepository) GetAll() ([]models.Obat, error) {
	var obat []models.Obat
	err := r.db.Preload("JadwalObat").Find(&obat).Error
	return obat, err
}

func (r *obatRepository) Update(id uint, obat models.Obat) (models.Obat, error) {
	updates := map[string]interface{}{
		"nama_obat":   obat.NamaObat,
		"dosis":       obat.Dosis,
		"frekuensi":   obat.Frekuensi,
		"tipe_obat":   obat.TipeObat,
		"tgl_selesai": obat.TglSelesai,
	}

	if obat.TglMulai != nil {
		updates["tgl_mulai"] = obat.TglMulai
	}

	err := r.db.Model(&models.Obat{}).Where("id_obat = ?", id).Updates(updates).Error
	if err == nil {
		obat, err = r.GetByID(id)
	}
	return obat, err
}

func (r *obatRepository) GetKepatuhanByID(obatID uint) (models.Obat, int64, []string, error) {
	obat, err := r.GetByID(obatID)
	if err != nil {
		return models.Obat{}, 0, nil, err
	}

	var statDiminum int64
	err = r.db.Table("log_konsumsi_obat").
		Joins("JOIN jadwal_obat ON jadwal_obat.id_jadwal_obat = log_konsumsi_obat.id_jadwal_obat").
		Where("jadwal_obat.id_obat = ? AND log_konsumsi_obat.status = ?", obatID, "Diminum").
		Count(&statDiminum).Error
	if err != nil {
		return models.Obat{}, 0, nil, err
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
		return models.Obat{}, 0, nil, err
	}

	statusLogs := make([]string, 3)
	for i, row := range rows {
		statusLogs[i] = row.Status
	}

	return obat, statDiminum, statusLogs, nil
}

func (r *obatRepository) Delete(id uint) error {
	return r.db.Delete(&models.Obat{}, id).Error
}
