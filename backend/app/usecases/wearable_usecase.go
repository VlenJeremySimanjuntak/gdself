package usecases

import (
	"fmt"
	"time" // ✅ Tambahkan package time untuk konversi format tanggal

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type WearableUsecase interface {
	CreateWearable(userID uint, wearable models.Wearable) (models.Wearable, error)
	GetWearableByID(id uint) (models.Wearable, error)
	GetWearableByRiwayatID(riwayatID uint) ([]models.Wearable, error)
	GetWearableByUserID(userID uint) ([]models.Wearable, error)
	GetAllWearable() ([]models.Wearable, error)
	UpdateWearable(id uint, input models.UpdateWearableRequest) (models.Wearable, error)
	DeleteWearable(id uint) error
}

type wearableUsecase struct {
	repo repositories.WearableRepository
}

func NewWearableUsecase(repo repositories.WearableRepository) WearableUsecase {
	return &wearableUsecase{repo: repo}
}

func (u *wearableUsecase) CreateWearable(userID uint, wearable models.Wearable) (models.Wearable, error) {
	if userID == 0 {
		return models.Wearable{}, fmt.Errorf("id_user tidak boleh kosong")
	}

	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return models.Wearable{}, tx.Error
	}

	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// ✅ PERBAIKAN: Ambil string tanggal dari TglData untuk menghindari isu timezone
	tglStr := ""
	if wearable.TglData != nil {
		tglStr = time.Time(*wearable.TglData).Format("2006-01-02")
	}

	// 1. Cari atau buat riwayat
	var riwayat models.Riwayat
	err := tx.Where("id_user = ? AND DATE(tanggal) = ?", userID, tglStr).First(&riwayat).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			riwayat = models.Riwayat{
				IDUser:  userID,
				Tanggal: wearable.TglData,
			}
			if errCreate := tx.Create(&riwayat).Error; errCreate != nil {
				tx.Rollback()
				return models.Wearable{}, fmt.Errorf("gagal membuat riwayat: %v", errCreate)
			}
		} else {
			tx.Rollback()
			return models.Wearable{}, err
		}
	}

	wearable.IDRiwayat = riwayat.IDRiwayat

	// ✅ 2. CEK apakah data wearable hari ini sudah ada (berdasarkan id_riwayat)
	var existing models.Wearable
	errCek := tx.Where("id_riwayat = ? AND waktu_data = ?", riwayat.IDRiwayat, wearable.WaktuData).First(&existing).Error

	if errCek == nil {
		// ✅ Sudah ada di jam yang sama — UPDATE saja, jangan insert baru (mencegah spam data saat buka tutup app)
		existing.HeartRateHr   = wearable.HeartRateHr
		existing.SleepDuration = wearable.SleepDuration
		existing.Sistolik      = wearable.Sistolik
		existing.Diastolik     = wearable.Diastolik

		if err := tx.Save(&existing).Error; err != nil {
			tx.Rollback()
			return models.Wearable{}, fmt.Errorf("gagal update wearable: %v", err)
		}

		// ✅ Update juga HasilAIHarian yang sudah ada
		if err := u.updateOrCreateHasilAI(tx, existing); err != nil {
			tx.Rollback()
			return models.Wearable{}, err
		}

		if err := tx.Commit().Error; err != nil {
			tx.Rollback()
			return models.Wearable{}, err
		}

		return u.repo.GetByID(existing.IDWearable)
	}

	// ✅ Belum ada di jam tersebut (Ada data baru dari smartwatch!) — INSERT baru
	if err := tx.Create(&wearable).Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, err
	}

	if err := u.updateOrCreateHasilAI(tx, wearable); err != nil {
		tx.Rollback()
		return models.Wearable{}, err
	}

	if err := tx.Commit().Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, err
	}

	return u.repo.GetByID(wearable.IDWearable)
}

func (u *wearableUsecase) updateOrCreateHasilAI(tx *gorm.DB, wearable models.Wearable) error {
	var existingAI models.HasilAIHarian
	isUpdate := tx.Where("id_wearable = ?", wearable.IDWearable).First(&existingAI).Error == nil

	hasilAI := existingAI
	if !isUpdate {
		hasilAI = models.HasilAIHarian{
			IDWearable: wearable.IDWearable,
			TglHasilAi: wearable.TglData,
		}
	}

	// -------------------------------------------------------------
	// Tabel 4.20 Aturan Analisis Detak Jantung
	// -------------------------------------------------------------
	if wearable.HeartRateHr > 0 {
		if wearable.HeartRateHr < 60 {
			hasilAI.StatusHr = "Rendah"
			hasilAI.ReminderHr = "Detak jantung berada di bawah kondisi normal. Disarankan istirahat cukup dan pemantauan ulang."
		} else if wearable.HeartRateHr <= 100 {
			hasilAI.StatusHr = "Normal"
			hasilAI.ReminderHr = "Detak jantung berada dalam kondisi normal. Pertahankan aktivitas dan pola hidup sehat."
		} else {
			hasilAI.StatusHr = "Tinggi"
			hasilAI.ReminderHr = "Detak jantung berada di atas kondisi normal. Disarankan mengurangi aktivitas berat dan melakukan pemantauan berkala."
		}
	} else {
		hasilAI.StatusHr = "Tidak Ada Data"
		hasilAI.ReminderHr = "-"
	}

	// -------------------------------------------------------------
	// Tabel 4.22 Aturan Analisis Durasi Tidur
	// -------------------------------------------------------------
	if wearable.SleepDuration > 0 {
		if wearable.SleepDuration < 420 { // < 7 jam
			hasilAI.StatusTidur = "Kurang"
			hasilAI.ReminderTidur = "Durasi tidur kurang dari kondisi ideal. Disarankan menambah waktu istirahat."
		} else if wearable.SleepDuration <= 540 { // 7 - 9 jam
			hasilAI.StatusTidur = "Normal"
			hasilAI.ReminderTidur = "Durasi tidur berada dalam kondisi ideal. Pertahankan pola tidur yang teratur."
		} else { // > 9 jam
			hasilAI.StatusTidur = "Berlebih"
			hasilAI.ReminderTidur = "Durasi tidur melebihi kondisi ideal. Disarankan menjaga keseimbangan pola tidur."
		}
	} else {
		hasilAI.StatusTidur = "Tidak Ada Data"
		hasilAI.ReminderTidur = "-"
	}

	// -------------------------------------------------------------
	// Tabel 4.21 Aturan Analisis Tekanan Darah
	// -------------------------------------------------------------
	if wearable.Sistolik > 0 && wearable.Diastolik > 0 {
		if wearable.Sistolik >= 130 || wearable.Diastolik > 80 {
			hasilAI.StatusTd = "Tinggi"
			hasilAI.ReminderTd = "Tekanan darah berada di atas batas normal. Disarankan pengurangan asupan garam dan pemantauan berkala."
		} else if wearable.Sistolik < 90 || wearable.Diastolik < 60 {
			hasilAI.StatusTd = "Rendah"
			hasilAI.ReminderTd = "Tekanan darah bera 	da di bawah batas normal. Disarankan untuk memantau kondisi fisik."
		} else {
			hasilAI.StatusTd = "Normal"
			hasilAI.ReminderTd = "Tekanan darah berada dalam kondisi normal. Pertahankan pola hidup sehat."
		}
	} else {
		hasilAI.StatusTd = "Tidak Ada Data"
		hasilAI.ReminderTd = "-"
	}

	if isUpdate {
		return tx.Save(&hasilAI).Error
	}
	return tx.Create(&hasilAI).Error
}

func (u *wearableUsecase) GetWearableByID(id uint) (models.Wearable, error) {
	if id == 0 {
		return models.Wearable{}, fmt.Errorf("id tidak valid")
	}

	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return models.Wearable{}, fmt.Errorf("data wearable tidak ditemukan")
	}

	return wearable, nil
}

func (u *wearableUsecase) GetWearableByRiwayatID(riwayatID uint) ([]models.Wearable, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}

	return u.repo.GetByRiwayatID(riwayatID)
}

func (u *wearableUsecase) GetWearableByUserID(userID uint) ([]models.Wearable, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *wearableUsecase) GetAllWearable() ([]models.Wearable, error) {
	return u.repo.GetAll()
}

func (u *wearableUsecase) UpdateWearable(id uint, input models.UpdateWearableRequest) (models.Wearable, error) {
	if id == 0 {
		return models.Wearable{}, fmt.Errorf("id tidak valid")
	}

	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return models.Wearable{}, fmt.Errorf("data wearable tidak ditemukan")
	}

	// ✅ Update field termasuk Sistolik & Diastolik
	if input.TglData != nil {
		wearable.TglData = input.TglData
	}
	if input.WaktuData != nil {
		wearable.WaktuData = input.WaktuData
	}
	if input.HeartRateHr != 0 {
		wearable.HeartRateHr = input.HeartRateHr
	}
	if input.SleepDuration != 0 {
		wearable.SleepDuration = input.SleepDuration
	}
	if input.Sistolik != 0 {
		wearable.Sistolik = input.Sistolik
	}
	if input.Diastolik != 0 {
		wearable.Diastolik = input.Diastolik
	}

	return u.repo.Update(id, wearable)
}

func (u *wearableUsecase) DeleteWearable(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return fmt.Errorf("data wearable tidak ditemukan")
	}

	return u.repo.Delete(id)
}