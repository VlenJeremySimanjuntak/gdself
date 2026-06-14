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

	// Enable query logging untuk debug
	query := r.db.Where("id_user = ?", userID)
	log.Printf("🔍 [ObatRepo] Base query for userID=%d", userID)

	// Preload dengan explicit order
	err := query.Preload("JadwalObat", func(db *gorm.DB) *gorm.DB {
		return db.Order("waktu_minum_obat ASC")
	}).Find(&obat).Error

	if err == nil {
		log.Printf("🔍 [ObatRepo] GetByUserID(%d): Found %d obat", userID, len(obat))
		for i, o := range obat {
			log.Printf("  📋 Obat[%d]: %s (ID=%d) → %d jadwal", i, o.NamaObat, o.IDObat, len(o.JadwalObat))
			for j, j2 := range o.JadwalObat {
				log.Printf("    ⏰ Jadwal[%d]: ID=%d, waktu=%v", j, j2.IDJadwalObat, j2.WaktuMinumObat)
			}
		}

		// Double-check: Query jadwal_obat table directly
		var directJadwal []models.JadwalObat
		r.db.Find(&directJadwal)
		log.Printf("🔍 [ObatRepo] Direct query jadwal_obat table: %d total jadwal exist", len(directJadwal))

		// Explicit check: Query just for user ID 1's obat
		var testObat []models.Obat
		r.db.Where("id_user = ?", userID).Find(&testObat)
		log.Printf("🔍 [ObatRepo] Test: Direct query obat by user: %d obat found", len(testObat))

		// Manual preload check for first obat
		if len(obat) > 0 {
			var manualJadwal []models.JadwalObat
			r.db.Where("id_obat = ?", obat[0].IDObat).Find(&manualJadwal)
			log.Printf("🔍 [ObatRepo] Manual query for obat[0] (ID=%d): %d jadwal found", obat[0].IDObat, len(manualJadwal))
		}
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
	// Build updates map to ensure boolean false and zero-values are persisted correctly
	updates := map[string]interface{}{
		"nama_obat":     obat.NamaObat,
		"dosis":         obat.Dosis,
		"frekuensi":     obat.Frekuensi,
		"hari_konsumsi": obat.HariKonsumsi,
		"status_aktif":  obat.StatusAktif,
	}

	if obat.TanggalMulai != nil {
		updates["tanggal_mulai"] = obat.TanggalMulai
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
