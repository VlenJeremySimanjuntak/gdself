package repositories

import (
	"log"
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type JadwalObatRepository interface {
	Create(jadwalObat models.JadwalObat) (models.JadwalObat, error)
	GetByID(id uint) (models.JadwalObat, error)
	GetByObatID(obatID uint) ([]models.JadwalObat, error)
	GetAll() ([]models.JadwalObat, error)
	Update(id uint, jadwalObat models.JadwalObat) (models.JadwalObat, error)
	Delete(id uint) error
}

type jadwalObatRepository struct {
	db *gorm.DB
}

func NewJadwalObatRepository(db *gorm.DB) JadwalObatRepository {
	return &jadwalObatRepository{db: db}
}

func (r *jadwalObatRepository) Create(jadwalObat models.JadwalObat) (models.JadwalObat, error) {
	err := r.db.Create(&jadwalObat).Error
	if err == nil {
		log.Printf("✅ [JadwalObatRepo] Created jadwal ID=%d, idObat=%d, waktu=%v", jadwalObat.IDJadwalObat, jadwalObat.IDObat, jadwalObat.WaktuMinumObat)
	} else {
		log.Printf("❌ [JadwalObatRepo] Create error: %v", err)
	}
	return jadwalObat, err
}

func (r *jadwalObatRepository) GetByID(id uint) (models.JadwalObat, error) {
	var jadwalObat models.JadwalObat
	err := r.db.First(&jadwalObat, id).Error
	return jadwalObat, err
}

func (r *jadwalObatRepository) GetByObatID(obatID uint) ([]models.JadwalObat, error) {
	var jadwalObat []models.JadwalObat
	err := r.db.Where("id_obat = ?", obatID).Order("waktu_minum_obat ASC").Find(&jadwalObat).Error
	if err == nil {
		log.Printf("🔍 [JadwalObatRepo] GetByObatID(%d): Found %d jadwal", obatID, len(jadwalObat))
		for i, j := range jadwalObat {
			log.Printf("  ⏰ Jadwal[%d]: ID=%d, waktu=%v", i, j.IDJadwalObat, j.WaktuMinumObat)
		}
	} else {
		log.Printf("❌ [JadwalObatRepo] GetByObatID(%d) error: %v", obatID, err)
	}
	return jadwalObat, err
}

func (r *jadwalObatRepository) GetAll() ([]models.JadwalObat, error) {
	var jadwalObat []models.JadwalObat
	err := r.db.Find(&jadwalObat).Error
	return jadwalObat, err
}

func (r *jadwalObatRepository) Update(id uint, jadwalObat models.JadwalObat) (models.JadwalObat, error) {
	err := r.db.Model(&models.JadwalObat{}).Where("id_jadwal_obat = ?", id).Updates(jadwalObat).Error
	if err == nil {
		jadwalObat, err = r.GetByID(id)
	}
	return jadwalObat, err
}

func (r *jadwalObatRepository) Delete(id uint) error {
	return r.db.Delete(&models.JadwalObat{}, id).Error
}
