package usecases

import (
	"strings"

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

	NilaiTSH  float64
	NilaiFT3  float64
	NilaiFT4  float64
	NilaiTRAb float64
}

func extractHormoneValues(params []models.AssessmentParamInput) map[string]models.AssessmentParamInput {
	result := make(map[string]models.AssessmentParamInput)
	for _, p := range params {
		key := strings.ToUpper(strings.TrimSpace(p.NamaParameter))
		if key == "TSHS" || key == "TSH" {
			key = "TSH"
		}
		result[key] = p
	}
	return result
}

// ==========================================
// EVALUASI PER PARAMETER
// ==========================================

func evaluateTSH(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan TSHs tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa TSHs berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa TSHs berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa TSHs berada dalam rentang yang diharapkan."
}

func evaluateFT3(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan FT3 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa FT3 berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa FT3 berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa FT3 berada dalam rentang yang diharapkan."
}

func evaluateFT4(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasBawah == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan FT4 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil < p.NilaiBatasBawah {
		return "Rendah",
			"Hasil pemeriksaan menunjukkan bahwa FT4 berada di bawah rentang yang diharapkan."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Tinggi",
			"Hasil pemeriksaan menunjukkan bahwa FT4 berada di atas rentang yang diharapkan."
	}
	return "Normal",
		"Hasil pemeriksaan menunjukkan bahwa FT4 berada dalam rentang yang diharapkan."
}

func evaluateTRAb(p models.AssessmentParamInput) (status, reminder string) {
	if p.NilaiHasil == 0 || p.NilaiBatasAtas == 0 {
		return "Tidak Diketahui",
			"Hasil pemeriksaan TRAb tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}
	if p.NilaiHasil > p.NilaiBatasAtas {
		return "Positif",
			"Hasil pemeriksaan menunjukkan adanya penanda autoimun tiroid (TRAb positif)."
	}
	return "Negatif",
		"Hasil pemeriksaan menunjukkan tidak adanya penanda autoimun tiroid (TRAb negatif)."
}

// ==========================================
// FUNGSI INTERPRETASI KESELURUHAN (Sesuai Tabel Skripsi)
// ==========================================
func interpretasiKeseluruhan(statusTSH, statusFT3, statusFT4 string) string {
	isFT3Aman := statusFT3 == "Normal" || statusFT3 == "Tidak Diketahui"
	isFT4Aman := statusFT4 == "Normal" || statusFT4 == "Tidak Diketahui"

	isFT3TinggiAtauAman := statusFT3 == "Tinggi" || statusFT3 == "Normal" || statusFT3 == "Tidak Diketahui"
	isFT4TinggiAtauAman := statusFT4 == "Tinggi" || statusFT4 == "Normal" || statusFT4 == "Tidak Diketahui"

	// Aturan 1: TSH Normal + FT3 Normal/TidakDiketahui + FT4 Normal/TidakDiketahui → Normal
	if statusTSH == "Normal" && isFT3Aman && isFT4Aman {
		return "Normal"
	}

	// Aturan 2-5: TSH Rendah + FT3 (Tinggi/Normal/TidakDiketahui) + FT4 (Tinggi/Normal/TidakDiketahui) → Belum Normal
	if statusTSH == "Rendah" && isFT3TinggiAtauAman && isFT4TinggiAtauAman {
		return "Belum Normal"
	}

	// Selain aturan di atas → Tidak Terinterpretasi
	return "Tidak Terinterpretasi"
}

func AnalyzeLabResults(params []models.AssessmentParamInput) LabAssessmentResult {
	var result LabAssessmentResult
	paramMap := extractHormoneValues(params)

	if tsh, ok := paramMap["TSH"]; ok {
		result.StatusTSH, result.ReminderTSH = evaluateTSH(tsh)
		result.NilaiTSH = tsh.NilaiHasil
	} else {
		result.StatusTSH = "Tidak Diketahui"
		result.ReminderTSH = "Hasil pemeriksaan TSHs tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if ft4, ok := paramMap["FT4"]; ok {
		result.StatusFT4, result.ReminderFT4 = evaluateFT4(ft4)
		result.NilaiFT4 = ft4.NilaiHasil
	} else {
		result.StatusFT4 = "Tidak Diketahui"
		result.ReminderFT4 = "Hasil pemeriksaan FT4 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if ft3, ok := paramMap["FT3"]; ok {
		result.StatusFT3, result.ReminderFT3 = evaluateFT3(ft3)
		result.NilaiFT3 = ft3.NilaiHasil
	} else {
		result.StatusFT3 = "Tidak Diketahui"
		result.ReminderFT3 = "Hasil pemeriksaan FT3 tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	if trab, ok := paramMap["TRAB"]; ok {
		result.StatusTRAb, result.ReminderTRAb = evaluateTRAb(trab)
		result.NilaiTRAb = trab.NilaiHasil
	} else {
		result.StatusTRAb = "Tidak Diketahui"
		result.ReminderTRAb = "Hasil pemeriksaan TRAb tidak dapat diinterpretasikan karena data tidak tersedia atau tidak valid."
	}

	result.Interpretasi = interpretasiKeseluruhan(
		result.StatusTSH,
		result.StatusFT3,
		result.StatusFT4,
	)

	return result
}

// ==========================================
// ANALISIS TREN PER PARAMETER (DISESUAIKAN DENGAN TABEL SKRIPSI)
// ==========================================

func trenTSH(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Rendah":
		if currNilai > prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		} else if currNilai < prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		} else {
			return "Tidak berubah", "Berdasarkan hasil pemeriksaan, TSHs saat ini masih berada di bawah rentang normal. Nilai TSHs tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di bawah rentang normal dan belum menunjukkan perubahan menuju rentang normal."
		}
	case "Normal":
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TSHs saat ini berada dalam rentang normal. Nilai TSHs tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
		}
	default: // Status "Tinggi" atau "Tidak Diketahui"
		return "Tidak diketahui", "Kondisi TSHs saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

func trenFT3(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Normal":
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada dalam rentang normal. Nilai FT3 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
		}
	case "Tinggi":
		if currNilai > prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		} else if currNilai < prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, FT3 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		} else {
			return "Tidak berubah", "Berdasarkan hasil pemeriksaan, FT3 saat ini masih berada di atas rentang normal. Nilai FT3 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
		}
	default: // Status "Rendah" atau "Tidak Diketahui"
		return "Tidak diketahui", "Kondisi FT3 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

func trenFT4(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Normal":
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam rentang normal."
		} else {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada dalam rentang normal. Nilai FT4 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam rentang normal."
		}
	case "Tinggi":
		if currNilai > prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi rentang normal."
		} else if currNilai < prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, FT4 saat ini berada di atas rentang normal dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati rentang normal."
		} else {
			return "Tidak berubah", "Berdasarkan hasil pemeriksaan, FT4 saat ini masih berada di atas rentang normal. Nilai FT4 tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada di atas rentang normal."
		}
	default: // Status "Rendah" atau "Tidak Diketahui"
		return "Tidak diketahui", "Kondisi FT4 saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

func trenTRAb(prevNilai, currNilai float64, currStatus string) (tren, reminder string) {
	switch currStatus {
	case "Negatif":
		if currNilai > prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif) dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam kategori negatif."
		} else if currNilai < prevNilai {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif) dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, namun kondisi tetap berada dalam kategori negatif."
		} else {
			return "Tetap normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini tidak menunjukkan penanda autoimun (negatif). Nilai TRAb tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi tetap berada dalam kategori negatif."
		}
	case "Positif":
		if currNilai > prevNilai {
			return "Menjauhi normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif) dibandingkan sebelumnya. Terjadi peningkatan nilai dari pemeriksaan sebelumnya, sehingga kondisi semakin menjauhi kategori negatif."
		} else if currNilai < prevNilai {
			return "Mendekati normal", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif) dibandingkan sebelumnya. Terjadi penurunan nilai dari pemeriksaan sebelumnya, sehingga kondisi mulai mendekati kategori negatif."
		} else {
			return "Tidak berubah", "Berdasarkan hasil pemeriksaan, TRAb saat ini masih menunjukkan penanda autoimun (positif). Nilai TRAb tidak mengalami perubahan dibandingkan pemeriksaan sebelumnya, sehingga kondisi masih berada dalam kategori positif."
		}
	default:
		return "Tidak diketahui", "Kondisi TRAb saat ini tidak sesuai dengan pola interpretasi yang tersedia dalam sistem sehingga tren tidak dapat ditentukan."
	}
}

// ==========================================
// FUNGSI ANALISIS TREN (MESIN 3)
// ==========================================
type TrenResult struct {
	TrenTSH          string
	ReminderTrenTSH  string
	TrenFT3          string
	ReminderTrenFT3  string
	TrenFT4          string
	ReminderTrenFT4  string
	TrenTRAb         string
	ReminderTrenTRAb string
}

func AnalyzeTren(prev, curr LabAssessmentResult) TrenResult {
	var tren TrenResult
	tren.TrenTSH, tren.ReminderTrenTSH = trenTSH(prev.NilaiTSH, curr.NilaiTSH, curr.StatusTSH)
	tren.TrenFT3, tren.ReminderTrenFT3 = trenFT3(prev.NilaiFT3, curr.NilaiFT3, curr.StatusFT3)
	tren.TrenFT4, tren.ReminderTrenFT4 = trenFT4(prev.NilaiFT4, curr.NilaiFT4, curr.StatusFT4)
	tren.TrenTRAb, tren.ReminderTrenTRAb = trenTRAb(prev.NilaiTRAb, curr.NilaiTRAb, curr.StatusTRAb)
	return tren
}