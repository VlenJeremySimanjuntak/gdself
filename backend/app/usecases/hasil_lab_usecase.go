package usecases

import (
	"fmt"
	"strings"
	"time"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type HasilLabUsecase interface {
	CreateHasilLab(input models.CreateHasilLabRequest) (models.HasilLab, error)
	GetHasilLabByID(id uint) (models.HasilLab, error)
	GetHasilLabByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error)
	GetHasilLabByRiwayatID(riwayatID uint) ([]models.HasilLab, error)
	GetHasilLabByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error)
	GetLaporanByUserAndDate(userID uint, date string) (models.LaporanLab, error)
	GetAllHasilLab() ([]models.HasilLab, error)
	UpdateHasilLab(id uint, input models.UpdateHasilLabRequest) (models.HasilLab, error)
	DeleteHasilLab(id uint) error
}

type hasilLabUsecase struct {
	repoHasilLab   repositories.HasilLabRepository
	repoParameter  repositories.ParameterRepository
	repoLaporanLab repositories.LaporanLabRepository
	repoWearable   repositories.WearableRepository
	hasilAILab     HasilAILabUsecase
	hasilAITren    HasilAITrenUsecase
}

func NewHasilLabUsecase(
	repoHasilLab repositories.HasilLabRepository,
	repoParameter repositories.ParameterRepository,
	repoLaporan repositories.LaporanLabRepository,
	repoWearable repositories.WearableRepository,
	hasilAILab HasilAILabUsecase,
	hasilAITren HasilAITrenUsecase,
) HasilLabUsecase {
	return &hasilLabUsecase{
		repoHasilLab:   repoHasilLab,
		repoParameter:  repoParameter,
		repoLaporanLab: repoLaporan,
		repoWearable:   repoWearable,
		hasilAILab:     hasilAILab,
		hasilAITren:    hasilAITren,
	}
}

func (u *hasilLabUsecase) CreateHasilLab(input models.CreateHasilLabRequest) (models.HasilLab, error) {
	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return models.HasilLab{}, tx.Error
	}

	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	if len(input.Parameters) == 0 {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("minimal 1 parameter harus diisi")
	}

	// 1. Cek atau Buat LaporanLab
	idLaporan := input.IDLaporanLab

	if idLaporan == 0 {
		if input.IDUser == 0 {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("id_user harus diisi untuk membuat laporan baru")
		}

		// ✅ PERBAIKAN: Gunakan tanggal dari input Flutter jika ada!
		var targetDate models.CustomDate
		if input.TglPeriksa != nil {
			targetDate = *input.TglPeriksa
		} else {
			// Fallback ke hari ini HANYA jika Flutter tidak mengirimkan tanggal
			now := time.Now()
			dateOnly := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
			targetDate = models.CustomDate(dateOnly)
		}

		var riwayat models.Riwayat
		if err := tx.Where("id_user = ? AND tanggal = ?", input.IDUser, targetDate).First(&riwayat).Error; err != nil {
			if err == gorm.ErrRecordNotFound {
				riwayat = models.Riwayat{
					IDUser:  input.IDUser,
					Tanggal: &targetDate,
				}
				if err := tx.Create(&riwayat).Error; err != nil {
					tx.Rollback()
					return models.HasilLab{}, fmt.Errorf("gagal membuat riwayat: %v", err)
				}
			} else {
				tx.Rollback()
				return models.HasilLab{}, err
			}
		}

		if input.NamaLab == "" {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nama_lab harus diisi ketika membuat laporan baru")
		}

		laporan := models.LaporanLab{
			IDRiwayat:  riwayat.IDRiwayat,
			NamaLab:    input.NamaLab,
			TglPeriksa: &targetDate, // ✅ Sekarang menyimpan 2025 sesuai pilihan user!
		}
		if err := tx.Create(&laporan).Error; err != nil {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("gagal membuat laporan lab: %v", err)
		}
		idLaporan = laporan.IDLaporanLab
	}

	var firstCreatedID uint

	// 2. Insert Hasil Lab per parameter
	for _, param := range input.Parameters {
		paramName := strings.TrimSpace(param.NamaParameter)
		if paramName == "" {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nama_parameter tidak boleh kosong")
		}

		var masterParam models.Parameter
		err := tx.Where("LOWER(nama_parameter) = LOWER(?)", paramName).First(&masterParam).Error
		if err != nil {
			if err == gorm.ErrRecordNotFound {
				masterParam = models.Parameter{
					NamaParameter: strings.ToUpper(paramName),
					Satuan:        param.Satuan,
					Kategori:      param.Kategori,
				}
				if err := tx.Create(&masterParam).Error; err != nil {
					tx.Rollback()
					return models.HasilLab{}, fmt.Errorf("gagal membuat master parameter %s: %v", paramName, err)
				}
			} else {
				tx.Rollback()
				return models.HasilLab{}, err
			}
		}

		nilai := param.Nilai
		if nilai == 0 {
			nilai = param.NilaiHasil
		}
		if nilai == 0 {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("nilai untuk parameter %s harus diisi", paramName)
		}

		created := models.HasilLab{
			IDLaporanLab:    idLaporan,
			IDParameter:     masterParam.IDParameter,
			NilaiHasil:      nilai,
			NilaiBatasBawah: param.NilaiBatasBawah,
			NilaiBatasAtas:  param.NilaiBatasAtas,
		}

		if err := tx.Create(&created).Error; err != nil {
			tx.Rollback()
			return models.HasilLab{}, err
		}

		if firstCreatedID == 0 {
			firstCreatedID = created.IDHasilLab
		}
	}

	if firstCreatedID == 0 {
		tx.Rollback()
		return models.HasilLab{}, fmt.Errorf("gagal membuat hasil lab")
	}

	if err := tx.Commit().Error; err != nil {
		tx.Rollback()
		return models.HasilLab{}, err
	}

	// 3. Konversi CreateParameterRequest ke AssessmentParamInput lalu jalankan AI async
	assessParams := make([]models.AssessmentParamInput, 0, len(input.Parameters))
	for _, p := range input.Parameters {
		nilai := p.Nilai
		if nilai == 0 {
			nilai = p.NilaiHasil
		}
		assessParams = append(assessParams, models.AssessmentParamInput{
			NamaParameter:   p.NamaParameter,
			NilaiHasil:      nilai,
			NilaiBatasBawah: p.NilaiBatasBawah,
			NilaiBatasAtas:  p.NilaiBatasAtas,
		})
	}

	return u.repoHasilLab.GetByID(firstCreatedID)
}

// ── Sisanya tidak berubah ────────────────────────────────────────────────────

func (u *hasilLabUsecase) GetHasilLabByID(id uint) (models.HasilLab, error) {
	if id == 0 {
		return models.HasilLab{}, fmt.Errorf("id tidak valid")
	}
	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return models.HasilLab{}, fmt.Errorf("hasil lab tidak ditemukan")
	}
	return hasilLab, nil
}

func (u *hasilLabUsecase) GetHasilLabByLaporanLabID(laporanLabID uint) ([]models.HasilLab, error) {
	if laporanLabID == 0 {
		return nil, fmt.Errorf("laporan_lab_id tidak valid")
	}
	return u.repoHasilLab.GetByLaporanLabID(laporanLabID)
}

func (u *hasilLabUsecase) GetHasilLabByRiwayatID(riwayatID uint) ([]models.HasilLab, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}
	return u.repoHasilLab.GetByRiwayatID(riwayatID)
}

func (u *hasilLabUsecase) GetHasilLabByRiwayatIDAndDate(riwayatID uint, date string) ([]models.HasilLab, error) {
	if riwayatID == 0 {
		return nil, fmt.Errorf("riwayat_id tidak valid")
	}
	if strings.TrimSpace(date) == "" {
		return nil, fmt.Errorf("tanggal tidak valid")
	}
	return u.repoHasilLab.GetByRiwayatIDAndDate(riwayatID, date)
}

func (u *hasilLabUsecase) GetLaporanByUserAndDate(userID uint, date string) (models.LaporanLab, error) {
	if userID == 0 {
		return models.LaporanLab{}, fmt.Errorf("user_id tidak valid")
	}
	if strings.TrimSpace(date) == "" {
		return models.LaporanLab{}, fmt.Errorf("tanggal tidak valid")
	}
	laporan, err := u.repoLaporanLab.GetByUserIDAndDate(userID, date)
	if err != nil {
		return models.LaporanLab{}, fmt.Errorf("data tidak ditemukan")
	}
	if laporan.IDLaporanLab == 0 {
		return models.LaporanLab{}, fmt.Errorf("data tidak ditemukan")
	}
	return laporan, nil
}

func (u *hasilLabUsecase) GetAllHasilLab() ([]models.HasilLab, error) {
	return u.repoHasilLab.GetAll()
}

func (u *hasilLabUsecase) UpdateHasilLab(id uint, input models.UpdateHasilLabRequest) (models.HasilLab, error) {
	if id == 0 {
		return models.HasilLab{}, fmt.Errorf("id tidak valid")
	}
	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return models.HasilLab{}, fmt.Errorf("hasil lab tidak ditemukan")
	}
	if input.NilaiHasil != 0 {
		hasilLab.NilaiHasil = input.NilaiHasil
	}
	if input.NilaiBatasBawah != 0 {
		hasilLab.NilaiBatasBawah = input.NilaiBatasBawah
	}
	if input.NilaiBatasAtas != 0 {
		hasilLab.NilaiBatasAtas = input.NilaiBatasAtas
	}
	return u.repoHasilLab.Update(id, hasilLab)
}

func (u *hasilLabUsecase) DeleteHasilLab(id uint) error {
	if id == 0 {
		return fmt.Errorf("id tidak valid")
	}
	hasilLab, err := u.repoHasilLab.GetByID(id)
	if err != nil || hasilLab.IDHasilLab == 0 {
		return fmt.Errorf("hasil lab tidak ditemukan")
	}
	return u.repoHasilLab.Delete(id)
}