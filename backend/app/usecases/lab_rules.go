package usecases

import (
	"fmt"
	"strings"

	"monitoring-service/app/constants"
	"monitoring-service/app/models"
)

type LabAssessmentResult struct {
	StatusTSH    string
	ReminderTSH  string
	StatusFT3    string
	ReminderFT3  string
	StatusFT4    string
	ReminderFT4  string
	StatusTRAb   string
	ReminderTRAb string
	Interpretasi string
}

// ✅ Sekarang pakai AssessmentParamInput, bukan models.Parameter
func extractHormoneValues(params []models.AssessmentParamInput) (ft3, ft4, tsh, trab float64) {
	for _, p := range params {
		paramName := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		switch paramName {
		case "FT3":
			ft3 = p.NilaiHasil
		case "FT4":
			ft4 = p.NilaiHasil
		case "TSH":
			tsh = p.NilaiHasil
		case "TRAB":
			trab = p.NilaiHasil
		}
	}
	return
}

func evaluateHormone(nama string, nilai, min, max float64) (status, reminder string) {
	if nilai == 0 {
		return "Tidak Ada Data", fmt.Sprintf("Data %s tidak ditemukan dalam laporan lab ini.", nama)
	}
	if nilai < min {
		return "Rendah", fmt.Sprintf("Nilai %s Anda (%.2f) di bawah batas normal. Segera konsultasikan dengan dokter.", nama, nilai)
	}
	if nilai > max {
		return "Tinggi", fmt.Sprintf("Nilai %s Anda (%.2f) di atas batas normal. Perhatikan gejala yang muncul dan hubungi dokter.", nama, nilai)
	}
	return "Normal", fmt.Sprintf("Nilai %s Anda (%.2f) berada dalam rentang normal. Pertahankan gaya hidup sehat.", nama, nilai)
}

// ✅ Signature diubah sesuai tipe baru
func AnalyzeLabResults(params []models.AssessmentParamInput) LabAssessmentResult {
	var result LabAssessmentResult
	ft3, ft4, tsh, trab := extractHormoneValues(params)

	result.StatusTSH, result.ReminderTSH = evaluateHormone("TSH", tsh, constants.TSH_MIN, constants.TSH_MAX)
	result.StatusFT3, result.ReminderFT3 = evaluateHormone("FT3", ft3, constants.FT3_MIN, constants.FT3_MAX)
	result.StatusFT4, result.ReminderFT4 = evaluateHormone("FT4", ft4, constants.FT4_MIN, constants.FT4_MAX)

	if trab > 0 {
		result.StatusTRAb, result.ReminderTRAb = evaluateHormone("TRAb", trab, constants.TRAB_MIN, constants.TRAB_MAX)
	} else {
		result.StatusTRAb = "Tidak Ada Data"
		result.ReminderTRAb = "Data TRAb tidak ditemukan."
	}

	if result.StatusTSH == "Normal" && result.StatusFT3 == "Normal" && result.StatusFT4 == "Normal" {
		result.Interpretasi = "Kondisi tiroid stabil (Normal)."
	} else if result.StatusTSH == "Rendah" && result.StatusFT3 == "Tinggi" && result.StatusFT4 == "Tinggi" {
		result.Interpretasi = "Indikasi Overt Graves Disease (Hipertiroid nyata). Harap segera ke dokter."
	} else if result.StatusTSH == "Rendah" && result.StatusFT3 == "Tinggi" && result.StatusFT4 == "Normal" {
		result.Interpretasi = "Indikasi Graves Disease dominan T3 (T3-toxicosis)."
	} else if result.StatusTSH == "Rendah" && result.StatusFT3 == "Normal" && result.StatusFT4 == "Tinggi" {
		result.Interpretasi = "Indikasi Graves Disease dominan T4."
	} else {
		result.Interpretasi = "Kondisi tiroid tidak menentu atau di luar pola standar Graves. Perlu evaluasi medis lebih lanjut."
	}

	return result
}