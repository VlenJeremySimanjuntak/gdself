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

	// 1. Simpan Wearable
	if err := tx.Create(&wearable).Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, err
	}

	// 2. Analisis AI Harian & Simpan
	hasilAI := models.HasilAIHarian{
		IDWearable: wearable.IDWearable,
		TglHasilAi: wearable.TglData,
	}

	// Klasifikasi Detak Jantung
	if wearable.HeartRateHr > 0 {
		if wearable.HeartRateHr < 60 {
			hasilAI.StatusHr = "Rendah"
			hasilAI.ReminderHr = "Detak jantung Anda berada di bawah batas normal. Pastikan Anda cukup istirahat dan konsultasikan dengan dokter jika merasa pusing atau lemas."
		} else if wearable.HeartRateHr <= 100 {
			hasilAI.StatusHr = "Normal"
			hasilAI.ReminderHr = "Detak jantung Anda dalam kondisi baik. Pertahankan aktivitas fisik yang teratur."
		} else {
			hasilAI.StatusHr = "Tinggi"
			hasilAI.ReminderHr = "Detak jantung Anda cukup tinggi. Kurangi aktivitas berat sementara waktu dan cobalah untuk rileks."
		}
	} else {
		hasilAI.StatusHr = "Tidak Ada Data"
	}

	// Klasifikasi Tidur
	if wearable.SleepDuration > 0 {
		if wearable.SleepDuration < 420 { // < 7 jam
			hasilAI.StatusTidur = "Kurang"
			hasilAI.ReminderTidur = "Total waktu tidur Anda kurang dari 7 jam. Kurang tidur dapat menurunkan kekebalan tubuh. Usahakan tidur lebih awal malam ini."
		} else if wearable.SleepDuration <= 540 { // 7-9 jam
			hasilAI.StatusTidur = "Normal"
			hasilAI.ReminderTidur = "Pola tidur Anda sudah sangat baik (7-9 jam). Kualitas tidur yang baik membantu pemulihan tubuh."
		} else { // > 9 jam
			hasilAI.StatusTidur = "Berlebih"
			hasilAI.ReminderTidur = "Anda tidur lebih dari 9 jam. Pastikan Anda tidak terlalu lelah dan jaga rutinitas agar tubuh tetap bugar."
		}
	} else {
		hasilAI.StatusTidur = "Tidak Ada Data"
	}

	// Klasifikasi Tekanan Darah
	if wearable.Sistolik > 0 && wearable.Diastolik > 0 {
		if wearable.Sistolik < 120 && wearable.Diastolik < 80 {
			hasilAI.StatusTd = "Normal"
			hasilAI.ReminderTd = "Tekanan darah Anda berada pada batas normal. Pertahankan pola makan sehat dan asupan cairan yang cukup."
		} else {
			hasilAI.StatusTd = "Tinggi"
			hasilAI.ReminderTd = "Tekanan darah Anda menunjukkan angka tinggi. Kurangi asupan garam, kelola stres, dan periksakan ke dokter jika berlanjut."
		}
	} else {
		hasilAI.StatusTd = "Tidak Ada Data"
		hasilAI.ReminderTd = "-"
	}

	// Simpan Hasil AI Harian
	if err := tx.Create(&hasilAI).Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, fmt.Errorf("gagal menyimpan hasil AI: %v", err)
	}

	if err := tx.Commit().Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, err
	}

	return u.repo.GetByID(wearable.IDWearable)
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