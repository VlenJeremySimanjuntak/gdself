package usecases

import (
	"fmt"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type ObatUsecase interface {
	CreateObat(obat models.Obat) (models.Obat, error)
	GetObatByID(id uint) (models.Obat, error)
	GetObatByUserID(userID uint) ([]models.Obat, error)
	GetAllObat() ([]models.Obat, error)
	UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error)
	DeleteObat(id uint) error
}

type obatUsecase struct {
	repo repositories.ObatRepository
}

func NewObatUsecase(repo repositories.ObatRepository) ObatUsecase {
	return &obatUsecase{repo: repo}
}

func (u *obatUsecase) CreateObat(obat models.Obat) (models.Obat, error) {
	if obat.IDUser == 0 || obat.NamaObat == "" {
		return models.Obat{}, fmt.Errorf("id_user dan nama_obat tidak boleh kosong")
	}

	return u.repo.Create(obat)
}

func (u *obatUsecase) GetObatByID(id uint) (models.Obat, error) {
	if id == 0 {
		return models.Obat{}, fmt.Errorf("id tidak valid")
	}

	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	return obat, nil
}

func (u *obatUsecase) GetObatByUserID(userID uint) ([]models.Obat, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}

	return u.repo.GetByUserID(userID)
}

func (u *obatUsecase) GetAllObat() ([]models.Obat, error) {
	return u.repo.GetAll()
}

func (u *obatUsecase) UpdateObat(id uint, input models.UpdateObatRequest) (models.Obat, error) {
	if id == 0 {
		return models.Obat{}, fmt.Errorf("id tidak valid")
	}

	// 1. Ambil data lama dari database
	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return models.Obat{}, fmt.Errorf("obat tidak ditemukan")
	}

	// 2. Update field yang ada di DTO (sesuaikan dengan struct UpdateObatRequest)
	if input.NamaObat != "" {
		obat.NamaObat = input.NamaObat
	}
	if input.Dosis != "" {
		obat.Dosis = input.Dosis
	}
	if input.Frekuensi != "" {
		obat.Frekuensi = input.Frekuensi
	}
	if input.TipeObat != "" {
		obat.TipeObat = input.TipeObat
	}
    
	// ✅ Karena TglMulai & TglSelesai di model adalah *CustomDate, 
    // kita bisa langsung assign dari input
	if input.TglMulai != nil {
		obat.TglMulai = input.TglMulai
	}
	if input.TglSelesai != nil {
		obat.TglSelesai = input.TglSelesai
	}

	// 3. Simpan kembali ke repository
	return u.repo.Update(id, obat)
}


func (u *obatUsecase) DeleteObat(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}

	// Check if obat exists
	obat, err := u.repo.GetByID(id)
	if err != nil || obat.IDObat == 0 {
		return fmt.Errorf("obat tidak ditemukan")
	}

	return u.repo.Delete(id)
}
