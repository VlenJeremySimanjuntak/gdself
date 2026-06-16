package usecases

import (
	"fmt"
	"strings"

	"monitoring-service/app/models"
	"monitoring-service/app/repositories"

	"gorm.io/gorm"
)

type LabUsecase interface {
	SaveLabResult(input models.CreateHasilLabRequest) (models.HasilLab, error)
	GetAllLabResults() ([]models.HasilLab, error)
	GetLabResultsByUserID(userID uint) ([]models.HasilLab, error)
	Assess(input models.AssessmentInput) (models.AssessmentResult, error)
}

type labUsecase struct {
	repo          repositories.LabRepository
	repoParameter repositories.ParameterRepository
	hasilAILab    HasilAILabUsecase
	hasilAITren   HasilAITrenUsecase
}

func NewLabUsecase(
	r repositories.LabRepository,
	repoParam repositories.ParameterRepository,
	hasilAILab HasilAILabUsecase,
	hasilAITren HasilAITrenUsecase,
) LabUsecase {
	return &labUsecase{
		repo:          r,
		repoParameter: repoParam,
		hasilAILab:    hasilAILab,
		hasilAITren:   hasilAITren,
	}
}

func (u *labUsecase) SaveLabResult(input models.CreateHasilLabRequest) (models.HasilLab, error) {
	if (input.IDLaporanLab == 0 && input.IDReport == 0) || input.IDRiwayat == 0 {
		return models.HasilLab{}, fmt.Errorf("id_laporan_lab dan id_riwayat wajib diisi")
	}
	if len(input.Parameters) == 0 {
		return models.HasilLab{}, fmt.Errorf("minimal 1 parameter harus diisi")
	}

	idLaporan := input.IDLaporanLab
	if idLaporan == 0 {
		idLaporan = input.IDReport
	}

	paramReq := input.Parameters[0]
	paramName := strings.TrimSpace(paramReq.NamaParameter) // ✅ Menggunakan strings (Menghapus UnusedImport)
	if paramName == "" {
		return models.HasilLab{}, fmt.Errorf("nama_parameter tidak boleh kosong")
	}

	masterParam, err := u.repoParameter.GetByNamaParameter(paramName)
	if err != nil {
		if err == gorm.ErrRecordNotFound { // ✅ Menggunakan gorm (Menghapus UnusedImport)
			masterParam, err = u.repoParameter.Create(models.Parameter{
				NamaParameter: strings.ToUpper(paramName),
				Satuan:        paramReq.Satuan,
				Kategori:      paramReq.Kategori,
			})
			if err != nil {
				return models.HasilLab{}, err
			}
		} else {
			return models.HasilLab{}, err
		}
	}

	hasilLab := models.HasilLab{
		IDLaporanLab:    idLaporan,
		IDRiwayat:       input.IDRiwayat,
		IDParameter:     masterParam.IDParameter,
		NilaiHasil:      paramReq.NilaiHasil,
		NilaiBatasBawah: paramReq.NilaiBatasBawah,
		NilaiBatasAtas:  paramReq.NilaiBatasAtas,
	}

	return u.repo.Create(hasilLab)
}

func (u *labUsecase) GetAllLabResults() ([]models.HasilLab, error) {
	return u.repo.GetAll()
}

func (u *labUsecase) GetLabResultsByUserID(userID uint) ([]models.HasilLab, error) {
	return u.repo.GetByUserID(userID)
}

func (u *labUsecase) Assess(input models.AssessmentInput) (models.AssessmentResult, error) {
	var res models.AssessmentResult

	// 1. Panggil rule-based logic dari lab_rules.go
	aiLabResult := AnalyzeLabResults(input.Lab.Parameters)

	// 2. Simpan Hasil AI Lab ke database dengan penamaan field PascalCase sesuai model Anda
	if u.hasilAILab != nil && input.Lab.IDLaporanLab != 0 {
		_, err := u.hasilAILab.CreateHasilAILab(models.HasilAILab{
			IDLaporanLab: input.Lab.IDLaporanLab,
			
			// ✅ Sesuai dengan struct HasilAILab milik Anda (StatusTsh, ReminderTsh, dll.)
			StatusTsh:    aiLabResult.StatusTSH,
			ReminderTsh:  aiLabResult.ReminderTSH,
			StatusFt3:    aiLabResult.StatusFT3,
			ReminderFt3:  aiLabResult.ReminderFT3,
			StatusFt4:    aiLabResult.StatusFT4,
			ReminderFt4:  aiLabResult.ReminderFT4,
			StatusTrab:   aiLabResult.StatusTRAb,
			ReminderTrab: aiLabResult.ReminderTRAb,
			Interpretasi: aiLabResult.Interpretasi,
		})
		if err != nil {
			fmt.Printf("Warning: failed to save AI Lab assessment result: %v\n", err)
		}
	}

	res.Interpretation = aiLabResult.Interpretasi
	return res, nil
}