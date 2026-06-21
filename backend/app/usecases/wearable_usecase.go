package usecases

import (
	"fmt"

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

    // 1. Cari atau buat riwayat
    var riwayat models.Riwayat
    err := tx.Where("id_user = ? AND tanggal = ?", userID, wearable.TglData).First(&riwayat).Error
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
    errCek := tx.Where("id_riwayat = ?", riwayat.IDRiwayat).First(&existing).Error

    if errCek == nil {
        // ✅ Sudah ada — UPDATE saja, jangan insert baru
        existing.WaktuData     = wearable.WaktuData
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

    // ✅ Belum ada — INSERT baru
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

// ✅ Fungsi pembantu analisis AI (pisahkan agar tidak duplikat kode)
func (u *wearableUsecase) updateOrCreateHasilAI(tx *gorm.DB, wearable models.Wearable) error {
    // Cek apakah hasil AI sudah ada untuk wearable ini
    var existingAI models.HasilAIHarian
    isUpdate := tx.Where("id_wearable = ?", wearable.IDWearable).First(&existingAI).Error == nil

    hasilAI := existingAI // pakai yang existing jika ada
    if !isUpdate {
        hasilAI = models.HasilAIHarian{
            IDWearable: wearable.IDWearable,
            TglHasilAi: wearable.TglData,
        }
    }

    // Analisis HR
    if wearable.HeartRateHr > 0 {
        if wearable.HeartRateHr < 60 {
            hasilAI.StatusHr = "Rendah"
            hasilAI.ReminderHr = "Detak jantung berada di bawah kondisi normal. Disarankan istirahat cukup dan pemantauan ulang."
        } else if wearable.HeartRateHr <= 100 {
            hasilAI.StatusHr = "Normal"
            hasilAI.ReminderHr = "Detak jantung berada dalam kondisi normal. Pertahankan aktivitas dan pola hidup sehat."
        } else {
            hasilAI.StatusHr = "Tinggi"
            hasilAI.ReminderHr = "Detak jantung berada di atas kondisi normal. Disarankan mengurangi aktivitas berat dan pemantauan berkala."
        }
    } else {
        hasilAI.StatusHr = "Tidak Ada Data"
        hasilAI.ReminderHr = "-"
    }

    // Analisis Tidur
    if wearable.SleepDuration > 0 {
        if wearable.SleepDuration < 420 {
            hasilAI.StatusTidur = "Kurang"
            hasilAI.ReminderTidur = "Durasi tidur kurang dari kondisi ideal. Disarankan menambah waktu istirahat."
        } else if wearable.SleepDuration <= 540 {
            hasilAI.StatusTidur = "Normal"
            hasilAI.ReminderTidur = "Durasi tidur berada dalam kondisi ideal. Pertahankan pola tidur yang teratur."
        } else {
            hasilAI.StatusTidur = "Berlebih"
            hasilAI.ReminderTidur = "Durasi tidur melebihi kondisi ideal. Disarankan menjaga keseimbangan pola tidur."
        }
    } else {
        hasilAI.StatusTidur = "Tidak Ada Data"
        hasilAI.ReminderTidur = "-"
    }

    // Analisis Tekanan Darah
    if wearable.Sistolik > 0 && wearable.Diastolik > 0 {
        if wearable.Sistolik < 120 && wearable.Diastolik < 80 {
            hasilAI.StatusTd = "Normal"
            hasilAI.ReminderTd = "Tekanan darah berada dalam kondisi normal. Pertahankan pola hidup sehat."
        } else {
            hasilAI.StatusTd = "Tinggi"
            hasilAI.ReminderTd = "Tekanan darah berada di atas batas normal. Disarankan pengurangan asupan garam dan pemantauan berkala."
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