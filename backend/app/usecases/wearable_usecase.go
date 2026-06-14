package usecases

import (
	"fmt"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type WearableUsecase interface {
	CreateWearable(userID uint, wearable models.WearableRecord) (models.WearableRecord, error)
	GetWearableByID(id uint) (models.WearableRecord, error)
	GetWearableByRiwayatID(riwayatID uint) ([]models.WearableRecord, error)
	GetWearableByUserID(userID uint) ([]models.WearableRecord, error)
	GetAllWearable() ([]models.WearableRecord, error)
	UpdateWearable(id uint, input models.UpdateWearableRequest) (models.WearableRecord, error)
	DeleteWearable(id uint) error
}

type wearableUsecase struct {
	repo repositories.WearableRepository
}

func NewWearableUsecase(repo repositories.WearableRepository) WearableUsecase {
	return &wearableUsecase{repo: repo}
}

func (u *wearableUsecase) CreateWearable(userID uint, wearable models.WearableRecord) (models.WearableRecord, error) {
	if userID == 0 {
		return models.WearableRecord{}, fmt.Errorf("id_user tidak boleh kosong")
	}

	// Start DB transaction
	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return models.WearableRecord{}, tx.Error
	}

	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Find existing riwayat by (id_user, tanggal)
	var riwayat models.Riwayat
	err := tx.Where("id_user = ? AND tanggal = ?", userID, wearable.TglData).First(&riwayat).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// create new riwayat
			riwayat = models.Riwayat{
				IDUser:  userID,
				Tanggal: wearable.TglData,
			}
			if errCreate := tx.Create(&riwayat).Error; errCreate != nil {
				tx.Rollback()
				return models.WearableRecord{}, fmt.Errorf("gagal membuat riwayat: %v", errCreate)
			}
		} else {
			tx.Rollback()
			return models.WearableRecord{}, err
		}
	}

	// Assign found/created riwayat ID
	wearable.IDRiwayat = riwayat.IDRiwayat

	// Insert wearable record using tx
	if err := tx.Create(&wearable).Error; err != nil {
		tx.Rollback()
		return models.WearableRecord{}, err
	}

	if err := tx.Commit().Error; err != nil {
		tx.Rollback()
		return models.WearableRecord{}, err
	}

	// Return created wearable (use repository to fetch full relations)
	return u.repo.GetByID(wearable.IDWearable)
}

func (u *wearableUsecase) GetWearableByID(id uint) (models.WearableRecord, error) {
	if id == 0 {
		return models.WearableRecord{}, fmt.Errorf("id tidak valid")
	}

	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return models.WearableRecord{}, fmt.Errorf("data wearable tidak ditemukan")
	}

	return wearable, nil
}

func (u *wearableUsecase) GetWearableByRiwayatID(riwayatID uint) ([]models.WearableRecord, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}

	return u.repo.GetByRiwayatID(riwayatID)
}

func (u *wearableUsecase) GetWearableByUserID(userID uint) ([]models.WearableRecord, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *wearableUsecase) GetAllWearable() ([]models.WearableRecord, error) {
	return u.repo.GetAll()
}

func (u *wearableUsecase) UpdateWearable(id uint, input models.UpdateWearableRequest) (models.WearableRecord, error) {
	if id == 0 {
		return models.WearableRecord{}, fmt.Errorf("id tidak valid")
	}

	// Get existing wearable
	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return models.WearableRecord{}, fmt.Errorf("data wearable tidak ditemukan")
	}

	// Update only non-empty fields
	if input.TglData != nil {
		wearable.TglData = input.TglData
	}
	if input.WaktuData != nil {
		wearable.WaktuData = input.WaktuData
	}
	if input.HeartRateRHR != 0 {
		wearable.HeartRateRHR = input.HeartRateRHR
	}
	if input.StressScore != 0 {
		wearable.StressScore = input.StressScore
	}
	if input.SleepDuration != 0 {
		wearable.SleepDuration = input.SleepDuration
	}

	return u.repo.Update(id, wearable)
}

func (u *wearableUsecase) DeleteWearable(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if wearable exists
	wearable, err := u.repo.GetByID(id)
	if err != nil || wearable.IDWearable == 0 {
		return fmt.Errorf("data wearable tidak ditemukan")
	}

	return u.repo.Delete(id)
}
