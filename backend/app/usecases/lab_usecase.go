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

	if input.IsLabDay {
		// ✅ Mesin 1 atau 3 — proses lab parameters
		if len(input.Lab.Parameters) == 0 {
			return res, fmt.Errorf("parameters lab tidak boleh kosong untuk lab day")
		}

		aiLabResult := AnalyzeLabResults(input.Lab.Parameters)

		// Simpan ke hasil_ai_lab
		if u.hasilAILab != nil && input.Lab.IDLaporanLab != 0 {
			_, err := u.hasilAILab.CreateHasilAILab(models.HasilAILab{
				IDLaporanLab: input.Lab.IDLaporanLab,
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
				fmt.Printf("Warning: gagal simpan hasil AI Lab: %v\n", err)
			}
		}

		// ✅ Simpan tren jika ada prev_lab (Mesin 3)
		if input.PrevLab != nil && len(input.PrevLab.Parameters) > 0 && u.hasilAITren != nil && input.Lab.IDLaporanLab != 0 {
			prevResult := AnalyzeLabResults(input.PrevLab.Parameters)
			_, err := u.hasilAITren.CreateHasilAITren(models.HasilAITren{
				IDLaporanLab:     input.Lab.IDLaporanLab,
				TrenTsh:          compareTren(prevResult.StatusTSH, aiLabResult.StatusTSH),
				ReminderTrenTsh:  fmt.Sprintf("TSH: %s → %s", prevResult.StatusTSH, aiLabResult.StatusTSH),
				TrenFt3:          compareTren(prevResult.StatusFT3, aiLabResult.StatusFT3),
				ReminderTrenFt3:  fmt.Sprintf("FT3: %s → %s", prevResult.StatusFT3, aiLabResult.StatusFT3),
				TrenFt4:          compareTren(prevResult.StatusFT4, aiLabResult.StatusFT4),
				ReminderTrenFt4:  fmt.Sprintf("FT4: %s → %s", prevResult.StatusFT4, aiLabResult.StatusFT4),
				TrenTrab:         compareTren(prevResult.StatusTRAb, aiLabResult.StatusTRAb),
				ReminderTrenTrab: fmt.Sprintf("TRAb: %s → %s", prevResult.StatusTRAb, aiLabResult.StatusTRAb),
			})
			if err != nil {
				fmt.Printf("Warning: gagal simpan hasil AI Tren: %v\n", err)
			}
		}

		res.Interpretation = aiLabResult.Interpretasi

	} else {
		// Mesin 2 — wearable only, tidak diproses di sini
		// Wearable diproses otomatis saat POST /wearable
		res.Interpretation = "Assessment harian diproses saat sync wearable."
	}

	return res, nil
}

// Helper untuk bandingkan tren antar dua status
func compareTren(prev, curr string) string {
	if prev == curr {
		return "Stabil"
	}
	if curr == "Normal" {
		return "Membaik"
	}
	if prev == "Normal" {
		return "Memburuk"
	}
	return "Berubah"
}