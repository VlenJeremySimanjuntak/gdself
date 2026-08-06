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
	if len(input.Parameters) == 0 {
		return models.HasilLab{}, fmt.Errorf("minimal 1 parameter harus diisi")
	}

	var isTshHigh, isFt4High bool
	var hasTSH bool // ✅ TAMBAHAN: Untuk melacak apakah ada TSH di payload

	// ==========================================
	// BLOK VALIDASI SEBELUM SIMPAN KE DB
	// ==========================================
	for _, param := range input.Parameters {
		paramNameUpper := strings.ToUpper(strings.TrimSpace(param.NamaParameter))

		// ✅ TAMBAHAN: Tandai jika TSH atau TSHS ditemukan
		if paramNameUpper == "TSH" || paramNameUpper == "TSHS" {
			hasTSH = true
		}

		// Ambil nilai yang dikirim (bisa dari .Nilai atau .NilaiHasil)
		nilai := param.Nilai
		if nilai == nil {
			nilai = param.NilaiHasil
		}

		if nilai != nil {
			// ✅ ATURAN 2: PHYSIOLOGICAL ABSURDITY LIMITS (Tolak Mutlak, tidak peduli ForceSave)
			if (paramNameUpper == "TSH" || paramNameUpper == "TSHS") && *nilai < 0 {
				return models.HasilLab{}, fmt.Errorf("ABSURDITY_ERROR: Nilai %s tidak boleh negatif. Mohon periksa kembali input Anda.", paramNameUpper)
			}
			if paramNameUpper == "FT4" && *nilai > 77.2 {
				return models.HasilLab{}, fmt.Errorf("ABSURDITY_ERROR: Nilai FT4 melampaui rentang pengukuran alat immunoassay standar (> 77.2 pmol/L). Mohon periksa kembali satuan/nilai yang diinput.")
			}

			// ✅ ATURAN 1 & ANTI-TREMOR (Bisa di-bypass dengan ForceSave)
			if !input.ForceSave {
				// Deteksi TSH dan FT4 Tinggi untuk Uji Konsistensi
				if param.NilaiBatasAtas != nil && *param.NilaiBatasAtas > 0 {
					if (paramNameUpper == "TSH" || paramNameUpper == "TSHS") && *nilai > *param.NilaiBatasAtas {
						isTshHigh = true
					}
					if paramNameUpper == "FT4" && *nilai > *param.NilaiBatasAtas {
						isFt4High = true
					}

					// Cek nilai melompat jauh (> 10x batas atas)
					if *nilai > (*param.NilaiBatasAtas * 10.0) {
						return models.HasilLab{}, fmt.Errorf("TREMOR_WARNING: Nilai %s tampak sangat jauh dari batas rujukan atas. Mohon periksa kembali angka yang diketik.", param.NamaParameter)
					}
				}
			}
		}

		// ✅ PERBAIKAN: LOGIKA RENTANG (Tolak Mutlak, TIDAK BOLEH di-bypass oleh ForceSave)
		if param.NilaiBatasBawah != nil && param.NilaiBatasAtas != nil {
			bb := *param.NilaiBatasBawah
			ba := *param.NilaiBatasAtas

			if bb > 0 && ba > 0 {
				if bb > ba {
					// Batas bawah lebih besar dari batas atas (100% Error)
					return models.HasilLab{}, fmt.Errorf("Gagal! Rentang batas %s tidak valid (Batas Bawah %v > Batas Atas %v).", param.NamaParameter, bb, ba)
				}
				
				if bb == ba && paramNameUpper != "TRAB" {
					// Batas bawah sama dengan batas atas (Error kecuali TRAb)
					return models.HasilLab{}, fmt.Errorf("Gagal! Rentang batas %s tidak boleh sama (Batas Bawah == Batas Atas).", param.NamaParameter)
				}
			}
		}
	}

	// ✅ TAMBAHAN: Validasi Wajib TSH
	if !hasTSH {
		return models.HasilLab{}, fmt.Errorf("Data hasil lab minimal harus menyertakan parameter TSH atau TSHs")
	}

	// Evaluasi Uji Konsistensi (Tidak Boleh ForceSave)
	if !input.ForceSave && isTshHigh && isFt4High {
		return models.HasilLab{}, fmt.Errorf("CONSISTENCY_ERROR: TSH dan FT4 tercatat sama-sama tinggi. Secara fisiologis ini paradoks. Mohon periksa kembali sampel atau kemungkinan interferensi alat.")
	}

	// ==========================================
	// BLOK PROSES DATABASE
	// ==========================================
	tx := repositories.DB.Begin()
	if tx.Error != nil {
		return models.HasilLab{}, tx.Error
	}

	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// 1. Cek atau Buat LaporanLab
	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		if input.IDUser == 0 {
			tx.Rollback()
			return models.HasilLab{}, fmt.Errorf("id_user harus diisi untuk membuat laporan baru")
		}

		var targetDate models.CustomDate
		if input.TglPeriksa != nil {
			targetDate = *input.TglPeriksa
		} else {
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
			TglPeriksa: &targetDate,
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
		if nilai == nil {
			nilai = param.NilaiHasil
		}

		created := models.HasilLab{
			IDLaporanLab:          idLaporan,
			IDParameter:           masterParam.IDParameter,
			NilaiHasil:            nilai,
			NilaiBatasBawah:       param.NilaiBatasBawah,
			NilaiBatasAtas:        param.NilaiBatasAtas,
			MeasurementStatus:     param.MeasurementStatus,
			PhysicalConditionCode: param.PhysicalConditionCode,
			PhysicalConditionNote: param.PhysicalConditionNote,
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

	return u.repoHasilLab.GetByID(firstCreatedID)
}

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

	var nilai, batasAtas, batasBawah float64

	// Resolusi nilai untuk validasi (gabungan input baru dan data lama)
	if input.NilaiHasil != nil {
		nilai = *input.NilaiHasil
	} else if hasilLab.NilaiHasil != nil {
		nilai = *hasilLab.NilaiHasil
	}

	if input.NilaiBatasAtas != nil {
		batasAtas = *input.NilaiBatasAtas
	} else if hasilLab.NilaiBatasAtas != nil {
		batasAtas = *hasilLab.NilaiBatasAtas
	}

	if input.NilaiBatasBawah != nil {
		batasBawah = *input.NilaiBatasBawah
	} else if hasilLab.NilaiBatasBawah != nil {
		batasBawah = *hasilLab.NilaiBatasBawah
	}

	paramNameUpper := strings.ToUpper(strings.TrimSpace(hasilLab.Parameter.NamaParameter))

	// ✅ ATURAN 2: PHYSIOLOGICAL ABSURDITY LIMITS SAAT EDIT (Tolak Mutlak)
	if (paramNameUpper == "TSH" || paramNameUpper == "TSHS") && nilai < 0 {
		return models.HasilLab{}, fmt.Errorf("ABSURDITY_ERROR: Nilai %s tidak boleh negatif. Mohon periksa kembali input Anda.", paramNameUpper)
	}
	if paramNameUpper == "FT4" && nilai > 77.2 {
		return models.HasilLab{}, fmt.Errorf("ABSURDITY_ERROR: Nilai FT4 melampaui rentang pengukuran alat immunoassay standar (> 77.2 pmol/L). Mohon periksa kembali satuan/nilai yang diinput.")
	}

	if !input.ForceSave {
		// ✅ ATURAN 1: VALIDASI CONSISTENCY CHECK SAAT EDIT
		if batasAtas > 0 && nilai > batasAtas {
			if paramNameUpper == "TSH" || paramNameUpper == "TSHS" {
				siblingLabs, _ := u.repoHasilLab.GetByLaporanLabID(hasilLab.IDLaporanLab)
				for _, sib := range siblingLabs {
					if strings.ToUpper(strings.TrimSpace(sib.Parameter.NamaParameter)) == "FT4" && sib.NilaiBatasAtas != nil && sib.NilaiHasil != nil {
						if *sib.NilaiHasil > *sib.NilaiBatasAtas {
							return models.HasilLab{}, fmt.Errorf("CONSISTENCY_ERROR: Mengubah TSH menjadi setinggi ini bertentangan dengan nilai FT4 yang sudah tercatat tinggi di laporan yang sama.")
						}
					}
				}
			}

			if paramNameUpper == "FT4" {
				siblingLabs, _ := u.repoHasilLab.GetByLaporanLabID(hasilLab.IDLaporanLab)
				for _, sib := range siblingLabs {
					if (strings.ToUpper(strings.TrimSpace(sib.Parameter.NamaParameter)) == "TSH" || strings.ToUpper(strings.TrimSpace(sib.Parameter.NamaParameter)) == "TSHS") && sib.NilaiBatasAtas != nil && sib.NilaiHasil != nil {
						if *sib.NilaiHasil > *sib.NilaiBatasAtas {
							return models.HasilLab{}, fmt.Errorf("CONSISTENCY_ERROR: Mengubah FT4 menjadi setinggi ini bertentangan dengan nilai TSH yang sudah tercatat tinggi di laporan yang sama.")
						}
					}
				}
			}
		}

		// ✅ VALIDASI ANTI-TREMOR SAAT EDIT
		if batasAtas > 0 && nilai > (batasAtas*10.0) {
			return models.HasilLab{}, fmt.Errorf("TREMOR_WARNING: Nilai hasil tampak sangat jauh dari batas rujukan atas. Mohon periksa kembali angka yang diketik.")
		}

		if batasBawah > 0 && batasAtas > 0 && batasBawah >= batasAtas {
			if paramNameUpper == "TRAB" && batasBawah == batasAtas {
				// Loloskan
			} else {
				return models.HasilLab{}, fmt.Errorf("TREMOR_WARNING: Rentang batas terbalik atau sama (Batas Bawah >= Batas Atas).")
			}
		}
	}

	// Update record
	if input.NilaiHasil != nil {
		hasilLab.NilaiHasil = input.NilaiHasil
	}
	if input.NilaiBatasBawah != nil {
		hasilLab.NilaiBatasBawah = input.NilaiBatasBawah
	}
	if input.NilaiBatasAtas != nil {
		hasilLab.NilaiBatasAtas = input.NilaiBatasAtas
	}
	if input.MeasurementStatus != "" {
		hasilLab.MeasurementStatus = input.MeasurementStatus
	}
	if input.PhysicalConditionCode != "" {
		hasilLab.PhysicalConditionCode = input.PhysicalConditionCode
	}
	if input.PhysicalConditionNote != "" {
		hasilLab.PhysicalConditionNote = input.PhysicalConditionNote
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
