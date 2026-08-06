package usecases

import (
	"fmt"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"
)

type LaporanLabUsecase interface {
	CreateLaporanLab(laporan models.LaporanLab, idUser uint) (models.LaporanLab, error)
	GetLaporanLabByID(id uint) (models.LaporanLab, error)
	GetAllLaporanLab() ([]models.LaporanLab, error)
	GetLaporanLabByUserID(userID uint) ([]models.LaporanLab, error)
	UpdateLaporanLab(id uint, input models.UpdateLaporanLabRequest) (models.LaporanLab, error)
	DeleteLaporanLab(id uint) error
}

type laporanLabUsecase struct {
	repo        repositories.LaporanLabRepository
	riwayatRepo repositories.RiwayatRepository
}

func NewLaporanLabUsecase(
	repo repositories.LaporanLabRepository,
	riwayatRepo repositories.RiwayatRepository,
) LaporanLabUsecase {
	return &laporanLabUsecase{
		repo:        repo,
		riwayatRepo: riwayatRepo,
	}
}

func (u *laporanLabUsecase) GetLaporanLabByUserID(userID uint) ([]models.LaporanLab, error) {
	if userID == 0 {
		return nil, fmt.Errorf("user_id tidak valid")
	}
	return u.repo.GetByUserID(userID)
}

func (u *laporanLabUsecase) CreateLaporanLab(laporan models.LaporanLab, idUser uint) (models.LaporanLab, error) {
	if laporan.NamaLab == "" {
		return models.LaporanLab{}, fmt.Errorf("nama_lab tidak boleh kosong")
	}

	if laporan.IDRiwayat != 0 {
		// 1. Ambil data Riwayat dari database berdasarkan IDRiwayat
		existingRiwayat, err := u.riwayatRepo.GetByID(laporan.IDRiwayat) 
		if err != nil || existingRiwayat.IDRiwayat == 0 {
			return models.LaporanLab{}, fmt.Errorf("id_riwayat tidak valid atau tidak ditemukan")
		}

		// 2. Cek apakah Riwayat ini benar milik idUser yang request
		if existingRiwayat.IDUser != idUser {
			// Pesan yang lebih tegas, menembak langsung ke masalah relasi
			return models.LaporanLab{}, fmt.Errorf("akses ditolak: id_riwayat %d tidak terdaftar atas id_user %d", laporan.IDRiwayat, idUser)
		}

	} else {
		// =========================================================
		// LOGIKA LAMA: Jika IDRiwayat == 0 (Kosong)
		// =========================================================
		if idUser == 0 {
			return models.LaporanLab{}, fmt.Errorf("id_user atau id_riwayat harus diisi")
		}

		today := models.CustomDate(time.Now())
		existing, err := u.riwayatRepo.GetByUserIDAndDate(idUser, today)
		
		if err == nil && existing.IDRiwayat != 0 {
			laporan.IDRiwayat = existing.IDRiwayat
		} else {
			newRiwayat := models.Riwayat{
				IDUser:  idUser,
				Tanggal: &today,
			}
			created, err := u.riwayatRepo.Create(newRiwayat)
			if err != nil {
				return models.LaporanLab{}, fmt.Errorf("gagal membuat riwayat: %w", err)
			}
			laporan.IDRiwayat = created.IDRiwayat
		}
	}

	return u.repo.Create(laporan)
}

func (u *laporanLabUsecase) GetLaporanLabByID(id uint) (models.LaporanLab, error) {
	if id == 0 {
		return models.LaporanLab{}, fmt.Errorf("id tidak valid")
	}
	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("laporan lab tidak ditemukan")
	}
	return laporan, nil
}

func (u *laporanLabUsecase) GetAllLaporanLab() ([]models.LaporanLab, error) {
	return u.repo.GetAll()
}

func (u *laporanLabUsecase) UpdateLaporanLab(id uint, input models.UpdateLaporanLabRequest) (models.LaporanLab, error) {
	if id == 0 {
		return models.LaporanLab{}, fmt.Errorf("id tidak valid")
	}
	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("laporan lab tidak ditemukan")
	}
	if input.NamaLab != "" {
		laporan.NamaLab = input.NamaLab
	}
	if input.TglPeriksa != nil {
		laporan.TglPeriksa = input.TglPeriksa
	}
	return u.repo.Update(id, laporan)
}

func (u *laporanLabUsecase) DeleteLaporanLab(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}
	laporan, err := u.repo.GetByID(id)
	if err != nil || laporan.IDLaporanLab == 0 {
		return fmt.Errorf("laporan lab tidak ditemukan")
	}
	return u.repo.Delete(id)
}