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
	laporanRepo   repositories.LaporanLabRepository // ✅ TAMBAHAN: Untuk mengakses GetPreviousLab
}

func NewLabUsecase(
	r repositories.LabRepository,
	repoParam repositories.ParameterRepository,
	hasilAILab HasilAILabUsecase,
	hasilAITren HasilAITrenUsecase,
	laporanRepo repositories.LaporanLabRepository, // ✅ TAMBAHAN DI CONSTRUCTOR
) LabUsecase {
	return &labUsecase{
		repo:          r,
		repoParameter: repoParam,
		hasilAILab:    hasilAILab,
		hasilAITren:   hasilAITren,
		laporanRepo:   laporanRepo, // ✅ INIT
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

func (u *labUsecase) Assess(input models.AssessmentInput) (models.AssessmentResult, error) {
	var res models.AssessmentResult

	if !input.IsLabDay {
		res.Interpretation = "Assessment harian diproses saat sync wearable."
		return res, nil
	}

	// ── Validasi Lab Day ──────────────────────────────────────
	if len(input.Lab.Parameters) == 0 {
		return res, fmt.Errorf("minimal parameter TSH dan FT4 harus diisi")
	}

	hasTSH, hasFT4 := false, false
	for _, p := range input.Lab.Parameters {
		key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		if key == "TSH" || key == "TSHS" { hasTSH = true }
		if key == "FT4" { hasFT4 = true }
	}
	if !hasTSH || !hasFT4 {
		return res, fmt.Errorf("parameter TSH dan FT4 wajib diisi")
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
	
	// Simpan AI Lab jika belum ada
	existingLab, _ := u.hasilAILab.GetHasilAILabByLaporanLabID(input.Lab.IDLaporanLab)
	if existingLab.IDHasilAILab == 0 && u.hasilAILab != nil {
		_, _ = u.hasilAILab.CreateHasilAILab(models.HasilAILab{
			IDLaporanLab: input.Lab.IDLaporanLab,
			StatusTsh:    currResult.StatusTSH, ReminderTsh: currResult.ReminderTSH,
			StatusFt3:    currResult.StatusFT3, ReminderFt3: currResult.ReminderFT3,
			StatusFt4:    currResult.StatusFT4, ReminderFt4: currResult.ReminderFT4,
			StatusTrab:   currResult.StatusTRAb, ReminderTrab: currResult.ReminderTRAb,
			Interpretasi: currResult.Interpretasi,
		})
	}

	// ── Logika AI Tren (Mesin 3) ─────────────────────────────────
	if input.PrevLab != nil && len(input.PrevLab.Parameters) > 0 && u.hasilAITren != nil && input.Lab.IDLaporanLab != 0 {
		
		existingTren, _ := u.hasilAITren.GetHasilAITrenByLaporanLabID(input.Lab.IDLaporanLab)
		if existingTren.IDHasilAITren == 0 {
			prevResult := AnalyzeLabResults(input.PrevLab.Parameters)
			trenResult := AnalyzeTren(prevResult, currResult)

			// ✅ Fungsi pembantu untuk cek eksistensi hormon
			hasParam := func(params []models.AssessmentParamInput, target string) bool {
				for _, p := range params {
					key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
					if key == target || (target == "TSH" && key == "TSHS") {
						return true
					}
				}
				return false
			}

			// ✅ Pencekalan Tren: Jika hormon tidak ada di data sebelumnya, set Tidak Diketahui
			if !hasParam(input.PrevLab.Parameters, "TSH") {
				trenResult.TrenTSH = "Tidak Diketahui"; trenResult.ReminderTrenTSH = ""
			}
			if !hasParam(input.PrevLab.Parameters, "FT3") {
				trenResult.TrenFT3 = "Tidak Diketahui"; trenResult.ReminderTrenFT3 = ""
			}
			if !hasParam(input.PrevLab.Parameters, "FT4") {
				trenResult.TrenFT4 = "Tidak Diketahui"; trenResult.ReminderTrenFT4 = ""
			}
			if !hasParam(input.PrevLab.Parameters, "TRAB") {
				trenResult.TrenTRAb = "Tidak Diketahui"; trenResult.ReminderTrenTRAb = ""
			}

			// Simpan Tren ke Database
			_, err := u.hasilAITren.CreateHasilAITren(models.HasilAITren{
				IDLaporanLab:     input.Lab.IDLaporanLab,
				TrenTsh:          trenResult.TrenTSH,
				ReminderTrenTsh:  trenResult.ReminderTrenTSH,
				TrenFt3:          trenResult.TrenFT3,
				ReminderTrenFt3:  trenResult.ReminderTrenFT3,
				TrenFt4:          trenResult.TrenFT4,
				ReminderTrenFt4:  trenResult.ReminderTrenFT4,
				TrenTrab:         trenResult.TrenTRAb,
				ReminderTrenTrab: trenResult.ReminderTrenTRAb,
			})
			if err != nil {
				fmt.Printf("Warning: gagal simpan hasil AI Tren: %v\n", err)
			}
		}
	}

	res.Interpretation = currResult.Interpretasi
	return res, nil
}