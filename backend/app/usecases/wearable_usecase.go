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

	if err := tx.Create(&wearable).Error; err != nil {
		tx.Rollback()
		return models.Wearable{}, err
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

	// ✅ Update yang 100% patuh pada struktur UpdateWearableRequest
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