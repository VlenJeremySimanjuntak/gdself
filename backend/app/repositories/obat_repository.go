package repositories

import (
	"log"
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type ObatRepository interface {
	Create(obat models.Obat) (models.Obat, error)
	GetByID(id uint) (models.Obat, error)
	GetByUserID(userID uint) ([]models.Obat, error)
	GetAll() ([]models.Obat, error)
	Update(id uint, obat models.Obat) (models.Obat, error)
	Delete(id uint) error
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
	// ✅ BARU: Build updates map menyesuaikan dengan ERD terbaru
	updates := map[string]interface{}{
		"nama_obat": obat.NamaObat,
		"dosis":     obat.Dosis,
		"frekuensi": obat.Frekuensi,
		"tipe_obat": obat.TipeObat,
	}

	if obat.TglMulai != nil {
		updates["tgl_mulai"] = obat.TglMulai
	}
	if obat.TglSelesai != nil {
		updates["tgl_selesai"] = obat.TglSelesai
	}

	err := r.db.Model(&models.Obat{}).Where("id_obat = ?", id).Updates(updates).Error
	if err == nil {
		obat, err = r.GetByID(id)
	}
	return obat, err
}

func (r *obatRepository) Delete(id uint) error {
	return r.db.Delete(&models.Obat{}, id).Error
}