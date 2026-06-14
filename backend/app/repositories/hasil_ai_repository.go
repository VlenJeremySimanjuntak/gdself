package repositories

import (
	"monitoring-service/app/models"

	"gorm.io/gorm"
)

type HasilAIRepository interface {
	Create(hasilAI models.HasilAI) (models.HasilAI, error)
	GetByID(id uint) (models.HasilAI, error)
	GetByRiwayatID(riwayatID uint) ([]models.HasilAI, error)
	GetByWearableID(wearableID uint) ([]models.HasilAI, error)
	GetByHasilLabID(hasilLabID uint) ([]models.HasilAI, error)
	GetAll() ([]models.HasilAI, error)
	Update(id uint, hasilAI models.HasilAI) (models.HasilAI, error)
	Delete(id uint) error
}

type hasilAIRepository struct {
	db *gorm.DB
}

func NewHasilAIRepository(db *gorm.DB) HasilAIRepository {
	return &hasilAIRepository{db: db}
}

func (r *hasilAIRepository) Create(hasilAI models.HasilAI) (models.HasilAI, error) {
	// Decide target table based on presence of fields
	// If StatusHarian or PesanHarian present -> hasil_ai_harian
	if hasilAI.StatusHarian != "" || hasilAI.PesanHarian != "" {
		// require IDWearable and IDRiwayat
		if hasilAI.IDWearable == nil || hasilAI.IDRiwayat == nil {
			return hasilAI, gorm.ErrInvalidData
		}
		h := models.HasilAIHarian{
			IDWearable:   *hasilAI.IDWearable,
			IDRiwayat:    *hasilAI.IDRiwayat,
			TglHasilAI:   hasilAI.TglHasilAI,
			Score:        hasilAI.Score,
			StatusHarian: hasilAI.StatusHarian,
			PesanHarian:  hasilAI.PesanHarian,
		}
		if err := r.db.Create(&h).Error; err != nil {
			return hasilAI, err
		}
		hasilAI.IDHasilAI = h.IDHasilAIHarian
		hasilAI.CreatedAt = h.CreatedAt
		return hasilAI, nil
	}

	// Otherwise treat as gabungan
	h2 := models.HasilAIGabungan{
		IDHasilLab:    hasilAI.IDHasilLab,
		IDRiwayat:     0,
		IDWearable:    hasilAI.IDWearable,
		KesimpulanLab: hasilAI.KesimpulanLab,
		TrendReport:   hasilAI.TrendReport,
		ArahPerubahan: hasilAI.ArahPerubahan,
		TglHasilAI:    hasilAI.TglHasilAI,
		Score:         hasilAI.Score,
		IsRead:        hasilAI.IsRead,
	}
	if hasilAI.IDRiwayat != nil {
		h2.IDRiwayat = *hasilAI.IDRiwayat
	}
	if err := r.db.Create(&h2).Error; err != nil {
		return hasilAI, err
	}
	hasilAI.IDHasilAI = h2.IDHasilAILab
	hasilAI.CreatedAt = h2.CreatedAt
	return hasilAI, nil
}

func (r *hasilAIRepository) GetByID(id uint) (models.HasilAI, error) {
	var res models.HasilAI
	// Try harian
	var h1 models.HasilAIHarian
	if err := r.db.Preload("Riwayat").Preload("Wearable").Where("id_hasil_ai_harian = ?", id).First(&h1).Error; err == nil {
		res.IDHasilAI = h1.IDHasilAIHarian
		res.IDWearable = &h1.IDWearable
		res.IDRiwayat = &h1.IDRiwayat
		res.TglHasilAI = h1.TglHasilAI
		res.Score = h1.Score
		res.StatusHarian = h1.StatusHarian
		res.PesanHarian = h1.PesanHarian
		res.CreatedAt = h1.CreatedAt
		res.Riwayat = h1.Riwayat
		res.Wearable = h1.Wearable
		return res, nil
	}
	// Try gabungan
	var h2 models.HasilAIGabungan
	if err := r.db.Preload("Riwayat").Preload("Wearable").Preload("HasilLab.Parameter").Where("id_hasil_ai_lab = ?", id).First(&h2).Error; err == nil {
		res.IDHasilAI = h2.IDHasilAILab
		res.IDHasilLab = h2.IDHasilLab
		res.IDRiwayat = &h2.IDRiwayat
		res.IDWearable = h2.IDWearable
		res.KesimpulanLab = h2.KesimpulanLab
		res.TrendReport = h2.TrendReport
		res.ArahPerubahan = h2.ArahPerubahan
		res.TglHasilAI = h2.TglHasilAI
		res.Score = h2.Score
		res.IsRead = h2.IsRead
		res.CreatedAt = h2.CreatedAt
		res.Riwayat = h2.Riwayat
		res.Wearable = h2.Wearable
		res.HasilLab = h2.HasilLab
		return res, nil
	}
	return models.HasilAI{}, gorm.ErrRecordNotFound
}

func (r *hasilAIRepository) GetByRiwayatID(riwayatID uint) ([]models.HasilAI, error) {
	var out []models.HasilAI
	var h1 []models.HasilAIHarian
	if err := r.db.Where("id_riwayat = ?", riwayatID).Preload("Riwayat").Preload("Wearable").Order("tgl_hasil_ai DESC").Find(&h1).Error; err == nil {
		for _, hh := range h1 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAIHarian
			rcv.IDWearable = &hh.IDWearable
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.StatusHarian = hh.StatusHarian
			rcv.PesanHarian = hh.PesanHarian
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			out = append(out, rcv)
		}
	}
	var h2 []models.HasilAIGabungan
	if err := r.db.Where("id_riwayat = ?", riwayatID).Preload("Riwayat").Preload("Wearable").Preload("HasilLab.Parameter").Order("tgl_hasil_ai DESC").Find(&h2).Error; err == nil {
		for _, hh := range h2 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAILab
			rcv.IDHasilLab = hh.IDHasilLab
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.IDWearable = hh.IDWearable
			rcv.KesimpulanLab = hh.KesimpulanLab
			rcv.TrendReport = hh.TrendReport
			rcv.ArahPerubahan = hh.ArahPerubahan
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.IsRead = hh.IsRead
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			rcv.HasilLab = hh.HasilLab
			out = append(out, rcv)
		}
	}
	return out, nil
}

func (r *hasilAIRepository) GetByWearableID(wearableID uint) ([]models.HasilAI, error) {
	var out []models.HasilAI
	var h1 []models.HasilAIHarian
	if err := r.db.Where("id_wearable = ?", wearableID).Preload("Riwayat").Preload("Wearable").Order("tgl_hasil_ai DESC").Find(&h1).Error; err == nil {
		for _, hh := range h1 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAIHarian
			rcv.IDWearable = &hh.IDWearable
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.StatusHarian = hh.StatusHarian
			rcv.PesanHarian = hh.PesanHarian
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			out = append(out, rcv)
		}
	}
	var h2 []models.HasilAIGabungan
	if err := r.db.Where("id_wearable = ?", wearableID).Preload("Riwayat").Preload("Wearable").Preload("HasilLab.Parameter").Order("tgl_hasil_ai DESC").Find(&h2).Error; err == nil {
		for _, hh := range h2 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAILab
			rcv.IDHasilLab = hh.IDHasilLab
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.IDWearable = hh.IDWearable
			rcv.KesimpulanLab = hh.KesimpulanLab
			rcv.TrendReport = hh.TrendReport
			rcv.ArahPerubahan = hh.ArahPerubahan
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.IsRead = hh.IsRead
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			rcv.HasilLab = hh.HasilLab
			out = append(out, rcv)
		}
	}
	return out, nil
}

func (r *hasilAIRepository) GetByHasilLabID(hasilLabID uint) ([]models.HasilAI, error) {
	var out []models.HasilAI
	var h2 []models.HasilAIGabungan
	if err := r.db.Where("id_hasil_lab = ?", hasilLabID).Preload("Riwayat").Preload("Wearable").Preload("HasilLab.Parameter").Order("tgl_hasil_ai DESC").Find(&h2).Error; err == nil {
		for _, hh := range h2 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAILab
			rcv.IDHasilLab = hh.IDHasilLab
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.IDWearable = hh.IDWearable
			rcv.KesimpulanLab = hh.KesimpulanLab
			rcv.TrendReport = hh.TrendReport
			rcv.ArahPerubahan = hh.ArahPerubahan
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.IsRead = hh.IsRead
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			rcv.HasilLab = hh.HasilLab
			out = append(out, rcv)
		}
	}
	return out, nil
}

func (r *hasilAIRepository) GetAll() ([]models.HasilAI, error) {
	var out []models.HasilAI
	var h1 []models.HasilAIHarian
	if err := r.db.Preload("Riwayat").Preload("Wearable").Order("created_at DESC").Find(&h1).Error; err == nil {
		for _, hh := range h1 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAIHarian
			rcv.IDWearable = &hh.IDWearable
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.StatusHarian = hh.StatusHarian
			rcv.PesanHarian = hh.PesanHarian
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			out = append(out, rcv)
		}
	}
	var h2 []models.HasilAIGabungan
	if err := r.db.Preload("Riwayat").Preload("Wearable").Preload("HasilLab.Parameter").Order("created_at DESC").Find(&h2).Error; err == nil {
		for _, hh := range h2 {
			var rcv models.HasilAI
			rcv.IDHasilAI = hh.IDHasilAILab
			rcv.IDHasilLab = hh.IDHasilLab
			rcv.IDRiwayat = &hh.IDRiwayat
			rcv.IDWearable = hh.IDWearable
			rcv.KesimpulanLab = hh.KesimpulanLab
			rcv.TrendReport = hh.TrendReport
			rcv.ArahPerubahan = hh.ArahPerubahan
			rcv.TglHasilAI = hh.TglHasilAI
			rcv.Score = hh.Score
			rcv.IsRead = hh.IsRead
			rcv.CreatedAt = hh.CreatedAt
			rcv.Riwayat = hh.Riwayat
			rcv.Wearable = hh.Wearable
			rcv.HasilLab = hh.HasilLab
			out = append(out, rcv)
		}
	}
	return out, nil
}

func (r *hasilAIRepository) Update(id uint, hasilAI models.HasilAI) (models.HasilAI, error) {
	// Try update harian
	if err := r.db.Model(&models.HasilAIHarian{}).Where("id_hasil_ai_harian = ?", id).Updates(map[string]interface{}{
		"score":         hasilAI.Score,
		"status_harian": hasilAI.StatusHarian,
		"pesan_harian":  hasilAI.PesanHarian,
		"is_read":       hasilAI.IsRead,
	}).Error; err == nil {
		// return refreshed
		return r.GetByID(id)
	}
	// Otherwise update gabungan
	if err := r.db.Model(&models.HasilAIGabungan{}).Where("id_hasil_ai_lab = ?", id).Updates(map[string]interface{}{
		"score":          hasilAI.Score,
		"kesimpulan_lab": hasilAI.KesimpulanLab,
		"trend_report":   hasilAI.TrendReport,
		"arah_perubahan": hasilAI.ArahPerubahan,
		"is_read":        hasilAI.IsRead,
	}).Error; err == nil {
		return r.GetByID(id)
	}
	return models.HasilAI{}, gorm.ErrRecordNotFound
}

func (r *hasilAIRepository) Delete(id uint) error {
	if err := r.db.Delete(&models.HasilAIHarian{}, "id_hasil_ai_harian = ?", id).Error; err == nil {
		return nil
	}
	if err := r.db.Delete(&models.HasilAIGabungan{}, "id_hasil_ai_lab = ?", id).Error; err == nil {
		return nil
	}
	return gorm.ErrRecordNotFound
}
