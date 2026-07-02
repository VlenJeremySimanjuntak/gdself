package usecases

import (
	"encoding/json"
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
	laporanRepo   repositories.LaporanLabRepository
}

func NewLabUsecase(
	r repositories.LabRepository,
	repoParam repositories.ParameterRepository,
	hasilAILab HasilAILabUsecase,
	hasilAITren HasilAITrenUsecase,
	laporanRepo repositories.LaporanLabRepository,
) LabUsecase {
	return &labUsecase{
		repo:          r,
		repoParameter: repoParam,
		hasilAILab:    hasilAILab,
		hasilAITren:   hasilAITren,
		laporanRepo:   laporanRepo,
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
	paramName := strings.TrimSpace(paramReq.NamaParameter)
	if paramName == "" {
		return models.HasilLab{}, fmt.Errorf("nama_parameter tidak boleh kosong")
	}

	masterParam, err := u.repoParameter.GetByNamaParameter(paramName)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
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

// ────────────────────────────────────────────────────────────────
// ✅ Helper baru: bedakan "Tidak Diketahui" (param sekarang gak ada)
// vs "Data Belum Cukup" (param sekarang ada, tapi belum ada pembanding lama)
// ────────────────────────────────────────────────────────────────
func resolveTrenStatus(prevHas, currHas bool, namaParam, currentTren, currentReminder string) (string, string) {
	if !currHas {
		// Parameter tidak diisi di laporan SEKARANG → memang tidak bisa dianalisis
		return "Tidak Diketahui", ""
	}
	if !prevHas {
		// Parameter baru pertama kali diperiksa → bukan error, cuma belum ada pembanding
		return "Data Belum Cukup", fmt.Sprintf(
			"Parameter %s baru pertama kali diperiksa. Tren akan muncul setelah pemeriksaan berikutnya.",
			namaParam,
		)
	}
	// Keduanya ada → biarkan hasil asli dari AnalyzeTren
	return currentTren, currentReminder
}

func (u *labUsecase) Assess(input models.AssessmentInput) (models.AssessmentResult, error) {
	var res models.AssessmentResult

	if !input.IsLabDay {
		res.Interpretation = "Assessment harian diproses saat sync wearable."
		return res, nil
	}

	// ── Validasi Lab Day ──────────────────────────────────────
	if len(input.Lab.Parameters) == 0 {
		return res, fmt.Errorf("minimal parameter TSHs harus diisi")
	}

	// FT4 opsional, hanya TSHs yang wajib.
	hasTSH := false
	for _, p := range input.Lab.Parameters {
		key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		if key == "TSH" || key == "TSHS" {
			hasTSH = true
			break
		}
	}
	if !hasTSH {
		return res, fmt.Errorf("parameter TSHs wajib diisi untuk analisis AI")
	}

	// ── OTOMATISASI PENCARIAN DATA TREN ──────────────
	if input.PrevLab == nil && input.Lab.IDLaporanLab != 0 {
		prevLabDB, err := u.laporanRepo.GetPreviousLab(input.Lab.IDLaporanLab)
		if err == nil && prevLabDB.IDLaporanLab != 0 {
			dbParams := []map[string]interface{}{}
			for _, h := range prevLabDB.HasilLab {
				dbParams = append(dbParams, map[string]interface{}{
					"nama_parameter":    h.Parameter.NamaParameter,
					"nilai_hasil":       h.NilaiHasil,
					"nilai_batas_bawah": h.NilaiBatasBawah,
					"nilai_batas_atas":  h.NilaiBatasAtas,
				})
			}
			paramBytes, _ := json.Marshal(map[string]interface{}{"parameters": dbParams})
			json.Unmarshal(paramBytes, &input.PrevLab)
		}
	}

	// ── Analisis AI Lab ──────────────────────────────────────────
	currResult := AnalyzeLabResults(input.Lab.Parameters)

	if u.hasilAILab != nil && input.Lab.IDLaporanLab != 0 {
		_, err := u.hasilAILab.UpsertFromAssessment(
			input.Lab.IDLaporanLab,
			input.Lab.Parameters,
		)
		if err != nil {
			fmt.Printf("Warning: gagal upsert hasil AI Lab: %v\n", err)
		}
	}

	// ── Logika AI Tren (Mesin 3) ─────────────────────────────────
	if input.PrevLab != nil && len(input.PrevLab.Parameters) > 0 &&
		u.hasilAITren != nil && input.Lab.IDLaporanLab != 0 {

		prevResult := AnalyzeLabResults(input.PrevLab.Parameters)
		trenResult := AnalyzeTren(prevResult, currResult)

		hasParam := func(params []models.AssessmentParamInput, target string) bool {
			for _, p := range params {
				key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
				if key == target || (target == "TSH" && key == "TSHS") {
					return true
				}
			}
			return false
		}

		// ✅ FIX: bedakan "Tidak Diketahui" vs "Data Belum Cukup"
		trenResult.TrenTSH, trenResult.ReminderTrenTSH = resolveTrenStatus(
			hasParam(input.PrevLab.Parameters, "TSH"),
			hasParam(input.Lab.Parameters, "TSH"),
			"TSHs", trenResult.TrenTSH, trenResult.ReminderTrenTSH,
		)
		trenResult.TrenFT3, trenResult.ReminderTrenFT3 = resolveTrenStatus(
			hasParam(input.PrevLab.Parameters, "FT3"),
			hasParam(input.Lab.Parameters, "FT3"),
			"FT3", trenResult.TrenFT3, trenResult.ReminderTrenFT3,
		)
		trenResult.TrenFT4, trenResult.ReminderTrenFT4 = resolveTrenStatus(
			hasParam(input.PrevLab.Parameters, "FT4"),
			hasParam(input.Lab.Parameters, "FT4"),
			"FT4", trenResult.TrenFT4, trenResult.ReminderTrenFT4,
		)
		trenResult.TrenTRAb, trenResult.ReminderTrenTRAb = resolveTrenStatus(
			hasParam(input.PrevLab.Parameters, "TRAB"),
			hasParam(input.Lab.Parameters, "TRAB"),
			"TRAb", trenResult.TrenTRAb, trenResult.ReminderTrenTRAb,
		)

		existingTren, _ := u.hasilAITren.GetHasilAITrenByLaporanLabID(input.Lab.IDLaporanLab)

		tren := models.HasilAITren{
			IDLaporanLab:     input.Lab.IDLaporanLab,
			TrenTsh:          trenResult.TrenTSH,
			ReminderTrenTsh:  trenResult.ReminderTrenTSH,
			TrenFt3:          trenResult.TrenFT3,
			ReminderTrenFt3:  trenResult.ReminderTrenFT3,
			TrenFt4:          trenResult.TrenFT4,
			ReminderTrenFt4:  trenResult.ReminderTrenFT4,
			TrenTrab:         trenResult.TrenTRAb,
			ReminderTrenTrab: trenResult.ReminderTrenTRAb,
		}

		if existingTren.IDHasilAITren != 0 {
			tren.IDHasilAITren = existingTren.IDHasilAITren
			_, err := u.hasilAITren.UpdateHasilAITren(tren)
			if err != nil {
				fmt.Printf("Warning: gagal update AI Tren: %v\n", err)
			}
		} else {
			_, err := u.hasilAITren.CreateHasilAITren(tren)
			if err != nil {
				fmt.Printf("Warning: gagal simpan AI Tren: %v\n", err)
			}
		}
	}

	res.Interpretation = currResult.Interpretasi
	return res, nil
}